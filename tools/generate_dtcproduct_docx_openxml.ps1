param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$OutputDir = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'output')
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$contentPath = Join-Path $ProjectRoot 'docs\presentation\DTCProduct_Gioi_thieu_noi_dung.md'
if (-not (Test-Path $contentPath)) { throw "Không tìm thấy nội dung báo cáo: $contentPath" }
$text = [System.IO.File]::ReadAllText($contentPath, [System.Text.Encoding]::UTF8)
$text = [regex]::Replace($text, '(?m)^---\s*$', '[[PAGEBREAK]]')
$lines = $text -split '\r?\n'

function XmlEscape([string]$value) {
  if ($null -eq $value) { return '' }
  return [System.Security.SecurityElement]::Escape($value)
}

function ParagraphXml([string]$value, [string]$style = 'Normal') {
  $safe = XmlEscape $value
  return "<w:p><w:pPr><w:pStyle w:val=`"$style`"/></w:pPr><w:r><w:t xml:space=`"preserve`">$safe</w:t></w:r></w:p>"
}

$body = New-Object System.Text.StringBuilder
$cover = $true
foreach($line in $lines) {
  $trimmed = $line.Trim()
  if ($trimmed -eq '[[PAGEBREAK]]') {
    [void]$body.Append('<w:p><w:r><w:br w:type="page"/></w:r></w:p>')
    $cover = $false
    continue
  }
  if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
  $style = 'Normal'
  if ($cover) {
    if ($trimmed -eq 'BÁO CÁO GIỚI THIỆU ỨNG DỤNG') { $style = 'CoverKicker' }
    elseif ($trimmed -eq 'DTCProduct') { $style = 'Title' }
    elseif ($trimmed -eq 'Chức năng và ứng dụng thực tế') { $style = 'Subtitle' }
    else { $style = 'CenterMeta' }
  }
  elseif ($trimmed -match '^(TÓM TẮT|[1-7]\. [A-ZÀ-ỸĐ]|PHỤ LỤC)') { $style = 'Heading1' }
  elseif ($trimmed -match '^\d+\.\d+\.') { $style = 'Heading2' }
  elseif ($trimmed.StartsWith('•')) { $style = 'Bullet' }
  [void]$body.Append((ParagraphXml $trimmed $style))
}

$contentTypes = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
'@

$rootRels = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
'@

$documentRels = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>
</Relationships>
'@

$styles = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Aptos" w:hAnsi="Aptos"/><w:color w:val="465362"/><w:sz w:val="22"/><w:lang w:val="vi-VN"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:after="120"/></w:pPr><w:rPr><w:rFonts w:ascii="Aptos" w:hAnsi="Aptos"/><w:sz w:val="22"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="CoverKicker"><w:name w:val="Cover Kicker"/><w:basedOn w:val="Normal"/><w:pPr><w:jc w:val="center"/><w:spacing w:before="900" w:after="160"/></w:pPr><w:rPr><w:b/><w:color w:val="00AEC7"/><w:sz w:val="32"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:pPr><w:jc w:val="center"/><w:spacing w:after="120"/></w:pPr><w:rPr><w:b/><w:color w:val="0C2444"/><w:sz w:val="68"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Subtitle"><w:name w:val="Subtitle"/><w:basedOn w:val="Normal"/><w:pPr><w:jc w:val="center"/><w:spacing w:after="600"/></w:pPr><w:rPr><w:color w:val="586A7C"/><w:sz w:val="38"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="CenterMeta"><w:name w:val="Center Meta"/><w:basedOn w:val="Normal"/><w:pPr><w:jc w:val="center"/><w:spacing w:after="80"/></w:pPr><w:rPr><w:color w:val="586A7C"/><w:sz w:val="22"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="280" w:after="100"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:color w:val="0C2444"/><w:sz w:val="32"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="180" w:after="60"/><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:b/><w:color w:val="0C2444"/><w:sz w:val="26"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Bullet"><w:name w:val="Bullet"/><w:basedOn w:val="Normal"/><w:pPr><w:ind w:left="360" w:hanging="240"/><w:spacing w:after="60"/></w:pPr><w:rPr><w:sz w:val="21"/></w:rPr></w:style>
</w:styles>
'@

$documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    $($body.ToString())
    <w:sectPr>
      <w:footerReference w:type="default" r:id="rId2"/>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1134" w:right="1300" w:bottom="1134" w:left="1300" w:header="540" w:footer="540" w:gutter="0"/>
      <w:cols w:space="708"/>
      <w:docGrid w:linePitch="360"/>
    </w:sectPr>
  </w:body>
</w:document>
"@

$footer = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:color w:val="586A7C"/><w:sz w:val="16"/></w:rPr><w:t>DTC Group  •  </w:t></w:r><w:fldSimple w:instr=" PAGE "><w:r><w:rPr><w:color w:val="586A7C"/><w:sz w:val="16"/></w:rPr><w:t>1</w:t></w:r></w:fldSimple></w:p>
</w:ftr>
'@

$core = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Báo cáo giới thiệu DTCProduct</dc:title><dc:subject>Chức năng và ứng dụng thực tế</dc:subject><dc:creator>DTC Group</dc:creator><cp:keywords>DTCProduct, Flutter, thiết bị, kỹ thuật</cp:keywords><dc:description>Báo cáo giới thiệu ứng dụng DTCProduct</dc:description><dcterms:created xsi:type="dcterms:W3CDTF">2026-09-29T00:00:00Z</dcterms:created>
</cp:coreProperties>
'@

$app = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>Microsoft Office Word</Application><AppVersion>16.0000</AppVersion></Properties>
'@

$tempRoot = Join-Path $ProjectRoot '.codex_tmp\dtcproduct_report_docx'
if (Test-Path $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot '_rels'), (Join-Path $tempRoot 'word\_rels'), (Join-Path $tempRoot 'docProps') | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $tempRoot '[Content_Types].xml'), $contentTypes, $utf8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot '_rels\.rels'), $rootRels, $utf8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot 'word\document.xml'), $documentXml, $utf8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot 'word\styles.xml'), $styles, $utf8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot 'word\footer1.xml'), $footer, $utf8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot 'word\_rels\document.xml.rels'), $documentRels, $utf8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot 'docProps\core.xml'), $core, $utf8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot 'docProps\app.xml'), $app, $utf8)

$docxPath = Join-Path $OutputDir 'Bao_cao_Gioi_thieu_DTCProduct.docx'
if (Test-Path $docxPath) { Remove-Item -LiteralPath $docxPath -Force }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($docxPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  foreach($file in Get-ChildItem -LiteralPath $tempRoot -File -Recurse) {
    $relative = $file.FullName.Substring($tempRoot.Length + 1).Replace('\', '/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
      $archive,
      $file.FullName,
      $relative,
      [System.IO.Compression.CompressionLevel]::Optimal
    ) | Out-Null
  }
}
finally {
  $archive.Dispose()
}

# Also provide a portable Markdown copy for quick review and easy reuse.
$mdPath = Join-Path $OutputDir 'Noi_dung_thuyet_trinh_va_Bao_cao_DTCProduct.md'
[System.IO.File]::WriteAllText($mdPath, $text.Replace('[[PAGEBREAK]]', "`r`n---`r`n"), $utf8)

$htmlBody = New-Object System.Text.StringBuilder
$cover = $true
foreach($line in $lines) {
  $trimmed = $line.Trim()
  if ($trimmed -eq '[[PAGEBREAK]]') {
    [void]$htmlBody.Append('<div class="page-break"></div>')
    $cover = $false
    continue
  }
  if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
  $safe = [System.Net.WebUtility]::HtmlEncode($trimmed)
  if ($cover) {
    if ($trimmed -eq 'BÁO CÁO GIỚI THIỆU ỨNG DỤNG') { [void]$htmlBody.Append("<p class=`"cover-kicker`">$safe</p>") }
    elseif ($trimmed -eq 'DTCProduct') { [void]$htmlBody.Append("<h1 class=`"cover-title`">$safe</h1>") }
    elseif ($trimmed -eq 'Chức năng và ứng dụng thực tế') { [void]$htmlBody.Append("<p class=`"cover-subtitle`">$safe</p>") }
    else { [void]$htmlBody.Append("<p class=`"cover-meta`">$safe</p>") }
  }
  elseif ($trimmed -match '^(TÓM TẮT|[1-7]\. [A-ZÀ-ỸĐ]|PHỤ LỤC)') { [void]$htmlBody.Append("<h1>$safe</h1>") }
  elseif ($trimmed -match '^\d+\.\d+\.') { [void]$htmlBody.Append("<h2>$safe</h2>") }
  elseif ($trimmed.StartsWith('•')) { [void]$htmlBody.Append("<p class=`"bullet`">$safe</p>") }
  else { [void]$htmlBody.Append("<p>$safe</p>") }
}

$html = @"
<!doctype html><html lang="vi"><head><meta charset="utf-8"><title>Báo cáo giới thiệu DTCProduct</title>
<style>
@page{size:A4;margin:18mm 20mm 18mm}*{box-sizing:border-box}body{font-family:Aptos,"Segoe UI",Arial,sans-serif;color:#465362;font-size:11pt;line-height:1.45;margin:0}h1{color:#0c2444;font-size:17pt;margin:18pt 0 7pt;page-break-after:avoid}h2{color:#0c2444;font-size:13pt;margin:12pt 0 5pt;page-break-after:avoid}p{margin:0 0 7pt;text-align:justify}.bullet{padding-left:16pt;text-indent:-12pt;margin-bottom:4pt}.cover-kicker{text-align:center;color:#00aec7;font-size:16pt;font-weight:700;margin-top:62mm;margin-bottom:8pt}.cover-title{text-align:center;font-size:36pt;margin:0 0 5pt;color:#0c2444}.cover-subtitle{text-align:center;font-size:19pt;color:#586a7c;margin-bottom:28pt}.cover-meta{text-align:center;color:#586a7c;margin-bottom:4pt}.page-break{break-after:page;page-break-after:always}body:after{content:"DTC Group";position:fixed;bottom:-11mm;right:0;color:#8796a5;font-size:8pt}
</style></head><body>$($htmlBody.ToString())</body></html>
"@
$htmlPath = Join-Path $OutputDir 'Bao_cao_Gioi_thieu_DTCProduct.html'
[System.IO.File]::WriteAllText($htmlPath, $html, $utf8)

Write-Output "Created: $docxPath"
Write-Output "Created: $mdPath"
Write-Output "Created: $htmlPath"
