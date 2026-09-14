const List<Map<String, dynamic>> ds8011Parameters = [
  {
    'category': 'Cài đặt cảnh báo nhiệt độ',
    'items': [
      {'code': 'F11', 'value': '10 – 45 ⁰C (Mặc định: 35⁰C)', 'description': 'Cảnh báo nhiệt điểm sương cao'},
      {'code': 'F12', 'value': '42 – 70 ⁰C (Mặc định: 65⁰C)', 'description': 'Cảnh báo nhiệt dàn ngưng cao'},
      {'code': 'F13', 'value': '0 – 500 giây (Mặc định: 120 giây)', 'description': 'Thời gian trễ phát hiện cảnh báo điểm sương'},
      {'code': 'F14', 'value': '0 – 600 giây (Mặc định: 0 giây)', 'description': 'Báo lỗi nhiệt dàn ngưng sau thời gian này'},
      {'code': 'F15', 'value': '0 – 600 giây (Mặc định: 300 giây)', 'description': 'Thời gian cảnh báo nhiệt điểm sương cao, nhiệt độ cao'},
      {'code': 'F18', 'value': '-10 ~ 10 ⁰C (Mặc định: 0 ⁰C)', 'description': 'Hiệu chỉnh cảm biến điểm sương'},
      {'code': 'F19', 'value': '-10 ~ 10 ⁰C (Mặc định: 0 ⁰C)', 'description': 'Hiệu chỉnh cảm biến dàn ngưng'},
    ]
  },
  {
    'category': 'Cài đặt lốc nén',
    'items': [
      {'code': 'F20', 'value': '10 – 300 giây (Mặc định: 60 giây)', 'description': 'Thời gian trễ khởi động lốc nén'},
      {'code': 'F21', 'value': '30 – 300 giây (Mặc định: 180 giây)', 'description': 'Thời gian trễ khởi động lại lốc nén'},
      {'code': 'F22', 'value': '0- Lốc chạy khi bật nguồn; 1- Lốc chạy theo nhiệt độ điểm sương (Mặc định: 1)', 'description': 'Chế độ chạy lốc nén'},
      {'code': 'F23', 'value': '-10 ~ 90 ⁰C (Mặc định: 2⁰C)', 'description': 'Nhiệt độ khởi động lốc nén'},
      {'code': 'F24', 'value': '0.5 – 25 ⁰C (Mặc định: 4⁰C)', 'description': 'Nhiệt độ điểm sương < [F23] – [F24] : Lốc nén dừng'},
      {'code': 'F25', 'value': '0 ~ 600 giây (Mặc định: 300 giây)', 'description': 'Thời gian Standby khi: Nhiệt độ điểm sương < [F23] – [F24]'},
    ]
  },
  {
    'category': 'Cài đặt quạt dàn ngưng và chế độ xả đá',
    'items': [
      {'code': 'F31', 'value': '-5 – 10 ⁰C (Mặc định: 2⁰C)', 'description': 'Nhiệt độ xả đá'},
      {'code': 'F32', 'value': '0.1 – 10 ⁰C (Mặc định: 2/0.5⁰C)', 'description': 'Nhiệt độ điểm sương > [F31] + [F32]: dừng xả đá'},
      {'code': 'F40', 'value': '0-Không sử dụng; 1- Quạt dàn ngưng; 2- Van chống đông (Mặc định: 1)', 'description': 'Ngõ ra Rơ-le K2'},
      {'code': 'F41', 'value': '0-Tắt quạt; 1-Quạt chạy theo nhiệt độ dàn ngưng; 2- Quạt chạy cùng lúc lốc nén; 3- Quạt chạy theo nhiệt độ điểm sương (Mặc định: 1/3)', 'description': 'Cài đặt chế độ chạy quạt dàn ngưng'},
      {'code': 'F42', 'value': '32 - 55 ⁰C (Mặc định: 42/50⁰C)', 'description': 'Nhiệt độ chạy quạt dàn ngưng'},
      {'code': 'F43', 'value': '0.1 (0.5) – 10 ⁰C (Mặc định: 2/1⁰C)', 'description': 'Nhiệt độ dàn ngưng < [F42] – [F43]: Quạt dừng'},
    ]
  },
  {
    'category': 'Cài đặt lỗi và cảnh báo',
    'items': [
      {'code': 'F50', 'value': '0-Thường mở; 1- Thường đóng; 2- Khi có lỗi và cài ở thường mở thì công tắc sẽ đóng (Mặc định: 0)', 'description': 'Loại công tắc báo lỗi'},
      {'code': 'F51', 'value': '0 – 1 (Mặc định: 0)', 'description': 'Điều kiện hoạt động khi xảy ra cảnh báo điểm sương cao'},
      {'code': 'F52', 'value': '0 – 1 (Mặc định: 1)', 'description': 'Điều kiện hoạt động khi xảy ra cảnh báo nhiệt dàn ngưng cao'},
      {'code': 'F53', 'value': '0 – 1 (Mặc định: 0)', 'description': 'Cách thiết lập lại khi cảnh báo điểm sương cao'},
      {'code': 'F54', 'value': '0 – 1 (Mặc định: 0)', 'description': 'Cách thiết lập lại khi cảnh báo nhiệt dàn ngưng cao'},
      {'code': 'F55', 'value': '0 – 1 (Mặc định: 0)', 'description': 'Cách thiết lập lại tín hiệu báo lỗi'},
      {'code': 'F56', 'value': '0 ~ 300 giây (Mặc định: 1 giây)', 'description': 'Thời gian trễ phát cảnh báo'},
      {'code': 'F57', 'value': '0-Chỉ cảnh báo, không tắt; 1- Cảnh báo và tắt; 2- Cảnh báo dừng lốc nén (Mặc định: 1)', 'description': 'Điều kiện hoạt động khi cảnh báo lỗi xảy ra'},
    ]
  },
  {
    'category': 'Chạy – Dừng và Cài đặt ngõ vào',
    'items': [
      {'code': 'F58', 'value': '0-Thường mở; 1- Thường đóng (Tuỳ chọn điều khiển ở F60) (Mặc định: 1)', 'description': 'Loại công tắc điều khiển từ xa'},
      {'code': 'F60', 'value': '0-Điều khiển độc lập; 1- Điều khiển từ xa (Mặc định: 0)', 'description': 'Phương thức điều khiển'},
      {'code': 'F63', 'value': '0-Không đặt lại; 1- Đặt thời gian chạy của máy về "0" (Mặc định: 0)', 'description': 'Đặt lại thời gian chạy của máy'},
    ]
  },
  {
    'category': 'Cài đặt hệ thống',
    'items': [
      {'code': 'F88', 'value': '0-Không bật; 1- Bật bù nhiệt độ điểm sương (Mặc định: 1)', 'description': 'Chế độ bù nhiệt độ điểm sương'},
      {'code': 'F89', 'value': '0-K1: Ngõ ra của máy nén, K2: Ngõ ra của quạt; 1- Ngược lại (Mặc định: 0)', 'description': 'Công tắc chuyển đổi Quạt – Lốc nén'},
      {'code': 'F90', 'value': '0 – 999 (Mặc định: 55); 0- Không đặt mật khẩu; 1~999: Đặt mật khẩu', 'description': 'Cài đặt mật khẩu truy cập'},
      {'code': 'F91', 'value': '0 – 999 (Mặc định: 1)', 'description': 'Địa chỉ giao tiếp từ xa'},
    ]
  }
];
