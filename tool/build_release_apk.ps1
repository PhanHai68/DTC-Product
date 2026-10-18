# Build APK release để gửi cài trực tiếp, có làm rối mã (obfuscate).
#
#   Bản gửi cho người dùng:
#     powershell -ExecutionPolicy Bypass -File tool\build_release_apk.ps1 -Label ten-ban
#   Bản build thử (không chép lên Google Drive):
#     powershell -ExecutionPolicy Bypass -File tool\build_release_apk.ps1 -Label thu -SkipBackup
#
# - Tên hàm/lớp Dart trong APK bị đổi thành ký tự vô nghĩa, khó đọc ngược logic.
# - File giải mã ("sổ giải mã") lưu ở symbols\android\<phiên bản>\ (không đưa
#   lên Git). Thiếu nó thì không đọc được chi tiết lỗi trong Cài đặt → Nhật ký
#   lỗi của bản đó, và không tạo lại được. Giải mã:
#     flutter symbolize -i loi.txt -d <thư mục symbols>\app.android-arm64.symbols
# - APK chép ra thư mục gốc: DTCProduct-<phiên bản>-<commit>-<Label>.apk
# - Sao lưu: chép APK + symbols vào $ReleaseDir\<phiên bản>\ (Google Drive cho
#   máy tính tự đồng bộ lên mạng). Thư mục này KHÔNG được chia sẻ công khai.
param(
    [string]$Label = 'release',
    [string]$ReleaseDir = 'G:\My Drive\DTC Product - Phát hành',
    [switch]$SkipBackup
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$versionLine = Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)' | Select-Object -First 1
if ($null -eq $versionLine) { throw 'Không đọc được version trong pubspec.yaml' }
$version = $versionLine.Matches[0].Groups[1].Value
$commit = (git rev-parse --short HEAD).Trim()
$symbols = Join-Path $root "symbols\android\$version"

if (-not (Test-Path android\key.properties)) {
    throw 'Thiếu android\key.properties — APK phải ký bằng upload-keystore.jks như các bản trước.'
}

Write-Host "Build $version ($commit), symbols -> $symbols"
flutter build apk --release --obfuscate "--split-debug-info=$symbols"
if ($LASTEXITCODE -ne 0) { throw "flutter build apk lỗi ($LASTEXITCODE)" }

$apkName = "DTCProduct-$version-$commit-$Label.apk"
$output = Join-Path $root $apkName
Copy-Item build\app\outputs\flutter-apk\app-release.apk $output -Force
Write-Host "Xong: $output"

if ($SkipBackup) {
    Write-Host 'Bản build thử: không sao lưu lên Google Drive.'
    return
}
if (-not (Test-Path (Split-Path -Parent $ReleaseDir))) {
    Write-Warning "Không thấy $(Split-Path -Parent $ReleaseDir) (Google Drive cho máy tính chưa chạy?). Hãy tự chép $output và thư mục $symbols lên Google Drive."
    return
}
$backup = Join-Path $ReleaseDir $version
New-Item -ItemType Directory -Force -Path (Join-Path $backup 'symbols') | Out-Null
Copy-Item $output (Join-Path $backup $apkName) -Force
Copy-Item (Join-Path $symbols '*') (Join-Path $backup 'symbols') -Force
Write-Host "Đã sao lưu APK + symbols vào $backup"
