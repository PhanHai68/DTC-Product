// Cấu hình đăng nhập bằng Firebase Authentication (gọi REST API, không dùng
// plugin Firebase nên chạy giống nhau trên web/Android/iOS).
//
// Web API key lấy ở Firebase Console → Project settings → General → Web API Key.
// Key này không phải bí mật (Firebase thiết kế để nằm trong app); bảo mật dựa
// trên việc TẮT tự đăng ký: Authentication → Settings → User actions → bỏ
// chọn "Enable create (sign-up)" để chỉ quản trị viên tạo được tài khoản.
const String firebaseWebApiKey = 'AIzaSyCch5bZCSY09EQ2IVq9Ybj6vC1ic1cL-9w';

/// Thời gian tối đa được dùng app mà không xác minh lại tài khoản qua mạng.
const Duration authOfflineGrace = Duration(days: 7);

/// Khoảng cách tối thiểu giữa 2 lần xác minh lại khi app mở/quay lại.
const Duration authRecheckInterval = Duration(hours: 1);
