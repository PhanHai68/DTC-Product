$docsDir = "d:\Flutter_Project\DTCproduct\docs\1 Máy tách màu"

try {
    # Excel
    Write-Host "Starting Excel replacement..."
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false

    $xlsxFiles = @("1.1 Thong_So_MayTachMauSC.xlsx", "1.3 Phan_Tich_Hoan_Von_MTM.xlsx")
    foreach ($file in $xlsxFiles) {
        $path = Join-Path $docsDir $file
        if (Test-Path $path) {
            $workbook = $excel.Workbooks.Open($path)
            foreach ($worksheet in $workbook.Sheets) {
                $range = $worksheet.UsedRange
                # 2 = xlPart
                $null = $range.Replace("SC12 Pro", "SC16 Pro", 2)
                $null = $range.Replace("SC12 pro", "SC16 Pro", 2)
            }
            $workbook.Save()
            $workbook.Close()
            Write-Host "Updated $path"
        }
    }
    $excel.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null

    # Word
    Write-Host "Starting Word replacement..."
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0

    $docxPath = Join-Path $docsDir "Dac_diem_thong_so_ky_thuat_may_SC.docx"
    if (Test-Path $docxPath) {
        $doc = $word.Documents.Open($docxPath)
        
        # Replace in document body
        $find = $doc.Content.Find
        $find.ClearFormatting()
        $find.Replacement.ClearFormatting()
        $find.Text = "SC12 Pro"
        $find.Replacement.Text = "SC16 Pro"
        $find.Execute([ref]$null, [ref]$null, [ref]$null, [ref]$null, [ref]$null, [ref]$null, [ref]$null, [ref]1, [ref]$null, [ref]$null, [ref]2)
        
        $find.Text = "SC12 pro"
        $find.Replacement.Text = "SC16 Pro"
        $find.Execute([ref]$null, [ref]$null, [ref]$null, [ref]$null, [ref]$null, [ref]$null, [ref]$null, [ref]1, [ref]$null, [ref]$null, [ref]2)

        $doc.Save()
        $doc.Close()
        Write-Host "Updated $docxPath"
    }
    $word.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}
