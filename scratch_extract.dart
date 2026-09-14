import 'dart:io';

void main() {
  String docXml = File('scratch_extract_docx/word/document.xml').readAsStringSync();
  String relsXml = File('scratch_extract_docx/word/_rels/document.xml.rels').readAsStringSync();

  // Extract relationships
  Map<String, String> rels = {};
  RegExp relRegex = RegExp(r'<Relationship[^>]*?Id="([^"]+)"[^>]*?Target="([^"]+)"');
  for (var match in relRegex.allMatches(relsXml)) {
    rels[match.group(1)!] = match.group(2)!;
  }

  // Extract paragraphs and images
  // Split the document into chunks that represent paragraphs or drawing elements roughly
  // The structure is generally linear.
  
  RegExp chunkRegex = RegExp(r'(<w:p[\s>].*?</w:p>|<w:drawing>.*?</w:drawing>)');
  RegExp tRegex = RegExp(r'<w:t(?:[^>]*?)>([^<]+)</w:t>');
  RegExp imgRegex = RegExp(r'<a:blip[^>]*?r:embed="([^"]+)"');

  for (var match in chunkRegex.allMatches(docXml)) {
    String chunk = match.group(0)!;
    
    var imgMatch = imgRegex.firstMatch(chunk);
    if (imgMatch != null) {
      String rId = imgMatch.group(1)!;
      print('IMAGE: ${rels[rId]}');
    }
    
    String text = '';
    for (var tMatch in tRegex.allMatches(chunk)) {
      text += tMatch.group(1)!;
    }
    text = text.trim();
    if (text.isNotEmpty) {
      print('TEXT: $text');
    }
  }
}
