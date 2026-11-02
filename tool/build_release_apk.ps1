# Phát hành một lệnh: APK (có làm rối mã) + web + sao lưu Google Drive.
#
#   Bản gửi cho người dùng:
#     powershell -ExecutionPolicy Bypass -File tool\build_release_apk.ps1 -Label ten-ban
#   Bản build thử (không chép lên Google Drive, không dọn APK cũ):
#     powershell -ExecutionPolicy Bypass -File tool\build_release_apk.ps1 -Label thu -SkipBackup
#   Không build web: -SkipWeb.
#
# Kết quả ở thư mục gốc dự án:
# - DTCProduct-<phiên bản>-<commit>-<Label>-arm64.apk: GỬI BẢN NÀY cho người
#   dùng (điện thoại Android 64-bit, gần như mọi máy từ 2017), nhẹ hơn nhiều.
# - DTCProduct-<phiên bản>-<commit>-<Label>-arm32.apk: cho máy 32-bit đời cũ
#   (máy nào báo không cài được bản arm64). Hai bản cùng số phiên bản
#   (versionCode) nên cài đè qua lại được.
# - DTCProduct-web-<phiên bản>.zip: kéo thả lên Cloudflare (worker "test" →
#   New deployment).
#
# - Tên hàm/lớp Dart trong APK bị đổi thành ký tự vô nghĩa, khó đọc ngược logic.
# - File giải mã ("sổ giải mã") lưu ở symbols\android\<phiên bản>\, không
#   đưa lên Git. Thiếu nó thì không đọc được chi tiết lỗi trong Cài đặt → Nhật
#   ký lỗi của bản đó, và không tạo lại được. Giải mã:
#     flutter symbolize -i loi.txt -d <thư mục symbols>\app.android-arm64.symbols
# - Sao lưu: chép APK + web + symbols vào $ReleaseDir\<phiên bản>\ (Google
#   Drive cho máy tính tự đồng bộ lên mạng). Thư mục này KHÔNG được chia sẻ
#   công khai. Sau khi sao lưu, APK / web zip cũ ở thư mục gốc đã có bản giống
#   hệt trên Drive sẽ được xoá cho gọn (chỉ giữ bản vừa build).
param(
    [string]$Label = 'release',
    [string]$ReleaseDir = 'G:\My Drive\DTC Product - Phát hành',
    [switch]$SkipBackup,
    [switch]$SkipWeb
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

Write-Host "Build APK $version ($commit), symbols -> $symbols"
# Tách APK theo loại chip nhưng giữ nguyên versionCode của pubspec (mặc định
# Flutter cộng thêm 1000 × mã chip, làm bản sau không cài đè được bản trước).
flutter build apk --release --obfuscate "--split-debug-info=$symbols" --split-per-abi -P force-version-code-ignoring-abi=true
if ($LASTEXITCODE -ne 0) { throw "flutter build apk lỗi ($LASTEXITCODE)" }
# Flutter dùng lại bản dịch cũ khi mã không đổi và khi đó không ghi lại
# symbols: thiếu thì chạy `flutter clean` rồi build lại.
if (-not (Test-Path (Join-Path $symbols 'app.android-arm64.symbols'))) {
    throw "Không thấy symbols ở $symbols — chạy 'flutter clean' rồi build lại."
}

$outputs = @()
foreach ($abi in @(@('arm64-v8a', 'arm64'), @('armeabi-v7a', 'arm32'))) {
    $apk = Join-Path $root "DTCProduct-$version-$commit-$Label-$($abi[1]).apk"
    Copy-Item "build\app\outputs\flutter-apk\app-$($abi[0])-release.apk" $apk -Force
    $outputs += $apk
}

if (-not $SkipWeb) {
    Write-Host 'Build web'
    flutter build web --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build web lỗi ($LASTEXITCODE)" }
    # File xác minh Google Search Console: thiếu thì Chrome có thể lại cảnh báo
    # "Nguy hiểm" cho trang web.
    if (-not (Test-Path build\web\googlee6149ad46a6623aa.html)) {
        throw 'Bản web thiếu file xác minh Google (web\googlee6149ad46a6623aa.html).'
    }
    $zip = Join-Path $root "DTCProduct-web-$version.zip"
    if (Test-Path $zip) { Remove-Item $zip }
    Compress-Archive -Path build\web\* -DestinationPath $zip
    $outputs += $zip
}

foreach ($f in $outputs) {
    Write-Host ('Xong: {0} ({1:N1} MB)' -f $f, ((Get-Item $f).Length / 1MB))
}

if ($SkipBackup) {
    Write-Host 'Bản build thử: không sao lưu lên Google Drive.'
    return
}
if (-not (Test-Path (Split-Path -Parent $ReleaseDir))) {
    Write-Warning "Không thấy $(Split-Path -Parent $ReleaseDir) (Google Drive cho máy tính chưa chạy?). Hãy tự chép các file trên và thư mục $symbols lên Google Drive."
    return
}
$backup = Join-Path $ReleaseDir $version
New-Item -ItemType Directory -Force -Path (Join-Path $backup 'symbols') | Out-Null
foreach ($f in $outputs) { Copy-Item $f $backup -Force }
Copy-Item (Join-Path $symbols '*') (Join-Path $backup 'symbols') -Recurse -Force
Write-Host "Đã sao lưu APK, web và symbols vào $backup"

# Dọn thư mục gốc: xoá APK / web zip của bản cũ đã có bản cùng kích thước
# trên Drive; bản chưa sao lưu thì giữ lại.
$keep = $outputs | ForEach-Object { Split-Path -Leaf $_ }
Get-ChildItem $root -File | Where-Object {
    ($_.Name -like 'DTCProduct-*.apk' -or $_.Name -like 'DTCProduct-web-*.zip') -and ($keep -notcontains $_.Name)
} | ForEach-Object {
    if ($_.Name -match '^DTCProduct-(?:web-)?(\d+\.\d+\.\d+\+\d+)') {
        $copy = Join-Path (Join-Path $ReleaseDir $Matches[1]) $_.Name
        if ((Test-Path $copy) -and (Get-Item $copy).Length -eq $_.Length) {
            Remove-Item $_.FullName
            Write-Host "Đã dọn $($_.Name) (đã có trên Drive)"
        }
    }
}
