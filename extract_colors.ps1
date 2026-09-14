Add-Type -AssemblyName System.IO.Compression.FileSystem
$docx = "D:\Flutter_Project\DTCproduct\docs\1 Máy tách màu\Dac_diem_thong_so_ky_thuat_may_SC.docx"
$temp = "D:\temp_docx_3"
if (Test-Path $temp) { Remove-Item -Recurse -Force $temp }
[System.IO.Compression.ZipFile]::ExtractToDirectory($docx, $temp)
$xml = [xml](Get-Content "$temp\word\document.xml")
$found = $false
foreach ($p in $xml.document.body.p) {
    if ($p.InnerText -match "DỤNG") { $found = $true }
    if ($found -and $p.InnerText -ne "") {
        Write-Host "--- PARAGRAPH ---"
        foreach ($r in $p.r) {
            $color = "None"
            if ($r.rPr.color.val) { $color = $r.rPr.color.val }
            $t = $r.t
            if ($t) { Write-Host "[$color] $t" }
        }
    }
}
