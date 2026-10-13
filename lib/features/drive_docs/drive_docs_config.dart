// Cấu hình thư viện tài liệu PDF lưu trên Google Drive (gọi Drive API v3 bằng
// REST, không cần đăng nhập Google).
//
// Thiết lập một lần:
// 1. Tạo thư mục gốc trên Google Drive, chia sẻ "Bất kỳ ai có đường liên kết"
//    quyền Người xem. Thư mục con và file bên trong tự kế thừa quyền này.
//    ID thư mục là đoạn cuối của link: drive.google.com/drive/folders/<ID>.
// 2. Google Cloud Console (project "DTC Product", ID dtc-product-36a8c) → bật
//    "Google Drive API" → Credentials → Create credentials → API key → giới
//    hạn key (API restrictions) chỉ dùng Google Drive API.
//
// Key và ID không phải bí mật: ai có chúng chỉ đọc được các file đã chia sẻ
// công khai trong thư mục này — tương đương PDF đóng gói trong APK trước đây.
const String driveDocsApiKey = 'AIzaSyAad0YX8DYbJFv4eLmS-gHFgXV8bVsh-68';
const String driveDocsRootFolderId = '1WbpcwZPkGk5wEGpdSNsKw_l9eWfkL6yt';

/// Thứ tự thư mục ở cấp gốc, giống màn hình chính. Thư mục khác xếp sau
/// theo bảng chữ cái.
const List<String> driveDocsRootOrder = [
  'Máy tách màu',
  'Cân đóng gói',
  'Máy nén khí',
  'Máy nghiền',
  'Xay xát lúa gạo',
];
