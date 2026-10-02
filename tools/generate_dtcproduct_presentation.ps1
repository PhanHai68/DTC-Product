param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$OutputDir = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'output'),
  [switch]$SkipReport
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function Rgb([int]$r, [int]$g, [int]$b) { return $r + ($g * 256) + ($b * 65536) }

$Navy = Rgb 12 36 68
$Blue = Rgb 24 113 181
$Cyan = Rgb 0 174 199
$Sky = Rgb 229 246 249
$Orange = Rgb 244 129 32
$Green = Rgb 35 145 95
$Red = Rgb 211 61 75
$Ink = Rgb 25 39 57
$Muted = Rgb 88 106 124
$Border = Rgb 216 225 233
$Light = Rgb 246 249 251
$White = Rgb 255 255 255
$PaleOrange = Rgb 255 244 232
$PaleGreen = Rgb 232 247 239

$logo = Join-Path $ProjectRoot 'assets\images\dtc_product_wordmark_full.png'
$appIcon = Join-Path $ProjectRoot 'assets\images\app_icon.png'
$slogan = Join-Path $ProjectRoot 'assets\images\DTCGroup-Slogan.png'
$imgSorter = Join-Path $ProjectRoot 'assets\images\home_color_sorter_5_chutes_v5.png'
$imgPacking = Join-Path $ProjectRoot 'assets\images\home_packing_lzb1200.jpg'
$imgCompressor = Join-Path $ProjectRoot 'assets\images\home_air_compressor_v5.png'
$imgGrinding = Join-Path $ProjectRoot 'assets\images\home_grinding_machine_asp350.png'
$imgLayout = Join-Path $ProjectRoot 'assets\images\So_do_lap_dat.png'

function Set-SlideBackground($slide, [int]$color) {
  $slide.FollowMasterBackground = 0
  $slide.Background.Fill.Solid()
  $slide.Background.Fill.ForeColor.RGB = $color
}

function Add-Shape($slide, [int]$type, [double]$x, [double]$y, [double]$w, [double]$h, [int]$fill, [int]$line = -1, [double]$radius = 0) {
  $shape = $slide.Shapes.AddShape($type, $x, $y, $w, $h)
  $shape.Fill.Solid()
  $shape.Fill.ForeColor.RGB = $fill
  if ($line -lt 0) { $shape.Line.Visible = 0 } else { $shape.Line.Visible = -1; $shape.Line.ForeColor.RGB = $line; $shape.Line.Weight = 1 }
  return $shape
}

function Add-Text($slide, [string]$text, [double]$x, [double]$y, [double]$w, [double]$h, [double]$size = 18, [int]$color = $Ink, [bool]$bold = $false, [int]$align = 1, [string]$font = 'Aptos', [int]$valign = 1) {
  $tb = $slide.Shapes.AddTextbox(1, $x, $y, $w, $h)
  $tb.TextFrame.MarginLeft = 0
  $tb.TextFrame.MarginRight = 0
  $tb.TextFrame.MarginTop = 0
  $tb.TextFrame.MarginBottom = 0
  $tb.TextFrame.WordWrap = -1
  $tb.TextFrame.VerticalAnchor = $valign
  $tr = $tb.TextFrame.TextRange
  $tr.Text = $text
  $tr.Font.Name = $font
  $tr.Font.Size = $size
  $tr.Font.Bold = if ($bold) { -1 } else { 0 }
  $tr.Font.Color.RGB = $color
  $tr.ParagraphFormat.Alignment = $align
  return $tb
}

function Add-Title($slide, [string]$title, [string]$kicker = '') {
  if ($kicker) { Add-Text $slide $kicker.ToUpper() 48 28 600 20 10 $Cyan $true | Out-Null }
  Add-Text $slide $title 48 54 840 54 29 $Navy $true | Out-Null
  Add-Shape $slide 1 48 112 70 4 $Cyan | Out-Null
}

function Add-Footer($slide, [int]$number, [bool]$dark = $false) {
  $color = if ($dark) { Rgb 190 211 226 } else { $Muted }
  Add-Text $slide 'DTCProduct • Giới thiệu chức năng & ứng dụng thực tế' 48 510 600 16 8.5 $color $false | Out-Null
  Add-Text $slide ("{0:00}" -f $number) 880 508 32 18 9 $color $true 3 | Out-Null
}

function Add-Pill($slide, [string]$text, [double]$x, [double]$y, [double]$w, [int]$fill, [int]$textColor = $Navy) {
  Add-Shape $slide 5 $x $y $w 28 $fill | Out-Null
  Add-Text $slide $text ($x + 8) ($y + 6) ($w - 16) 16 10 $textColor $true 2 | Out-Null
}

function Add-Card($slide, [double]$x, [double]$y, [double]$w, [double]$h, [string]$tag, [string]$title, [string]$body, [int]$accent = $Cyan, [int]$fill = $White) {
  $card = Add-Shape $slide 5 $x $y $w $h $fill $Border
  Add-Shape $slide 5 ($x + 14) ($y + 15) 38 38 $accent | Out-Null
  Add-Text $slide $tag ($x + 14) ($y + 25) 38 18 11 $White $true 2 | Out-Null
  Add-Text $slide $title ($x + 64) ($y + 15) ($w - 78) 28 15 $Navy $true | Out-Null
  Add-Text $slide $body ($x + 18) ($y + 62) ($w - 36) ($h - 74) 11.3 $Muted $false | Out-Null
  return $card
}

function Add-PictureContain($slide, [string]$path, [double]$x, [double]$y, [double]$w, [double]$h) {
  if (-not (Test-Path $path)) { return $null }
  Add-Type -AssemblyName System.Drawing
  $img = [System.Drawing.Image]::FromFile($path)
  try {
    $scale = [Math]::Min($w / $img.Width, $h / $img.Height)
    $iw = $img.Width * $scale
    $ih = $img.Height * $scale
    return $slide.Shapes.AddPicture($path, 0, -1, $x + (($w - $iw) / 2), $y + (($h - $ih) / 2), $iw, $ih)
  } finally { $img.Dispose() }
}

function Add-Notes($slide, [string]$notes) {
  try {
    $placeholder = $slide.NotesPage.Shapes.Placeholders.Item(2)
    $placeholder.TextFrame.TextRange.Text = $notes
  } catch { }
}

function Add-FlowStep($slide, [int]$n, [string]$title, [string]$body, [double]$x, [double]$y, [double]$w, [int]$color) {
  Add-Shape $slide 9 $x $y 44 44 $color | Out-Null
  Add-Text $slide ([string]$n) $x ($y + 10) 44 22 15 $White $true 2 | Out-Null
  Add-Text $slide $title ($x + 58) ($y - 1) ($w - 58) 24 13.5 $Navy $true | Out-Null
  Add-Text $slide $body ($x + 58) ($y + 25) ($w - 58) 42 10.3 $Muted | Out-Null
}

$ppt = $null
$word = $null
try {
  $ppt = New-Object -ComObject PowerPoint.Application
  $ppt.Visible = -1
  $deck = $ppt.Presentations.Add()
  $deck.PageSetup.SlideWidth = 960
  $deck.PageSetup.SlideHeight = 540

  # Slide 1 — Cover
  $s = $deck.Slides.Add(1, 12)
  Set-SlideBackground $s $Navy
  Add-Shape $s 9 690 -90 350 350 (Rgb 16 64 102) | Out-Null
  Add-Shape $s 9 770 302 250 250 $Cyan | Out-Null
  Add-Shape $s 1 0 0 14 540 $Cyan | Out-Null
  Add-PictureContain $s $logo 54 42 360 80 | Out-Null
  Add-Text $s 'GIỚI THIỆU ỨNG DỤNG' 56 150 500 24 12 $Cyan $true | Out-Null
  Add-Text $s 'DTCProduct' 54 180 600 72 42 $White $true | Out-Null
  Add-Text $s 'Từ dữ liệu sản phẩm đến quyết định kỹ thuật tại hiện trường' 56 258 590 70 21 (Rgb 223 235 244) $false | Out-Null
  Add-Pill $s 'Tra cứu' 56 355 100 (Rgb 23 73 113) $White
  Add-Pill $s 'Tính toán' 168 355 110 (Rgb 23 73 113) $White
  Add-Pill $s 'Triển khai' 290 355 110 (Rgb 23 73 113) $White
  Add-Pill $s 'Báo cáo' 412 355 105 (Rgb 23 73 113) $White
  Add-PictureContain $s $appIcon 710 120 185 185 | Out-Null
  Add-Text $s 'Phiên bản mã nguồn 1.0.14+15  •  29/09/2026' 56 474 560 18 10 (Rgb 169 197 218) | Out-Null
  Add-Notes $s 'Kính chào quý anh/chị. Hôm nay tôi xin giới thiệu DTCProduct — một ứng dụng hỗ trợ xuyên suốt từ tra cứu sản phẩm, tư vấn lựa chọn thiết bị, tính toán kỹ thuật cho đến quản lý triển khai và lập báo cáo tại hiện trường. Trọng tâm của phần trình bày là chức năng và giá trị ứng dụng thực tế.'

  # Slide 2 — Context
  $s = $deck.Slides.Add(2, 12); Set-SlideBackground $s $Light
  Add-Title $s 'Vấn đề DTCProduct hướng tới' 'Bối cảnh'
  Add-Card $s 48 145 260 230 '01' 'Dữ liệu phân tán' 'Thông số, catalog, bản vẽ và hướng dẫn nằm ở nhiều file; tìm kiếm chậm và khó đảm bảo đúng phiên bản.' $Red | Out-Null
  Add-Card $s 350 145 260 230 '02' 'Tính toán thủ công' 'Chọn máy, tính năng suất, điện, đường ống hay hoàn vốn dễ phụ thuộc vào bảng tính và kinh nghiệm cá nhân.' $Orange | Out-Null
  Add-Card $s 652 145 260 230 '03' 'Hồ sơ hiện trường rời rạc' 'Ảnh, tiến độ, biên bản bảo trì và thông tin khách hàng chưa liên kết thành một quy trình thống nhất.' $Blue | Out-Null
  Add-Shape $s 5 140 408 680 58 $Navy | Out-Null
  Add-Text $s 'Mục tiêu: đưa đúng dữ liệu và đúng công cụ đến đúng người — ngay tại thời điểm ra quyết định.' 168 424 624 24 14 $White $true 2 | Out-Null
  Add-Footer $s 2
  Add-Notes $s 'Trong thực tế, khó khăn không hẳn là thiếu dữ liệu, mà là dữ liệu nằm rải rác và mất thời gian để chuyển thành quyết định. DTCProduct gom dữ liệu sản phẩm, công thức kỹ thuật và hồ sơ công việc vào một điểm truy cập, phù hợp với nhân viên kinh doanh, kỹ thuật và quản lý.'

  # Slide 3 — Overview
  $s = $deck.Slides.Add(3, 12); Set-SlideBackground $s $White
  Add-Title $s 'Một nền tảng nghiệp vụ theo vòng đời thiết bị' 'Tổng quan'
  $cx = 480; $cy = 290
  Add-Shape $s 9 385 195 190 190 $Navy | Out-Null
  Add-PictureContain $s $appIcon 425 225 110 110 | Out-Null
  Add-Text $s 'DTCProduct' 405 342 150 20 12 $White $true 2 | Out-Null
  $nodes = @(
    @{x=90;y=150;t='TRA CỨU';b='Sản phẩm • catalog • 3D';c=$Blue},
    @{x=660;y=150;t='TƯ VẤN';b='Chọn máy • so sánh';c=$Cyan},
    @{x=90;y=350;t='TRIỂN KHAI';b='Mặt bằng • dự án';c=$Orange},
    @{x=660;y=350;t='HẬU MÃI';b='Bảo trì • báo cáo';c=$Green}
  )
  foreach($n in $nodes){
    Add-Shape $s 5 $n.x $n.y 210 88 $White $Border | Out-Null
    Add-Shape $s 1 $n.x $n.y 7 88 $n.c | Out-Null
    Add-Text $s $n.t ($n.x+20) ($n.y+15) 170 20 13 $Navy $true | Out-Null
    Add-Text $s $n.b ($n.x+20) ($n.y+44) 170 22 10.5 $Muted | Out-Null
  }
  Add-Text $s 'Kinh doanh' 374 142 90 18 10 $Muted $true 2 | Out-Null
  Add-Text $s 'Kỹ thuật' 466 142 90 18 10 $Muted $true 2 | Out-Null
  Add-Text $s 'Quản lý' 420 405 120 18 10 $Muted $true 2 | Out-Null
  Add-Footer $s 3
  Add-Notes $s 'Có thể hình dung DTCProduct như một nền tảng nghiệp vụ theo vòng đời thiết bị. Trước bán hàng, ứng dụng hỗ trợ tra cứu và tư vấn. Khi chốt phương án, ứng dụng hỗ trợ tính toán và bố trí. Trong triển khai, ứng dụng theo dõi dự án. Sau bàn giao, dữ liệu tiếp tục được dùng cho bảo trì và báo cáo.'

  # Slide 4 — Product portfolio
  $s = $deck.Slides.Add(4, 12); Set-SlideBackground $s $Light
  Add-Title $s 'Hệ sinh thái sản phẩm tích hợp' 'Danh mục thiết bị'
  $products = @(
    @{x=48;img=$imgSorter;tag='01';title='Máy tách màu';body='Gạo, thóc/gạo xô, trà, khoáng sản, nông sản; thông số, phụ trợ, hoàn vốn, bản vẽ, lỗi và tài liệu.';c=$Cyan},
    @{x=274;img=$imgPacking;tag='02';title='Cân đóng gói';body='Danh mục, tìm model, chọn theo yêu cầu, so sánh; xem catalog và thông số đóng gói, hiệu suất, điện – khí.';c=$Blue},
    @{x=500;img=$imgCompressor;tag='03';title='Máy nén khí';body='Chọn công suất, bình chứa, MCCB – dây điện, đường ống, thời gian nạp, vật tư, sự cố và vận hành.';c=$Orange},
    @{x=726;img=$imgGrinding;tag='04';title='Máy nghiền';body='Tra cứu, lọc, so sánh, chọn máy theo nguyên liệu – công suất – độ mịn; lập dự án và đề xuất kỹ thuật.';c=$Green}
  )
  foreach($p in $products){
    Add-Shape $s 5 $p.x 140 186 310 $White $Border | Out-Null
    Add-Shape $s 5 ($p.x+12) 152 162 112 (Rgb 240 245 248) | Out-Null
    Add-PictureContain $s $p.img ($p.x+20) 158 146 98 | Out-Null
    Add-Shape $s 9 ($p.x+18) 244 34 34 $p.c | Out-Null
    Add-Text $s $p.tag ($p.x+18) 252 34 16 9.5 $White $true 2 | Out-Null
    Add-Text $s $p.title ($p.x+18) 286 150 25 14 $Navy $true | Out-Null
    Add-Text $s $p.body ($p.x+18) 321 150 112 9.7 $Muted | Out-Null
  }
  Add-Footer $s 4
  Add-Notes $s 'Trang chủ hiện tổ chức bốn nhóm thiết bị chính. Điểm đáng chú ý là mỗi nhóm không chỉ có hình ảnh sản phẩm mà còn gắn với nghiệp vụ riêng. Ví dụ máy nén khí có bộ công cụ chọn công suất và đường ống; máy nghiền có luồng lọc, so sánh và lập đề xuất; máy tách màu có dữ liệu theo từng nhóm nguyên liệu.'

  # Slide 5 — Sales journey
  $s = $deck.Slides.Add(5, 12); Set-SlideBackground $s $White
  Add-Title $s 'Từ yêu cầu khách hàng đến đề xuất phù hợp' 'Quy trình tư vấn'
  Add-FlowStep $s 1 'Nhập nhu cầu' 'Nguyên liệu, năng suất, độ mịn, loại bao hoặc điều kiện vận hành.' 65 155 360 $Cyan
  Add-FlowStep $s 2 'Lọc và chọn máy' 'Đối chiếu dữ liệu kỹ thuật để tạo danh sách model phù hợp.' 535 155 360 $Blue
  Add-FlowStep $s 3 'So sánh phương án' 'So sánh thông số, công suất, đặc điểm và thiết bị phụ trợ.' 65 275 360 $Orange
  Add-FlowStep $s 4 'Chốt hồ sơ tư vấn' 'Xem catalog, mô hình 3D, tính chi phí/hoàn vốn và xuất tài liệu.' 535 275 360 $Green
  Add-Shape $s 5 185 410 590 50 $Sky | Out-Null
  Add-Text $s 'Kết quả: tư vấn nhất quán hơn, giảm phụ thuộc vào việc nhớ thông số và tìm file thủ công.' 210 425 540 20 12.5 $Navy $true 2 | Out-Null
  Add-Footer $s 5
  Add-Notes $s 'Luồng tư vấn bắt đầu từ nhu cầu khách hàng. Người dùng nhập các tiêu chí, ứng dụng hỗ trợ lọc và đề xuất model, sau đó đối chiếu thông số và mở catalog hoặc mô hình 3D. Đây là công cụ hỗ trợ ra quyết định; kết quả cuối cùng vẫn cần được kỹ thuật xác nhận theo điều kiện thực tế.'

  # Slide 6 — Engineering tools
  $s = $deck.Slides.Add(6, 12); Set-SlideBackground $s $Light
  Add-Title $s 'Bộ công cụ tính toán kỹ thuật tại chỗ' 'Năng lực nổi bật'
  Add-Card $s 48 140 270 135 'A' 'Năng suất & mẫu' 'Đo năng suất thực tế, ghi nhận mẫu, chụp ảnh và xuất phiếu kết quả PDF.' $Cyan | Out-Null
  Add-Card $s 345 140 270 135 'B' 'Điện & khí nén' 'Chọn máy nén, bình chứa, MCCB – dây điện, đường ống và tính thời gian nạp.' $Blue | Out-Null
  Add-Card $s 642 140 270 135 'C' 'Hiệu quả đầu tư' 'Ước tính tiền điện, lợi nhuận gia công/tự kinh doanh và thời gian hoàn vốn.' $Orange | Out-Null
  Add-Card $s 196 305 270 135 'D' 'Quy đổi kỹ thuật' 'Quy đổi Mesh, kích thước ống, áp suất và lưu lượng ngay trên thiết bị.' $Green | Out-Null
  Add-Card $s 494 305 270 135 'E' 'Bố trí mặt bằng' 'Đặt máy, đo khoảng cách, kiểm tra chồng lấn, khoảng hở và chiều cao.' $Red | Out-Null
  Add-Footer $s 6
  Add-Notes $s 'Ngoài dữ liệu sản phẩm, giá trị khác biệt nằm ở bộ công cụ kỹ thuật. Các phép tính thường dùng được đưa vào điện thoại để dùng ngay tại nhà máy hoặc buổi khảo sát. Các kết quả có thể trở thành dữ liệu đầu vào cho đề xuất, biên bản hoặc báo cáo PDF.'

  # Slide 7 — Field project
  $s = $deck.Slides.Add(7, 12); Set-SlideBackground $s $White
  Add-Title $s 'Số hóa khảo sát và triển khai tại hiện trường' 'Project Timeline & mặt bằng'
  Add-Shape $s 5 48 140 360 320 $Navy | Out-Null
  Add-PictureContain $s $imgLayout 70 164 316 178 | Out-Null
  Add-Text $s 'Mặt bằng có thể kiểm tra' 70 365 310 24 16 $White $true | Out-Null
  Add-Text $s "• Kéo thả thiết bị, tường, cột, cửa, lối đi`n• Đo khoảng cách và đặt khoảng hở`n• Cảnh báo chồng lấn, ngoài vùng và thiếu chiều cao" 70 398 300 56 10.5 (Rgb 211 228 239) | Out-Null
  Add-FlowStep $s 1 'Tạo dự án' 'Khách hàng, địa điểm, phụ trách và danh sách máy.' 470 145 410 $Cyan
  Add-FlowStep $s 2 'Theo dõi giai đoạn' 'Lịch thực hiện, checklist, trạng thái và nhắc hạn.' 470 225 410 $Blue
  Add-FlowStep $s 3 'Ghi nhận hiện trường' 'Ảnh nguyên liệu, thành phẩm, phế phẩm và kết quả chạy thử.' 470 305 410 $Orange
  Add-FlowStep $s 4 'Nghiệm thu & báo cáo' 'Tập hợp lịch sử, tài liệu, ảnh và tiến độ dự án.' 470 385 410 $Green
  Add-Footer $s 7
  Add-Notes $s 'Ở giai đoạn triển khai, DTCProduct hỗ trợ hai lớp công việc. Thứ nhất là bố trí mặt bằng: đặt thiết bị và kiểm tra khoảng hở, chồng lấn, chiều cao. Thứ hai là Project Timeline: quản lý các giai đoạn, ảnh hiện trường, chạy thử và nghiệm thu. Nhờ đó dữ liệu khảo sát không bị tách khỏi hồ sơ dự án.'

  # Slide 8 — Reports
  $s = $deck.Slides.Add(8, 12); Set-SlideBackground $s $Light
  Add-Title $s 'Biến thao tác hiện trường thành hồ sơ có thể chia sẻ' 'Báo cáo số'
  $cols = @(
    @{x=55;n='01';t='Ghi nhận';b='Thông tin khách hàng, máy, ngày thực hiện, kỹ thuật viên.';c=$Cyan},
    @{x=275;n='02';t='Minh chứng';b='Ảnh trước/sau, ảnh mẫu, kết quả vận hành và vật tư thay thế.';c=$Blue},
    @{x=495;n='03';t='Xác nhận';b='Checklist, kết luận, trạng thái hoàn thành và dấu xác minh ảnh.';c=$Orange},
    @{x=715;n='04';t='Xuất & chia sẻ';b='Tạo PDF theo mẫu thống nhất để lưu trữ hoặc gửi khách hàng.';c=$Green}
  )
  foreach($c in $cols){
    Add-Shape $s 5 $c.x 160 190 250 $White $Border | Out-Null
    Add-Shape $s 9 ($c.x+63) 125 64 64 $c.c | Out-Null
    Add-Text $s $c.n ($c.x+63) 143 64 24 14 $White $true 2 | Out-Null
    Add-Text $s $c.t ($c.x+20) 218 150 26 15 $Navy $true 2 | Out-Null
    Add-Text $s $c.b ($c.x+20) 260 150 104 10.8 $Muted $false 2 | Out-Null
  }
  Add-Text $s 'Áp dụng cho: form lưu mẫu • phiếu tính năng suất • báo cáo tình trạng máy • hồ sơ lựa chọn máy • báo cáo dự án' 86 442 788 26 11.5 $Navy $true 2 | Out-Null
  Add-Footer $s 8
  Add-Notes $s 'Ứng dụng giúp chuẩn hóa quá trình lập hồ sơ. Người dùng nhập thông tin, chụp ảnh minh chứng, hoàn thành checklist và xuất PDF. Hiện app hỗ trợ nhiều dạng hồ sơ như form lưu mẫu, phiếu năng suất, báo cáo tình trạng máy và báo cáo lựa chọn máy nghiền.'

  # Slide 9 — Real world scenarios
  $s = $deck.Slides.Add(9, 12); Set-SlideBackground $s $White
  Add-Title $s 'Ba tình huống ứng dụng thực tế' 'Use cases'
  Add-Card $s 48 142 278 300 '01' 'Tư vấn tại nhà máy' 'Nhân viên kinh doanh ghi nhận nhu cầu, tra cứu model, mở catalog/3D, so sánh phương án và minh họa thời gian hoàn vốn ngay trong buổi làm việc.' $Cyan $Sky | Out-Null
  Add-Card $s 341 142 278 300 '02' 'Khảo sát – lắp đặt' 'Kỹ thuật viên chụp ảnh hiện trường, dựng mặt bằng, kiểm tra khoảng hở/chiều cao, tính điện – khí và theo dõi các giai đoạn triển khai.' $Orange $PaleOrange | Out-Null
  Add-Card $s 634 142 278 300 '03' 'Bảo trì – hậu mãi' 'Tạo lịch nhắc, ghi hạng mục đã làm, vật tư thay thế, ảnh trước/sau, kết luận tình trạng máy và gửi báo cáo PDF cho khách hàng.' $Green $PaleGreen | Out-Null
  Add-Footer $s 9
  Add-Notes $s 'Ba tình huống này cho thấy DTCProduct không chỉ phục vụ tra cứu. Trong bán hàng, app rút ngắn thời gian chuẩn bị. Trong khảo sát và lắp đặt, app hỗ trợ tính toán và ghi nhận. Trong hậu mãi, app tạo lịch sử bảo trì có minh chứng và báo cáo chuẩn hóa.'

  # Slide 10 — Benefits
  $s = $deck.Slides.Add(10, 12); Set-SlideBackground $s $Navy
  Add-Text $s 'GIÁ TRỊ MANG LẠI' 48 30 500 20 10 $Cyan $true | Out-Null
  Add-Text $s 'Một nguồn dữ liệu — nhiều quyết định tốt hơn' 48 60 820 50 28 $White $true | Out-Null
  $benefits = @(
    @{x=48;y=145;n='01';t='Nhanh hơn';b='Giảm thời gian tìm tài liệu, tra model và chuẩn bị biểu mẫu.'},
    @{x=355;y=145;n='02';t='Nhất quán hơn';b='Cùng một nguồn thông số và cùng cấu trúc báo cáo cho toàn đội.'},
    @{x=662;y=145;n='03';t='Ít sai sót hơn';b='Công thức, bộ lọc và cảnh báo hỗ trợ kiểm tra trước khi chốt.'},
    @{x=48;y=305;n='04';t='Minh bạch hơn';b='Có ảnh, timeline, trạng thái và hồ sơ PDF để truy vết công việc.'},
    @{x=355;y=305;n='05';t='Chuyên nghiệp hơn';b='Tư vấn trực quan bằng hình ảnh, catalog, mô hình 3D và báo cáo.'},
    @{x=662;y=305;n='06';t='Dùng tại hiện trường';b='Dữ liệu nghiệp vụ cốt lõi được đóng gói trong ứng dụng client.'}
  )
  foreach($b in $benefits){
    Add-Shape $s 5 $b.x $b.y 250 125 (Rgb 18 54 88) (Rgb 37 86 123) | Out-Null
    Add-Text $s $b.n ($b.x+18) ($b.y+16) 35 18 11 $Cyan $true | Out-Null
    Add-Text $s $b.t ($b.x+18) ($b.y+43) 210 24 15 $White $true | Out-Null
    Add-Text $s $b.b ($b.x+18) ($b.y+75) 210 40 10.2 (Rgb 205 222 235) | Out-Null
  }
  Add-Footer $s 10 $true
  Add-Notes $s 'Giá trị của DTCProduct có thể tóm gọn ở sáu điểm: nhanh, nhất quán, giảm sai sót, minh bạch, chuyên nghiệp và thuận tiện tại hiện trường. Đây là lợi ích định tính; để lượng hóa, doanh nghiệp nên theo dõi thời gian chuẩn bị hồ sơ, tỷ lệ sai thông số, thời gian hoàn thành báo cáo và mức độ tái sử dụng dữ liệu.'

  # Slide 11 — Architecture / caveats
  $s = $deck.Slides.Add(11, 12); Set-SlideBackground $s $Light
  Add-Title $s 'Cách vận hành và phạm vi hiện tại' 'Dữ liệu & nền tảng'
  Add-Card $s 48 140 270 145 '01' 'Client-first' 'Dữ liệu nghiệp vụ và dữ liệu người dùng được xử lý cục bộ theo mã nguồn hiện tại; thuận tiện khi làm việc tại hiện trường.' $Cyan | Out-Null
  Add-Card $s 345 140 270 145 '02' 'Nhiều định dạng' 'Tích hợp cơ sở dữ liệu, hình ảnh, PDF, video và mô hình 3D trong cùng ứng dụng.' $Blue | Out-Null
  Add-Card $s 642 140 270 145 '03' 'Đa nền tảng' 'Android/iOS là hướng phát hành chính; mã nguồn có cấu hình Web, Windows, Linux và macOS.' $Green | Out-Null
  Add-Shape $s 5 48 320 864 116 $White $Border | Out-Null
  Add-Text $s 'Lưu ý khi áp dụng' 70 340 200 24 14 $Navy $true | Out-Null
  Add-Text $s "• Kết quả chọn máy và tính toán cần được kỹ thuật xác nhận theo dữ liệu thực tế.`n• Cần quản lý phiên bản database, nội dung catalog và quy trình sao lưu dữ liệu cục bộ.`n• Các nền tảng ngoài Android/iOS cần nghiệm thu riêng trước khi phát hành." 70 374 810 54 11 $Muted | Out-Null
  Add-Footer $s 11
  Add-Notes $s 'Về kỹ thuật, phiên bản hiện tại theo hướng client-first và sử dụng dữ liệu cục bộ. Điều này phù hợp với hiện trường nhưng cũng đặt ra yêu cầu sao lưu và quản lý phiên bản dữ liệu. Android và iOS là hướng phát hành chính; các nền tảng khác đã có cấu hình nhưng cần kiểm thử riêng. Các phép tính luôn cần được đối chiếu với điều kiện thực tế và chuyên môn kỹ thuật.'

  # Slide 12 — Close & demo
  $s = $deck.Slides.Add(12, 12); Set-SlideBackground $s $White
  Add-Shape $s 1 0 0 310 540 $Navy | Out-Null
  Add-PictureContain $s $appIcon 75 90 160 160 | Out-Null
  Add-Text $s 'DTCProduct' 56 285 200 35 25 $White $true 2 | Out-Null
  Add-Text $s "Dữ liệu đúng`nCông cụ đúng`nQuyết định đúng" 56 338 200 88 17 (Rgb 210 229 241) $true 2 | Out-Null
  Add-Text $s 'GỢI Ý DEMO 5 PHÚT' 370 60 430 22 11 $Cyan $true | Out-Null
  Add-FlowStep $s 1 'Chọn nhóm thiết bị' 'Mở trang chủ và giới thiệu bốn danh mục sản phẩm.' 370 110 480 $Cyan
  Add-FlowStep $s 2 'Thực hiện một bài toán' 'Ví dụ: chọn máy, tính năng suất hoặc tính đường ống khí nén.' 370 195 480 $Blue
  Add-FlowStep $s 3 'Mở công cụ hiện trường' 'Minh họa bố trí mặt bằng hoặc Project Timeline.' 370 280 480 $Orange
  Add-FlowStep $s 4 'Xuất một báo cáo PDF' 'Kết thúc bằng form lưu mẫu hoặc báo cáo tình trạng máy.' 370 365 480 $Green
  Add-Text $s 'Xin cảm ơn — Q&A' 370 472 420 30 18 $Navy $true | Out-Null
  Add-Footer $s 12
  Add-Notes $s 'Kết luận: DTCProduct kết nối dữ liệu sản phẩm với công việc thực tế của kinh doanh, kỹ thuật và quản lý. Nếu demo trực tiếp, tôi đề xuất đi theo bốn bước trên để khán giả thấy rõ luồng từ tra cứu đến báo cáo. Xin cảm ơn và sẵn sàng trao đổi.'

  $pptxPath = Join-Path $OutputDir 'DTCProduct_Gioi_thieu_Chuc_nang_Ung_dung.pptx'
  $pptPdfPath = Join-Path $OutputDir 'DTCProduct_Gioi_thieu_Chuc_nang_Ung_dung.pdf'
  $deck.SaveAs($pptxPath, 24)
  $deck.SaveAs($pptPdfPath, 32)

  if ($SkipReport) {
    $deck.Close()
    $ppt.Quit()
    $ppt = $null
    Write-Output "Created: $pptxPath"
    Write-Output "Created: $pptPdfPath"
    return
  }

  # Create Word report
  $word = New-Object -ComObject Word.Application
  $word.Visible = $false
  $doc = $word.Documents.Add()
  $doc.PageSetup.TopMargin = 56.7
  $doc.PageSetup.BottomMargin = 56.7
  $doc.PageSetup.LeftMargin = 65
  $doc.PageSetup.RightMargin = 65

  $normal = $doc.Styles.Item('Normal')
  $normal.Font.Name = 'Aptos'
  $normal.Font.Size = 11
  $normal.ParagraphFormat.SpaceAfter = 6
  $normal.ParagraphFormat.LineSpacingRule = 1

  function Add-WParagraph([string]$text, [string]$style = 'Normal', [int]$align = 0, [bool]$bold = $false, [int]$size = 0, [int]$color = -1) {
    $p = $doc.Content.Paragraphs.Add()
    $p.Range.Text = $text
    try { $p.Range.Style = $style } catch { }
    $p.Alignment = $align
    if ($bold) { $p.Range.Font.Bold = -1 }
    if ($size -gt 0) { $p.Range.Font.Size = $size }
    if ($color -ge 0) { $p.Range.Font.Color = $color }
    $p.Range.InsertParagraphAfter()
    return $p
  }

  function Add-WHeading([string]$text, [int]$level = 1) {
    $p = Add-WParagraph $text ("Heading $level")
    $p.Range.Font.Name = 'Aptos Display'
    $p.Range.Font.Color = $Navy
    return $p
  }

  function Add-WBullet([string]$text) {
    $p = Add-WParagraph $text
    $p.Range.ListFormat.ApplyBulletDefault()
    return $p
  }

  # Cover
  Add-WParagraph '' | Out-Null
  $range = $doc.Content
  $range.Collapse(0)
  if (Test-Path $logo) {
    $pic = $range.InlineShapes.AddPicture($logo)
    $pic.LockAspectRatio = -1
    $pic.Width = 260
  }
  Add-WParagraph '' | Out-Null
  Add-WParagraph 'BÁO CÁO GIỚI THIỆU ỨNG DỤNG' 'Title' 1 $true 18 $Cyan | Out-Null
  Add-WParagraph 'DTCProduct' 'Title' 1 $true 32 $Navy | Out-Null
  Add-WParagraph 'Chức năng và ứng dụng thực tế' 'Subtitle' 1 $false 18 $Muted | Out-Null
  Add-WParagraph '' | Out-Null
  Add-WParagraph 'Phiên bản mã nguồn khảo sát: 1.0.14+15' 'Normal' 1 $false 11 $Muted | Out-Null
  Add-WParagraph 'Ngày soạn: 29/09/2026' 'Normal' 1 $false 11 $Muted | Out-Null
  Add-WParagraph 'DTC Group' 'Normal' 1 $true 12 $Navy | Out-Null
  $doc.Words.Last.InsertBreak(7)

  Add-WHeading 'TÓM TẮT ĐIỀU HÀNH' 1 | Out-Null
  Add-WParagraph 'DTCProduct là ứng dụng Flutter hỗ trợ tra cứu sản phẩm và các nghiệp vụ kỹ thuật của DTC Group. Ứng dụng tổ chức dữ liệu quanh bốn nhóm thiết bị chính: máy tách màu, cân đóng gói, máy nén khí và máy nghiền; đồng thời cung cấp bộ công cụ phục vụ tư vấn, tính toán, khảo sát, triển khai dự án, bảo trì và lập báo cáo.' | Out-Null
  Add-WParagraph 'Điểm nổi bật của DTCProduct là kết nối dữ liệu sản phẩm với quy trình làm việc thực tế. Người dùng có thể đi từ yêu cầu khách hàng đến lựa chọn model, tính toán phương án, kiểm tra mặt bằng, theo dõi dự án và xuất báo cáo PDF ngay trong một hệ thống. Theo mã nguồn hiện tại, dữ liệu nghiệp vụ và dữ liệu người dùng chủ yếu được xử lý phía client, phù hợp cho công việc tại hiện trường.' | Out-Null
  Add-WParagraph 'Giá trị kỳ vọng gồm: giảm thời gian tìm kiếm tài liệu; chuẩn hóa cách tư vấn và báo cáo; hạn chế sai sót do nhập liệu hoặc dùng nhầm phiên bản; tăng khả năng truy vết công việc bằng ảnh, trạng thái và timeline; nâng cao tính chuyên nghiệp khi làm việc với khách hàng.' | Out-Null

  Add-WHeading '1. MỤC TIÊU VÀ ĐỐI TƯỢNG SỬ DỤNG' 1 | Out-Null
  Add-WHeading '1.1. Mục tiêu' 2 | Out-Null
  Add-WBullet 'Tập trung thông số kỹ thuật, catalog, tài liệu vận hành, hình ảnh và mô hình 3D vào một điểm truy cập.' | Out-Null
  Add-WBullet 'Hỗ trợ lựa chọn thiết bị và thực hiện các phép tính kỹ thuật thường dùng.' | Out-Null
  Add-WBullet 'Chuẩn hóa việc ghi nhận hiện trường, theo dõi dự án và lập báo cáo.' | Out-Null
  Add-WBullet 'Tạo nền tảng dữ liệu dùng chung cho kinh doanh, kỹ thuật và quản lý.' | Out-Null
  Add-WHeading '1.2. Đối tượng sử dụng' 2 | Out-Null
  Add-WBullet 'Nhân viên kinh doanh: tra cứu, so sánh, tư vấn và theo dõi mục tiêu doanh số/cơ hội.' | Out-Null
  Add-WBullet 'Kỹ sư và kỹ thuật viên: tính toán, khảo sát mặt bằng, ghi nhận mẫu, bảo trì và xử lý sự cố.' | Out-Null
  Add-WBullet 'Quản lý dự án: theo dõi giai đoạn, lịch, ảnh hiện trường, nghiệm thu và hồ sơ.' | Out-Null
  Add-WBullet 'Quản lý bộ phận: theo dõi tiến độ công việc và chuẩn hóa nguồn dữ liệu nội bộ.' | Out-Null

  Add-WHeading '2. CÁC NHÓM CHỨC NĂNG CHÍNH' 1 | Out-Null
  Add-WHeading '2.1. Tra cứu danh mục thiết bị' 2 | Out-Null
  Add-WParagraph 'Máy tách màu được phân nhóm theo nguyên liệu gồm gạo, thóc/gạo xô, trà, khoáng sản và nông sản. Tùy nhóm, người dùng có thể xem thông số, thiết bị phụ trợ, phân tích hoàn vốn, bản vẽ lắp đặt, lỗi thường gặp và tài liệu vận hành.' | Out-Null
  Add-WParagraph 'Cân đóng gói có các luồng danh mục sản phẩm, tìm nhanh theo model, chọn máy theo yêu cầu và so sánh model. Màn hình chi tiết tổ chức thông tin theo đóng gói, hiệu suất, điện – khí, kích thước và ghi chú; đồng thời liên kết catalog PDF.' | Out-Null
  Add-WParagraph 'Máy nén khí ACOMP tích hợp thông số kỹ thuật, chọn công suất phù hợp, tính bình chứa, chọn MCCB và dây điện, tính đường ống, bản vẽ lắp đặt, danh sách vật tư, thời gian nạp đầy bình, hướng dẫn xử lý sự cố và tài liệu vận hành.' | Out-Null
  Add-WParagraph 'Máy nghiền hỗ trợ tra cứu, tìm kiếm, lọc và so sánh; lựa chọn theo nguyên liệu, công suất, độ mịn, kích thước đầu vào và yêu cầu đặc biệt; đồng thời quản lý dự án lựa chọn máy và đề xuất kỹ thuật.' | Out-Null

  Add-WHeading '2.2. Công cụ kỹ thuật và phân tích' 2 | Out-Null
  Add-WBullet 'Tính năng suất thực tế và xuất phiếu kết quả PDF.' | Out-Null
  Add-WBullet 'Chuyển đổi Mesh, kích thước ống, áp suất và lưu lượng.' | Out-Null
  Add-WBullet 'Tính điện năng, tiền điện, lợi nhuận gia công/tự kinh doanh và thời gian hoàn vốn.' | Out-Null
  Add-WBullet 'Tính toán hệ thống khí nén: công suất máy, thể tích bình, MCCB – dây điện, đường ống và thời gian nạp.' | Out-Null
  Add-WBullet 'Bố trí mặt bằng: đặt máy và các đối tượng, đo khoảng cách, kiểm tra chồng lấn, phạm vi, khoảng hở và chiều cao.' | Out-Null

  Add-WHeading '2.3. Quản lý công việc và dữ liệu hiện trường' 2 | Out-Null
  Add-WParagraph 'Project Timeline cho phép tạo dự án, gắn máy, theo dõi các giai đoạn, lịch thực hiện, checklist, ảnh hiện trường, kết quả chạy thử và nghiệm thu. Mỗi máy có thể tập hợp thông tin, lịch sử lắp đặt, hình ảnh, bảo trì, sự cố, tài liệu và timeline.' | Out-Null
  Add-WParagraph 'Nhóm tiện ích còn có ghi chú và nhắc hẹn, mục tiêu hằng ngày, lịch bảo trì, mục tiêu doanh số, pipeline cơ hội, quản lý dung lượng tệp và tìm kiếm toàn cục.' | Out-Null

  Add-WHeading '2.4. Báo cáo và chia sẻ' 2 | Out-Null
  Add-WParagraph 'Ứng dụng hỗ trợ chụp/lưu ảnh và xuất PDF cho nhiều nghiệp vụ: form lưu mẫu, phiếu tính năng suất, báo cáo tình trạng máy, báo cáo lựa chọn máy nghiền và báo cáo dự án. Báo cáo bảo trì có thể ghi hạng mục công việc, vật tư thay thế, tình trạng sau bảo trì, ảnh trước/sau và kết quả cuối cùng.' | Out-Null

  Add-WHeading '3. ỨNG DỤNG THỰC TẾ' 1 | Out-Null
  Add-WHeading '3.1. Tư vấn thiết bị tại nhà máy khách hàng' 2 | Out-Null
  Add-WParagraph 'Nhân viên kinh doanh tiếp nhận nhu cầu về nguyên liệu, năng suất hoặc quy cách đóng gói; dùng ứng dụng để tìm và lọc model, so sánh thông số, mở catalog/mô hình 3D và minh họa hiệu quả đầu tư. Hồ sơ tư vấn được chuẩn bị nhanh hơn và dựa trên cùng một nguồn dữ liệu.' | Out-Null
  Add-WHeading '3.2. Khảo sát và chuẩn bị phương án lắp đặt' 2 | Out-Null
  Add-WParagraph 'Kỹ thuật viên ghi nhận ảnh hiện trường, dựng sơ đồ mặt bằng, đặt vị trí máy, kiểm tra khoảng hở và chiều cao; đồng thời tính toán điện, khí nén và thiết bị phụ trợ. Kết quả được dùng làm đầu vào cho đề xuất kỹ thuật và kế hoạch triển khai.' | Out-Null
  Add-WHeading '3.3. Theo dõi thi công, chạy thử và nghiệm thu' 2 | Out-Null
  Add-WParagraph 'Quản lý dự án theo dõi tiến độ từng giai đoạn, phân công phụ trách, cập nhật checklist và ảnh. Trong giai đoạn chạy thử, có thể ghi nhận hình ảnh nguyên liệu, thành phẩm, phế phẩm và kết quả vận hành. Khi hoàn tất, hồ sơ hỗ trợ nghiệm thu và truy vết.' | Out-Null
  Add-WHeading '3.4. Bảo trì và chăm sóc sau bán hàng' 2 | Out-Null
  Add-WParagraph 'Kỹ thuật viên tạo lịch nhắc bảo trì, lập báo cáo tình trạng máy, ghi công việc đã thực hiện, vật tư thay thế và ảnh trước/sau. Báo cáo PDF có thể chia sẻ cho khách hàng và lưu làm lịch sử dịch vụ.' | Out-Null

  Add-WHeading '4. GIÁ TRỊ MANG LẠI' 1 | Out-Null
  $table = $doc.Tables.Add($doc.Content.Paragraphs.Add().Range, 6, 3)
  $table.Style = 'Table Grid'
  $table.Cell(1,1).Range.Text = 'Nhóm giá trị'; $table.Cell(1,2).Range.Text = 'Tác động'; $table.Cell(1,3).Range.Text = 'Chỉ số đề xuất'
  $rows = @(
    @('Hiệu suất','Giảm thời gian tìm dữ liệu và chuẩn bị hồ sơ','Thời gian/ca tư vấn; thời gian lập báo cáo'),
    @('Chất lượng','Dùng chung dữ liệu và quy trình chuẩn','Tỷ lệ sửa báo cáo; số lỗi sai thông số'),
    @('Minh bạch','Có ảnh, trạng thái, timeline và PDF','Tỷ lệ hồ sơ đủ minh chứng; công việc đúng hạn'),
    @('Khách hàng','Tư vấn trực quan và phản hồi nhanh','Thời gian gửi phương án; mức hài lòng'),
    @('Quản trị tri thức','Giảm phụ thuộc vào file cá nhân','Tỷ lệ tài liệu được cập nhật/tái sử dụng')
  )
  for($i=0;$i -lt $rows.Count;$i++){
    $table.Cell($i+2,1).Range.Text = $rows[$i][0]
    $table.Cell($i+2,2).Range.Text = $rows[$i][1]
    $table.Cell($i+2,3).Range.Text = $rows[$i][2]
  }
  $table.Rows.Item(1).Range.Bold = -1
  $table.Rows.Item(1).Shading.BackgroundPatternColor = $Navy
  $table.Rows.Item(1).Range.Font.Color = $White
  $doc.Content.Paragraphs.Add() | Out-Null

  Add-WHeading '5. PHẠM VI KỸ THUẬT VÀ LƯU Ý' 1 | Out-Null
  Add-WBullet 'Phiên bản mã nguồn khảo sát là 1.0.14+15.' | Out-Null
  Add-WBullet 'Android và iOS là nền tảng phát hành chính. Web, Windows, Linux và macOS có cấu hình hỗ trợ nhưng cần checklist nghiệm thu riêng.' | Out-Null
  Add-WBullet 'Theo mã nguồn hiện tại, dữ liệu nghiệp vụ và dữ liệu người dùng không được gửi lên máy chủ; dữ liệu bảo trì và các tệp người dùng được lưu cục bộ.' | Out-Null
  Add-WBullet 'Kết quả tính toán/chọn máy là công cụ hỗ trợ; kỹ thuật viên phải xác nhận dữ liệu đầu vào, điều kiện vận hành và yêu cầu an toàn trước khi áp dụng.' | Out-Null
  Add-WBullet 'Cần có quy trình cập nhật database, catalog, sao lưu/khôi phục và kiểm soát phiên bản ứng dụng.' | Out-Null

  Add-WHeading '6. ĐỀ XUẤT TRIỂN KHAI VÀ ĐÁNH GIÁ' 1 | Out-Null
  Add-WBullet 'Chọn 1–2 quy trình thí điểm, ví dụ tư vấn máy nén khí và báo cáo bảo trì.' | Out-Null
  Add-WBullet 'Chuẩn hóa chủ sở hữu dữ liệu cho từng nhóm sản phẩm; quy định chu kỳ rà soát thông số và tài liệu.' | Out-Null
  Add-WBullet 'Đào tạo theo tình huống thực tế, không chỉ giới thiệu menu.' | Out-Null
  Add-WBullet 'Theo dõi chỉ số trước và sau khi áp dụng: thời gian tìm thông tin, thời gian lập báo cáo, tỷ lệ hồ sơ đầy đủ và số lỗi phải chỉnh sửa.' | Out-Null
  Add-WBullet 'Đánh giá nhu cầu đồng bộ và phân quyền tập trung nếu quy mô người dùng hoặc yêu cầu cộng tác tăng.' | Out-Null

  Add-WHeading '7. KẾT LUẬN' 1 | Out-Null
  Add-WParagraph 'DTCProduct là nền tảng hỗ trợ nghiệp vụ có phạm vi rộng, kết nối tra cứu sản phẩm, tư vấn, tính toán kỹ thuật, triển khai dự án và hậu mãi. Ứng dụng có khả năng tạo giá trị rõ nhất khi dữ liệu được duy trì chính xác, quy trình sử dụng được chuẩn hóa và kết quả tính toán luôn được chuyên môn kỹ thuật xác nhận.' | Out-Null
  Add-WParagraph 'Thông điệp chính: DTCProduct giúp chuyển dữ liệu sản phẩm thành hành động có thể kiểm tra, lưu vết và chia sẻ.' 'Normal' 0 $true 12 $Navy | Out-Null

  Add-WHeading 'PHỤ LỤC — KỊCH BẢN THUYẾT TRÌNH 8–10 PHÚT' 1 | Out-Null
  $scriptItems = @(
    'Slide 1 (30 giây): Giới thiệu tên ứng dụng và thông điệp “từ dữ liệu sản phẩm đến quyết định kỹ thuật tại hiện trường”.',
    'Slide 2 (45 giây): Nêu ba vấn đề: dữ liệu phân tán, tính toán thủ công, hồ sơ hiện trường rời rạc.',
    'Slide 3 (45 giây): Giải thích vòng đời tra cứu – tư vấn – triển khai – hậu mãi và ba nhóm người dùng.',
    'Slide 4 (60 giây): Lướt qua bốn nhóm thiết bị, nhấn mạnh mỗi nhóm có nghiệp vụ riêng.',
    'Slide 5 (50 giây): Mô tả hành trình tư vấn từ yêu cầu đến hồ sơ đề xuất.',
    'Slide 6 (60 giây): Giới thiệu các công cụ tính toán quan trọng và cách dùng tại hiện trường.',
    'Slide 7 (60 giây): Minh họa bố trí mặt bằng và Project Timeline.',
    'Slide 8 (50 giây): Giải thích quy trình ghi nhận – minh chứng – xác nhận – xuất PDF.',
    'Slide 9 (60 giây): Kể ba tình huống thực tế: tư vấn, lắp đặt và bảo trì.',
    'Slide 10 (45 giây): Tóm tắt sáu nhóm lợi ích; nhấn mạnh nên đo lường bằng chỉ số.',
    'Slide 11 (45 giây): Nêu phạm vi nền tảng, dữ liệu cục bộ và các lưu ý kỹ thuật.',
    'Slide 12 (30 giây): Kết luận, gợi ý demo và mời đặt câu hỏi.'
  )
  foreach($item in $scriptItems){ Add-WBullet $item | Out-Null }

  # Header/footer and TOC-like fields
  foreach($section in $doc.Sections){
    $section.Headers.Item(1).Range.Text = 'DTCProduct | Báo cáo giới thiệu'
    $section.Headers.Item(1).Range.Font.Name = 'Aptos'
    $section.Headers.Item(1).Range.Font.Size = 8
    $section.Headers.Item(1).Range.Font.Color = $Muted
    $footer = $section.Footers.Item(1).Range
    $footer.Text = 'DTC Group  •  '
    $footer.Collapse(0)
    $footer.Fields.Add($footer, 33) | Out-Null
    $section.Footers.Item(1).Range.ParagraphFormat.Alignment = 2
    $section.Footers.Item(1).Range.Font.Size = 8
    $section.Footers.Item(1).Range.Font.Color = $Muted
  }

  $docxPath = Join-Path $OutputDir 'Bao_cao_Gioi_thieu_DTCProduct.docx'
  $reportPdfPath = Join-Path $OutputDir 'Bao_cao_Gioi_thieu_DTCProduct.pdf'
  $doc.SaveAs2($docxPath, 16)
  $doc.ExportAsFixedFormat($reportPdfPath, 17)

  $doc.Close(0)
  $word.Quit()
  $word = $null
  $deck.Close()
  $ppt.Quit()
  $ppt = $null

  Write-Output "Created: $pptxPath"
  Write-Output "Created: $pptPdfPath"
  Write-Output "Created: $docxPath"
  Write-Output "Created: $reportPdfPath"
}
finally {
  if ($word -ne $null) { try { $word.Quit() } catch {} }
  if ($ppt -ne $null) { try { $ppt.Quit() } catch {} }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
