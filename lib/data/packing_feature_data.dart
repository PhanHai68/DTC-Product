import 'package:flutter/material.dart';

import '../models/packing_machine.dart';

/// Một đặc điểm nổi bật được chuẩn hóa từ ba catalog đóng gói tiếng Việt.
class PackingFeature {
  final String title;
  final String summary;
  final String detail;
  final IconData icon;

  const PackingFeature({
    required this.title,
    required this.summary,
    required this.detail,
    required this.icon,
  });
}

const _riceMixerFeatures = <PackingFeature>[
  PackingFeature(
    title: 'Tự động phát hiện lỗi',
    summary: 'Tự điều chỉnh đúng lưu lượng trong khi vận hành.',
    detail:
        'Chức năng tự động phát hiện sai lệch và điều chỉnh đúng lưu lượng '
        'trong lúc vận hành, giúp quá trình phối trộn duy trì ổn định.',
    icon: Icons.build_circle_outlined,
  ),
  PackingFeature(
    title: 'Vệ sinh thuận tiện',
    summary: 'Làm sạch nguyên liệu còn sót chỉ bằng một nút nhấn.',
    detail:
        'Dễ dàng vệ sinh máy; nguyên liệu còn sót trong silo có thể được làm '
        'sạch bằng một nút nhấn.',
    icon: Icons.cleaning_services_outlined,
  ),
  PackingFeature(
    title: 'Truyền dữ liệu',
    summary: 'Kết nối với hệ thống điều khiển trung tâm.',
    detail:
        'Giao diện truyền dữ liệu có thể kết nối với hệ thống điều khiển '
        'trung tâm, thuận tiện cho theo dõi và quản lý dây chuyền.',
    icon: Icons.cable_outlined,
  ),
  PackingFeature(
    title: 'Hàn miệng túi tốt',
    summary: 'Cổng hút gió ngoài hỗ trợ hạn chế bụi.',
    detail:
        'Thiết kế túi rút kết hợp cổng hút gió bên ngoài giúp hạn chế bụi và '
        'giữ nguyên liệu bên trong thiết bị sạch hơn.',
    icon: Icons.lock_outline_rounded,
  ),
  PackingFeature(
    title: 'Điều khiển tự động',
    summary: 'Tự điều chỉnh cửa xả theo dòng chảy.',
    detail:
        'Cửa xả liệu được điều chỉnh tự động theo dòng chảy, giúp duy trì '
        'lưu lượng chính xác và phù hợp với quá trình vận hành.',
    icon: Icons.tune_rounded,
  ),
  PackingFeature(
    title: 'Phân bố chính xác',
    summary: 'Kiểm soát xả liệu đồng nhất trong quá trình trộn.',
    detail:
        'Hệ thống kiểm soát việc xả liệu để nguyên liệu được phân bố đồng '
        'nhất trong quá trình trộn và xả.',
    icon: Icons.shuffle_rounded,
  ),
];

const _flowScaleFeatures = <PackingFeature>[
  PackingFeature(
    title: 'Dễ dàng vận hành',
    summary: 'Điều chỉnh thuận tiện trên màn hình điều khiển.',
    detail:
        'Các điều chỉnh được thực hiện thuận tiện qua màn hình điều khiển. '
        'Các thiết bị được bố trí để dễ kiểm tra và sửa chữa.',
    icon: Icons.display_settings_outlined,
  ),
  PackingFeature(
    title: 'Thiết kế linh hoạt',
    summary: 'Phù hợp nhiều môi trường, kể cả phòng lạnh.',
    detail:
        'Thiết bị tùy chọn có thể bố trí linh hoạt, phù hợp với nhiều môi '
        'trường làm việc, bao gồm cả phòng lạnh.',
    icon: Icons.electrical_services_outlined,
  ),
  PackingFeature(
    title: 'Thiết bị uy tín',
    summary: 'Linh kiện Nhật Bản và Châu Âu, vận hành ổn định.',
    detail:
        'Các thiết bị có xuất xứ từ Nhật Bản và Châu Âu, hướng đến khả năng '
        'hoạt động ổn định và tuổi thọ cao.',
    icon: Icons.verified_outlined,
  ),
  PackingFeature(
    title: 'In dữ liệu',
    summary: 'Máy in tùy chọn cho năng suất và thông tin đầu ra.',
    detail:
        'Có thể trang bị máy in tùy chọn để in năng suất đầu ra cùng các '
        'thông tin vận hành liên quan.',
    icon: Icons.print_outlined,
  ),
];

const _peTwoEdgeAutomaticFeatures = <PackingFeature>[
  PackingFeature(
    title: 'Hai dây đóng túi song song',
    summary: 'Hai dây đóng túi có thể hoạt động đồng thời.',
    detail:
        'Hai dây đóng túi được bố trí hoạt động song song để hỗ trợ năng suất '
        'cao của dòng máy hoàn toàn tự động.',
    icon: Icons.call_split_rounded,
  ),
  PackingFeature(
    title: 'Chuyển đổi khối lượng linh hoạt',
    summary: 'Thuận tiện thay đổi quy cách đóng gói.',
    detail:
        'Cấu hình máy hỗ trợ chuyển đổi khối lượng túi linh hoạt theo yêu cầu '
        'sản xuất và nguyên liệu đầu vào.',
    icon: Icons.scale_outlined,
  ),
  PackingFeature(
    title: 'Thiết kế theo cụm',
    summary: 'Các bộ phận được tổ chức thành từng cụm chức năng.',
    detail:
        'Thiết kế thành từng cụm giúp dây chuyền dễ bố trí, kiểm tra và bảo '
        'trì trong quá trình sử dụng.',
    icon: Icons.view_module_outlined,
  ),
  PackingFeature(
    title: 'Định hình thứ cấp',
    summary: 'Có thể trang bị máy định hình thứ cấp tùy chọn.',
    detail:
        'Máy định hình thứ cấp là thiết bị tùy chọn, hỗ trợ hoàn thiện hình '
        'dạng túi theo yêu cầu đóng gói.',
    icon: Icons.inventory_2_outlined,
  ),
];

const _peTwoEdgeSemiFeatures = <PackingFeature>[
  PackingFeature(
    title: 'Điều chỉnh linh hoạt',
    summary: 'Cài đặt thông số và cấp liệu tự động.',
    detail:
        'Các thông số vận hành được cài đặt linh hoạt; hệ thống hỗ trợ điều '
        'chỉnh quá trình cấp liệu tự động.',
    icon: Icons.tune_rounded,
  ),
  PackingFeature(
    title: 'Định hình hoàn hảo',
    summary: 'Điều chỉnh thông số để định hình túi chính xác.',
    detail:
        'Có thể điều chỉnh các thông số định hình để túi đạt hình dạng chính '
        'xác hơn theo quy cách đóng gói.',
    icon: Icons.crop_portrait_rounded,
  ),
  PackingFeature(
    title: 'Vận hành độc lập',
    summary: 'Hai trạm có thể làm việc độc lập hoặc cùng lúc.',
    detail:
        'Hai trạm đóng gói có thể làm việc độc lập và vận hành hai thông số '
        'kỹ thuật khác nhau cùng lúc.',
    icon: Icons.hub_outlined,
  ),
  PackingFeature(
    title: 'Màn hình cảm ứng',
    summary: 'Thao tác dễ dàng, hiển thị đầy đủ thông tin.',
    detail:
        'Màn hình cảm ứng giúp thao tác cài đặt thuận tiện và hiển thị đầy đủ '
        'thông tin cần thiết trong quá trình vận hành.',
    icon: Icons.touch_app_outlined,
  ),
  PackingFeature(
    title: 'Kiểm soát nhiệt độ',
    summary: 'Hệ thống kiểm soát nhiệt độ thông minh.',
    detail:
        'Hệ thống kiểm soát nhiệt độ phù hợp với nhiều loại túi có độ dày '
        'khác nhau, hỗ trợ chất lượng đường hàn ổn định.',
    icon: Icons.device_thermostat_outlined,
  ),
  PackingFeature(
    title: 'Truyền dữ liệu',
    summary: 'Cổng RS232/485 kết nối hệ thống quản lý.',
    detail:
        'Cổng nối tiếp RS232/485 riêng cho truyền dữ liệu, có thể đăng ký kết '
        'nối với hệ thống quản lý.',
    icon: Icons.cable_outlined,
  ),
];

const _peSixEdgeFeatures = <PackingFeature>[
  PackingFeature(
    title: 'Điều chỉnh linh hoạt',
    summary: 'Cài đặt thông số và điều chỉnh cấp liệu tự động.',
    detail:
        'Người vận hành có thể cài đặt các thông số phù hợp; quá trình cấp '
        'liệu được điều chỉnh tự động.',
    icon: Icons.tune_rounded,
  ),
  PackingFeature(
    title: 'Tự động phát hiện lỗi',
    summary: 'Phát hiện và hỗ trợ khắc phục sự cố.',
    detail:
        'Hệ thống có chức năng tự phát hiện và hỗ trợ khắc phục sự cố, giúp '
        'việc bảo trì đơn giản và thuận tiện hơn.',
    icon: Icons.build_circle_outlined,
  ),
  PackingFeature(
    title: 'Thiết bị cao cấp',
    summary: 'Linh kiện Nhật Bản và Châu Âu, tuổi thọ cao.',
    detail:
        'Thiết bị và linh kiện có xuất xứ từ Nhật Bản và Châu Âu, hướng đến '
        'khả năng hoạt động ổn định và tuổi thọ cao.',
    icon: Icons.verified_outlined,
  ),
  PackingFeature(
    title: 'Điều khiển thông minh',
    summary: 'Màn hình cảm ứng dễ thao tác.',
    detail:
        'Màn hình cảm ứng giúp thao tác điều khiển thuận tiện và hiển thị đầy '
        'đủ thông tin vận hành.',
    icon: Icons.touch_app_outlined,
  ),
  PackingFeature(
    title: 'Chuyển đổi đơn giản',
    summary: 'Thay đổi khuôn nhanh, không cần dụng cụ phức tạp.',
    detail:
        'Khuôn có thể được thay đổi nhanh chóng để phù hợp nhiều quy cách '
        'đóng gói mà không cần dụng cụ phức tạp.',
    icon: Icons.change_circle_outlined,
  ),
  PackingFeature(
    title: 'Truyền dữ liệu',
    summary: 'Cổng RS232/485 kết nối hệ thống quản lý.',
    detail:
        'Cổng nối tiếp RS232/485 phục vụ truyền dữ liệu và có thể kết nối với '
        'hệ thống quản lý.',
    icon: Icons.cable_outlined,
  ),
];

const _ppAutomaticFeatures = <PackingFeature>[
  PackingFeature(
    title: 'Cân tốc độ cao',
    summary: 'Cấu trúc ba cảm biến tải trọng, chính xác và ổn định.',
    detail:
        'Cân đơn có tốc độ cao; cấu trúc ba cảm biến tải trọng giúp quá trình '
        'cân đạt độ chính xác và ổn định.',
    icon: Icons.speed_outlined,
  ),
  PackingFeature(
    title: 'Điều khiển từ xa',
    summary: 'Cài đặt và giám sát thiết bị qua Wi-Fi.',
    detail:
        'Thiết bị hỗ trợ điều khiển từ xa để người dùng thuận tiện cài đặt và '
        'giám sát trạng thái vận hành.',
    icon: Icons.settings_remote_outlined,
  ),
  PackingFeature(
    title: 'Tự động gấp túi',
    summary: 'Chuyển đổi chế độ thuận tiện, cải thiện hình dạng túi.',
    detail:
        'Chức năng gấp túi tự động giúp chuyển đổi giữa các chế độ và cải '
        'thiện hình dạng túi sau khi đóng gói.',
    icon: Icons.horizontal_rule_rounded,
  ),
  PackingFeature(
    title: 'Tra dầu tự động',
    summary: 'Hệ thống nạp dầu tự động, giảm bảo trì thủ công.',
    detail:
        'Hệ thống nạp dầu tự động hỗ trợ duy trì cơ cấu chuyển động và giảm '
        'khối lượng bảo trì thủ công.',
    icon: Icons.oil_barrel_outlined,
  ),
  PackingFeature(
    title: 'Tự động cấp túi',
    summary: 'Cơ chế kẹp và di chuyển túi chính xác.',
    detail:
        'Cơ chế cấp túi tự động kẹp chính xác tâm túi và chuyển túi đến bộ '
        'phận cấp liệu.',
    icon: Icons.input_rounded,
  ),
  PackingFeature(
    title: 'Từ chối túi lỗi',
    summary: 'Tự loại bỏ túi không đạt mà không dừng máy.',
    detail:
        'Túi không đạt được tự động loại bỏ; túi thay thế được đưa vào lưu '
        'trình mà không cần dừng máy.',
    icon: Icons.cancel_presentation_outlined,
  ),
  PackingFeature(
    title: 'Dễ dàng chuyển đổi',
    summary: 'Lưu trữ nhiều thông số kỹ thuật theo quy cách.',
    detail:
        'Máy có thể lưu trữ tới 60 loại thông số kỹ thuật, giúp chuyển đổi '
        'quy cách chỉ bằng thao tác trên màn hình.',
    icon: Icons.swap_horiz_rounded,
  ),
  PackingFeature(
    title: 'Thống kê',
    summary: 'Theo dõi số túi theo ca hoặc theo ngày.',
    detail:
        'Hiển thị số lượng túi đã đóng theo thực tế và hỗ trợ thống kê theo '
        'ca hoặc ngày làm việc.',
    icon: Icons.stacked_bar_chart_outlined,
  ),
];

const _ppCompactSemiFeatures = <PackingFeature>[
  PackingFeature(
    title: 'Chuyển đổi chế độ',
    summary: 'Chuyển giữa nâng hạ băng tải và băng tải quay tay.',
    detail:
        'Cơ cấu cho phép chuyển đổi thuận tiện giữa nâng hạ băng tải và '
        'băng tải quay tay theo nhu cầu sử dụng.',
    icon: Icons.change_circle_outlined,
  ),
  PackingFeature(
    title: 'Tự động cắt chỉ',
    summary: 'Cắt chỉ tự động trong máy khâu chuyên dụng.',
    detail:
        'Máy khâu chuyên dụng được tích hợp chức năng cắt chỉ tự động, giảm '
        'thao tác thủ công sau khi may bao.',
    icon: Icons.content_cut_rounded,
  ),
  PackingFeature(
    title: 'Phụ tùng cao cấp',
    summary: 'Phụ tùng thay thế uy tín, vận hành ổn định.',
    detail:
        'Sử dụng phụ tùng thay thế từ các nhà cung cấp uy tín để hỗ trợ thiết '
        'bị hoạt động ổn định.',
    icon: Icons.verified_outlined,
  ),
  PackingFeature(
    title: 'Màn hình cảm ứng (tùy chọn)',
    summary: 'Điều khiển thông minh, trực quan và gọn.',
    detail:
        'Có thể trang bị màn hình cảm ứng tùy chọn để điều khiển trực quan, '
        'thông minh và gọn hơn.',
    icon: Icons.touch_app_outlined,
  ),
];

const _ppSemiFeatures = <PackingFeature>[
  PackingFeature(
    title: 'Cảm biến lực chính xác',
    summary: 'Hiệu suất cao, ổn định và dễ vận hành.',
    detail:
        'Cảm biến lực giúp quá trình định lượng đạt hiệu suất cao, ổn định '
        'và thuận tiện khi vận hành.',
    icon: Icons.sensors_outlined,
  ),
  PackingFeature(
    title: 'Tự động phát hiện lỗi',
    summary: 'Báo động ngoài dung sai và tự chẩn đoán.',
    detail:
        'Hệ thống hỗ trợ tự động sửa lỗi, báo động khi ngoài dung sai và tự '
        'chẩn đoán lỗi trong quá trình hoạt động.',
    icon: Icons.notification_important_outlined,
  ),
  PackingFeature(
    title: 'Thép chống gỉ sét',
    summary: 'Bộ phận tiếp xúc nguyên liệu bằng thép không gỉ.',
    detail:
        'Các bộ phận tiếp xúc trực tiếp với nguyên liệu được thiết kế bằng '
        'thép không gỉ để tăng độ bền và tuổi thọ.',
    icon: Icons.shield_outlined,
  ),
  PackingFeature(
    title: 'Truyền dữ liệu',
    summary: 'RS232/485 kết nối thuận tiện với hệ thống quản lý.',
    detail:
        'Cổng RS232/485 phục vụ truyền dữ liệu và có thể đăng ký kết nối với '
        'hệ thống quản lý.',
    icon: Icons.cable_outlined,
  ),
];

const _jumboFeatures = <PackingFeature>[
  PackingFeature(
    title: 'Cân chính xác',
    summary: 'Cơ chế định lượng chính xác, hiệu suất ổn định.',
    detail:
        'Cơ chế định lượng được thiết kế để đạt độ chính xác và duy trì hiệu '
        'suất ổn định khi đóng bao Jumbo.',
    icon: Icons.track_changes_outlined,
  ),
  PackingFeature(
    title: 'Dễ dàng hoạt động',
    summary: 'Tự động đóng và kẹp miệng túi khi hoàn tất.',
    detail:
        'Cơ chế nhả túi tự động đóng và kẹp miệng túi khi hoàn tất quá trình '
        'đóng bao.',
    icon: Icons.settings_suggest_outlined,
  ),
  PackingFeature(
    title: 'Thép chống gỉ sét',
    summary: 'Bộ phận tiếp xúc nguyên liệu bằng thép không gỉ.',
    detail:
        'Các bộ phận tiếp xúc trực tiếp với nguyên liệu được thiết kế bằng '
        'thép không gỉ để tăng độ bền.',
    icon: Icons.shield_outlined,
  ),
  PackingFeature(
    title: 'Truyền dữ liệu',
    summary: 'RS232/485 kết nối với hệ thống quản lý.',
    detail:
        'Cổng RS232/485 hỗ trợ truyền dữ liệu và kết nối với hệ thống quản lý '
        'của nhà máy.',
    icon: Icons.cable_outlined,
  ),
];

const _powderFeatures = <PackingFeature>[
  PackingFeature(
    title: 'Đóng gói bột đa dạng',
    summary: 'Phù hợp bột gạo, bột mì, cám và vật liệu dạng bột.',
    detail:
        'Dòng máy được thiết kế để đóng gói các loại nguyên liệu dạng bột như '
        'bột gạo, bột mì và cám.',
    icon: Icons.grain_outlined,
  ),
  PackingFeature(
    title: 'Định lượng chính xác',
    summary: 'Độ chính xác theo catalog đạt tới ±50 g.',
    detail:
        'Cơ cấu định lượng cho nguyên liệu bột được thiết kế với độ chính xác '
        'theo catalog đạt tới ±50 g.',
    icon: Icons.scale_outlined,
  ),
  PackingFeature(
    title: 'Nhiều dải trọng lượng',
    summary: 'Bao phủ các mức 2,5–10 kg, 10–25 kg và 25–50 kg.',
    detail:
        'Các model trong dòng đáp ứng nhiều dải trọng lượng đóng gói, từ '
        '2,5 kg đến 50 kg tùy cấu hình.',
    icon: Icons.straighten_outlined,
  ),
  PackingFeature(
    title: 'Tích hợp may bao',
    summary: 'Băng tải và cụm may bao bố trí theo dây chuyền.',
    detail:
        'Thiết bị được bố trí cùng băng tải và cụm may bao để hoàn thiện quy '
        'trình đóng gói dạng bột.',
    icon: Icons.linear_scale_rounded,
  ),
];

/// Chọn bộ đặc điểm theo đúng dòng máy/model trong catalog.
List<PackingFeature> packingFeaturesFor(PackingMachine machine) {
  final line = machine.machineLine ?? '';
  final group = machine.productGroup ?? '';

  if (line == 'Máy trộn gạo') return _riceMixerFeatures;
  if (line == 'Cân lưu lượng' && group == 'Định lượng') {
    return _flowScaleFeatures;
  }

  if (group.contains('PE')) {
    if (line == 'Túi 2 cạnh - Hoàn toàn tự động') {
      return _peTwoEdgeAutomaticFeatures;
    }
    if (line == 'Túi 2 cạnh - Bán tự động') {
      return _peTwoEdgeSemiFeatures;
    }
    return _peSixEdgeFeatures;
  }

  if (line == 'Hoàn toàn tự động') return _ppAutomaticFeatures;
  if (line.contains('Cân bao Jumbo')) return _jumboFeatures;
  if (line.contains('Đóng bột')) return _powderFeatures;

  const compactModels = {'DCS-5S-3A', 'DCS-25K-3A', 'DCS-25K-3C'};
  if (compactModels.contains(machine.model)) return _ppCompactSemiFeatures;
  return _ppSemiFeatures;
}
