import zipfile
import os
import re
import xml.etree.ElementTree as ET

def extract_docx(docx_path, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    images = {}
    text_content = []
    
    with zipfile.ZipFile(docx_path, 'r') as docx:
        # Extract images
        for file in docx.namelist():
            if file.startswith('word/media/'):
                filename = os.path.basename(file)
                if filename:
                    extracted_path = docx.extract(file, output_dir)
                    images[file] = extracted_path
                    
        # Extract text to find mapping
        if 'word/document.xml' in docx.namelist():
            doc_xml = docx.read('word/document.xml')
            root = ET.fromstring(doc_xml)
            
            # The namespace dictionary
            namespaces = {
                'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
                'pic': 'http://schemas.openxmlformats.org/drawingml/2006/picture',
                'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
            }
            
            # Read paragraphs and images in order
            for elem in root.iter():
                if elem.tag == '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}p':
                    # Paragraph
                    texts = [t.text for t in elem.findall('.//w:t', namespaces) if t.text]
                    if texts:
                        text_content.append('TEXT: ' + ''.join(texts))
                elif elem.tag == '{http://schemas.openxmlformats.org/drawingml/2006/picture}pic':
                    # Image
                    blip = elem.find('.//a:blip', namespaces)
                    if blip is not None:
                        embed_id = blip.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed')
                        text_content.append(f'IMAGE: {embed_id}')
            
            # We also need to map relationship IDs to actual media files
            rels_xml = docx.read('word/_rels/document.xml.rels')
            rels_root = ET.fromstring(rels_xml)
            rels_namespaces = {'rel': 'http://schemas.openxmlformats.org/package/2006/relationships'}
            
            rel_map = {}
            for rel in rels_root.findall('.//rel:Relationship', rels_namespaces):
                rel_id = rel.get('Id')
                target = rel.get('Target')
                if target.startswith('media/'):
                    rel_map[rel_id] = target
                    
            print("Mapping:")
            for item in text_content:
                if item.startswith('IMAGE: '):
                    rel_id = item.split(' ')[1]
                    print(f"IMAGE -> {rel_map.get(rel_id, 'UNKNOWN')}")
                else:
                    print(item)
                    
    print(f"Extracted {len(images)} images to {output_dir}")

extract_docx(r'D:\Flutter_Project\DTCproduct\docs\1 Máy tách màu\Hinh_Anh_May_Mau_SC.docx', r'D:\Flutter_Project\DTCproduct\scratch_extract')
