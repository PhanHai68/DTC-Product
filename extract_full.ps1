Add-Type -AssemblyName System.IO.Compression.FileSystem
$docx = (Get-ChildItem -Path "D:\Flutter_Project\DTCproduct\docs" -Recurse -Filter "Dac_diem_thong_so_ky_thuat_may_SC.docx" | Select-Object -First 1).FullName
$tempDocx = "D:\temp_copy.docx"
Copy-Item $docx -Destination $tempDocx -Force

$temp = "D:\temp_docx5"
if (Test-Path $temp) { Remove-Item -Recurse -Force $temp }
[System.IO.Compression.ZipFile]::ExtractToDirectory($tempDocx, $temp)
$xml = [xml](Get-Content "$temp\word\document.xml")
$text = ""
foreach ($p in $xml.document.body.p) {
    $para = ""
    foreach ($r in $p.r) {
        $color = ""
        if ($r.rPr.color.val) { $color = "[" + $r.rPr.color.val + "] " }
        $t = $r.t
        if ($t) { $para += $color + $t }
    }
    if ($para) { $text += $para + "`n" }
}
Set-Content -Path "D:\Flutter_Project\DTCproduct\full_docx_colors.txt" -Value $text -Encoding UTF8
