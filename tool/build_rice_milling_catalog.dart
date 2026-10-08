// Sinh assets/database/rice_milling_catalog.json từ catalog
// "DTC-C-DayChuyenXayXat-VN-250117.pdf" (docs_database/07_Day chuyen_Xay_xat).
//
// Chạy: dart run tool/build_rice_milling_catalog.dart
//
// Mọi số liệu dưới đây chép nguyên từ bảng "Thông số kỹ thuật" của catalog
// (số trang ghi ở từng dòng máy). Không tự thêm thông số catalog không có:
// ô trống trong catalog thì bỏ hẳn dòng đó. Tổng công suất điện chỉ là
// phép cộng các động cơ catalog liệt kê.
import 'dart:convert';
import 'dart:io';

const _output = 'assets/database/rice_milling_catalog.json';

void main() {
  final machines = <Map<String, Object?>>[
    ..._dryers(),
    ..._cleaners(),
    ..._destoners(),
    ..._huskers(),
    ..._separators(),
    ..._whiteners(),
    ..._polishers(),
    ..._graders(),
    ..._lengthGraders(),
    ..._filters(),
    ..._conveyors(),
  ];
  final ids = <String>{};
  for (final m in machines) {
    if (!ids.add(m['machineId']! as String)) {
      throw StateError('Trùng machineId ${m['machineId']}');
    }
  }
  final root = {
    'catalogVersion': '1.0.0',
    'sourceDocument':
        'DTC-C-DayChuyenXayXat-VN-250117.pdf — Dây chuyền xay xát lúa - gạo',
    'criteria': _criteria,
    'series': _series,
    'machines': machines,
  };
  File(
    _output,
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(root)}\n');
  stdout.writeln(
    'Đã ghi $_output: ${_series.length} dòng máy, ${machines.length} model.',
  );
}

// ---------------------------------------------------------------------------
// Tiêu chí chọn máy
// ---------------------------------------------------------------------------

const _stages = [
  ('drying', 'Sấy lúa'),
  ('cleaning', 'Làm sạch tạp chất'),
  ('destoning', 'Tách đá, sạn'),
  ('husking', 'Bóc vỏ lúa'),
  ('separating', 'Tách thóc (gạo lứt)'),
  ('whitening', 'Xát trắng'),
  ('polishing', 'Lau bóng'),
  ('grading', 'Sàng đảo / phân cỡ'),
  ('broken_grading', 'Phân loại gạo tấm'),
  ('dust_filter', 'Lọc bụi'),
  ('conveying', 'Tải hàng (gàu, băng, xích)'),
];

final _criteria = [
  {
    'key': 'stage',
    'type': 'choice',
    'label': 'Công đoạn',
    'inputLabel': 'Công đoạn / loại thiết bị',
    'options': [
      for (final (value, label) in _stages) {'value': value, 'label': label},
    ],
  },
  {
    'key': 'capacity',
    'type': 'atLeast',
    'label': 'Năng suất',
    'inputLabel': 'Năng suất cần đạt (tấn/giờ)',
    'units': [
      {'label': 'tấn/giờ', 'factor': 1},
    ],
    'matchNote':
        'theo catalog; máy bóc vỏ, gằng tách thóc tính theo gạo hạt dài, '
        'băng tải tính theo lúa',
  },
  {
    'key': 'power',
    'type': 'atMost',
    'label': 'Tổng công suất điện',
    'inputLabel': 'Tổng công suất điện tối đa (kW)',
    'units': [
      {'label': 'kW', 'factor': 1},
    ],
  },
];

// ---------------------------------------------------------------------------
// Dòng máy
// ---------------------------------------------------------------------------

String _bullets(List<String> lines) => lines.map((l) => '- $l').join('\n');

const _smartControl =
    'Kết hợp thông minh: màn hình điều khiển cảm ứng; điều chỉnh lưu lượng '
    'tự động; tự động chống nghẽn nguyên liệu.';

Map<String, Object?> _s(
  String code,
  String display,
  String name,
  String group,
  String pages,
  String image,
  List<String> features, {
  String application = '',
}) => {
  'seriesCode': code,
  'displayCode': display,
  'nameVi': name,
  'groupVi': group,
  'pdfPages': pages,
  'image': 'assets/images/$image.jpg',
  'imageCaption': 'Ảnh minh họa dòng $display',
  'applicationVi': application,
  'featuresVi': _bullets(features),
};

const _gDrying = 'Sấy lúa';
const _gCleaning = 'Làm sạch & tách đá, sạn';
const _gHusking = 'Bóc vỏ & tách thóc';
const _gWhitening = 'Xát trắng & lau bóng';
const _gGrading = 'Sàng phân cỡ & phân loại tấm';
const _gFilter = 'Lọc bụi';
const _gConveying = 'Thiết bị tải hàng';

final _series = [
  _s(
    'DRYER_5H',
    '5H',
    'Máy sấy tháp tuần hoàn',
    _gDrying,
    '9-10',
    'rice_dryer_5h',
    [
      'Nguồn nhiệt linh hoạt và hiệu suất cao: kết nối đa dạng với các loại lò '
          'đốt. Giảm thiểu tối đa ảnh hưởng đến môi trường, áp dụng công nghệ '
          'sấy khô hoàn toàn nhiệt độ thấp và công nghệ chuyển đổi nhiệt độ tối '
          'đa.',
      'Phơi sấy đều, sấy tuần hoàn: sấy với lưu lượng gió tối đa và nhiệt độ '
          'thấp (nhiệt độ không khí khoảng 40 - 60°C). Lúa được làm nóng trong '
          'thời gian rất ngắn rồi ủ trong thời gian dài để giảm tỷ lệ gãy vỡ, '
          'giữ chất lượng và tăng hiệu quả khử ẩm, giảm chi phí sản xuất.',
      'Dễ dàng vận hành: khả năng tự động hóa cao. Màn hình điều khiển HMI '
          'trực quan, nhiều chế độ tự động / bán tự động, khóa an toàn đa điểm.',
    ],
  ),
  _s(
    'CLEANER_TQLG',
    'TQLG',
    'Sàng tạp chất dạng kết hợp xoay và rung',
    _gCleaning,
    '11',
    'rice_cleaner_tqlg',
    [
      'Tích hợp nhiều chức năng trong một thiết bị, có thể loại bỏ đồng thời '
          'các tạp chất với kích cỡ khác nhau.',
      'Sử dụng vít tải để cấp liệu, nguyên liệu được trải đồng đều trên bề mặt '
          'sàn, công suất điều chỉnh vô cấp, hiển thị thông số điện tử, đơn '
          'giản và trực quan.',
      'Thiết kế máng kín, giảm thiểu bụi phát tán ra môi trường.',
      'Sử dụng khớp nối các-đăng linh hoạt, đảm bảo máy hoạt động trơn tru.',
      'Khớp nối độ bền cao, máy hoạt động ổn định.',
      'Kết cấu làm sạch lưới dạng bàn chải, có thể tự động làm sạch tạp chất.',
      'Năng suất của máy lớn.',
    ],
  ),
  _s(
    'CLEANER_TQLM',
    'TQLM',
    'Sàng tạp chất dạng rung ngang',
    _gCleaning,
    '12',
    'rice_cleaner_tqlm',
    [
      'Ba hướng chuyển động trên cùng một mặt sàn, hướng xoay từ trái qua '
          'phải.',
      'Vị trí bề mặt giữa sàn chuyển động xoay tròn - phẳng, ổn định khi có '
          'nguyên liệu tràn và khả năng tự động hóa.',
      'Thân máy kín, được trang bị hút bụi, giảm bụi bẩn.',
      'Vận hành dễ dàng và độ bền cao.',
    ],
  ),
  _s(
    'DESTONER_TQSX',
    'TQSX',
    'Sàng tách đá, sạn TQSX',
    _gCleaning,
    '12',
    'rice_destoner_tqsx',
    [
      'Buồng phân loại đặc biệt để loại đá ra khỏi nguyên liệu, hiệu quả tốt '
          'nhất cho gạo lứt.',
      'Cấu trúc sàng được thiết kế để tiết kiệm khí thổi.',
      'Hút bụi bên trong để giảm bụi bẩn thoát ra ngoài môi trường.',
    ],
    application:
        'Loại đá, sạn ra khỏi nguyên liệu; hiệu quả tốt nhất cho '
        'gạo lứt.',
  ),
  _s(
    'DESTONER_TQSZ',
    'TQSZ',
    'Sàng tách đá, sạn TQSZ',
    _gCleaning,
    '13',
    'rice_destoner_tqsz',
    [
      'Sử dụng mô tơ rung kép làm nguồn rung cho máy, độ rung có thể điều '
          'chỉnh.',
      'Thiết kế cơ cấu phù hợp, không thoát bụi ra bên ngoài.',
      'Độ cứng, độ bền cao, dễ dàng tháo lắp để bảo trì và vệ sinh.',
      'Thiết kế bên ngoài theo một tiêu chuẩn công nghiệp mới.',
      'Thiết kế đặc trưng làm giảm lưu lượng khí tiêu thụ, tăng hiệu quả tách '
          'đá và độ tin cậy.',
      'Góc nghiêng lưới phân loại có thể điều chỉnh, có khả năng tách được các '
          'loại đá trong các loại nguyên liệu khác nhau.',
      'Hệ thống điều khiển thông minh: màn hình điều khiển LCD cảm ứng; tự '
          'động bật nguồn khi có nguyên liệu, tự động tắt khi tạm dừng nạp '
          'nguyên liệu; đồng hồ áp suất kỹ thuật số; van điều chỉnh điện hiển '
          'thị số; hiển thị biên độ bằng màn hình kỹ thuật số.',
    ],
  ),
  _s(
    'HUSKER_MLGQ',
    'MLGQ',
    'Máy bóc vỏ lúa',
    _gHusking,
    '14',
    'rice_husker_mlgq',
    [
      'Tự động điều chỉnh tần số hoạt động để ép ru lô lại gần khi cấp liệu '
          'hoặc dãn ra khi ngừng cấp liệu.',
      'Kiểm soát áp suất ép chặt giữa ru lô.',
      'Hiển thị kỹ thuật số mức cấp liệu, dễ dàng điều chỉnh.',
      'Sử dụng bộ rung cấp liệu, máng dẫn, có thể đạt năng suất cao, giảm tỉ '
          'lệ gãy, tăng hiệu suất.',
      'Sử dụng dây curoa truyền động, không bánh răng, giảm tiếng ồn, không rò '
          'rỉ dầu.',
      'Khung máy chắc chắn, vận hành dễ dàng, hiệu suất ổn định.',
      'Ru lô cao su đóng mở ổn định, tuổi thọ cao.',
    ],
  ),
  _s(
    'HUSKER_SMART',
    'MLGQ-D',
    'Máy bóc vỏ lúa thông minh',
    _gHusking,
    '15',
    'rice_husker_smart',
    [
      'Sử dụng bộ chuyển đổi tần số giúp máy nhận ra sự thay đổi trong truyền '
          'động, tự động điều chỉnh giữa ru lô nhanh và ru lô chậm.',
      'Tự động điều chỉnh tốc độ quay của ru lô và duy trì ổn định, tỉ lệ bóc '
          'vỏ cao, độ nhám và gãy thấp.',
      'Áp dụng cấu trúc 3 điểm, tăng cường độ vững của ru lô, trục chính giúp '
          'máy vận hành trơn tru, ổn định.',
      'Áp dụng truyền động dây đai, hiệu suất truyền động cao, giảm tiếng ồn.',
      'Nhiệt độ ru lô được theo dõi bằng tia hồng ngoại, bảo vệ ru lô liên tục '
          'và theo thời gian thực.',
    ],
  ),
  _s(
    'HUSKER_ASPIRATOR',
    'MLGQ-D + MKXF',
    'Máy bóc vỏ lúa thông minh tích hợp hệ thống hút vỏ trấu',
    _gHusking,
    '15',
    'rice_husker_aspirator',
    [
      'Sử dụng bộ chuyển đổi tần số và tiết kiệm năng lượng, hệ thống hộp số '
          'biến thiên vô cấp, tự động chuyển đổi giữa nhanh và chậm của ru lô '
          'và không cần giám sát.',
      'Tự động điều chỉnh tốc độ quay của ru lô, duy trì không đổi, tỉ lệ bóc '
          'vỏ cao, giảm tỉ lệ gãy.',
      'Kết cấu cơ khí ổn định, hoạt động trơn tru, êm ái.',
      'Thiết kế tích hợp thêm thiết bị hút để loại bỏ vỏ trấu, khả năng tách '
          'trấu tốt.',
    ],
  ),
  _s(
    'SEPARATOR_DOUBLE',
    'MGCZ',
    'Gằng tách thóc đôi',
    _gHusking,
    '16',
    'rice_separator_double',
    [
      'Bề mặt sàng có nhiều sóng nối bằng thép không gỉ, hạn chế trấu bám lại '
          'bề mặt sàng, gia tăng hiệu quả tách thóc.',
      'Tự động khởi động khi cấp liệu và dừng khi ngắt liệu, màn hình điều '
          'khiển cảm ứng.',
      'Hệ thống điều khiển có khả năng nâng cấp.',
      'Trang bị thiết bị điều chỉnh tốc độ, khả năng đáp ứng cao, khởi động '
          'mềm và kết cấu ổn định.',
      'Cấu trúc khớp quay kiểu chữ B, khả năng tiết kiệm năng lượng tối ưu.',
    ],
  ),
  _s(
    'SEPARATOR_SINGLE',
    'MGCZ 100',
    'Gằng tách thóc đơn',
    _gHusking,
    '16',
    'rice_separator_single',
    [
      'Góc nghiêng của mặt sàng lớn hơn để giảm tắc nghẽn.',
      'Thiết kế bánh đà làm tăng hiệu quả cơ khí.',
      'Công nghệ điều chỉnh tốc độ, kết cấu cấp liệu đảm bảo độ đồng đều trên '
          'các mặt sàn.',
    ],
  ),
  _s(
    'WHITENER_MNSL',
    'MNSL',
    'Máy xát trắng trục đứng MNSL',
    _gWhitening,
    '17',
    'rice_whitener_mnsl',
    [
      'Cấp liệu bằng vít tải, độ trắng đồng đều và tỉ lệ gãy hạt thấp.',
      'Hệ thống cấp liệu phụ trợ, đảm bảo nguyên liệu duy trì ổn định, không '
          'phụ thuộc vào sự biến đổi của lưu lượng gió.',
      'Buồng xát trắng nằm thẳng đứng, đảm bảo ma sát đều, giảm nhiệt độ gạo '
          'và tăng hiệu suất xát trắng.',
      'Tùy theo tình hình thực tế của nhà máy khách hàng, cửa nạp và xả liệu '
          'có thể linh hoạt thay đổi.',
      _smartControl,
    ],
  ),
  _s(
    'WHITENER_MNTL',
    'MNTL',
    'Máy xát trắng trục đứng MNTL',
    _gWhitening,
    '18',
    'rice_whitener_mntl',
    [
      'Máy xát trắng tích hợp có thể giảm thiểu gàu tải, tránh tình trạng lên '
          'xuống của nguyên liệu; thay vào đó vít tải có độ tin cậy cao và năng '
          'suất tương đối lớn.',
      'Cấp liệu phụ trợ, nguyên liệu ổn định, không bị ảnh hưởng bởi lưu lượng '
          'gió.',
      'Kết hợp thổi và hút, đảm bảo không bị cám tồn đọng, năng suất cao, giảm '
          'gãy vỡ; quá trình xát mịn với thiết bị cấp nước có thể làm bóng hiệu '
          'quả.',
      'Tùy theo tình hình thực tế của nhà máy khách hàng, cửa nạp và xả liệu '
          'có thể linh hoạt thay đổi.',
      _smartControl,
    ],
  ),
  _s(
    'WHITENER_MNSW',
    'MNSW',
    'Máy xát trắng dạng 1 trục ngang',
    _gWhitening,
    '19',
    'rice_whitener_mnsw',
    [
      'Trục xát lăn dài hơn, giúp gạo mịn và sáng hơn, độ nguyên chất cao '
          'hơn.',
      'Sử dụng quạt bên ngoài, bổ sung khí từ 2 đầu trục và cổng nạp liệu, '
          'làm giảm nhiệt độ gạo, giảm tỉ lệ gãy, tỉ lệ cám thấp.',
    ],
  ),
  _s(
    'WHITENER_MNSW2',
    'MNSW × 2',
    'Máy xát trắng dạng 2 trục ngang',
    _gWhitening,
    '19',
    'rice_whitener_mnsw2',
    [
      'Trục xát lăn dài hơn, giúp gạo mịn và sáng hơn, độ trắng cao hơn.',
      'Thiết kế 2 trục xát song song, bộ thu cám độc lập, lưu lượng gió điều '
          'chỉnh độc lập, tạo điều kiện ổn định lưu lượng nguyên liệu trong 2 '
          'buồng xát.',
      'Sử dụng quạt bên ngoài, bổ sung khí từ 2 đầu trục và cổng nạp liệu, '
          'làm giảm nhiệt độ gạo, giảm tỉ lệ gãy, tỉ lệ cám thấp.',
    ],
  ),
  _s(
    'POLISHER_MPGW',
    'MPGW',
    'Máy lau bóng dạng 1 trục ngang',
    _gWhitening,
    '20',
    'rice_polisher_mpgw',
    _polisherFeatures,
  ),
  _s(
    'POLISHER_MPGW2',
    'MPGW × 2',
    'Máy lau bóng dạng 2 trục ngang',
    _gWhitening,
    '21',
    'rice_polisher_mpgw2',
    _polisherFeatures,
  ),
  _s(
    'POLISHER_MPGL',
    'MPGL',
    'Máy lau bóng dạng trục đứng',
    _gWhitening,
    '22',
    'rice_polisher_mpgl',
    [
      'Kết hợp linh hoạt 2 trục lau bóng, có thể đặt nối tiếp hoặc song song, '
          'dễ dàng tạo độ bóng cho gạo.',
      'Nguyên liệu được trộn đều bên trong trục lau, giúp tạo ra thành phẩm '
          'gạo đẹp hơn, bóng hơn.',
      'Có thể lựa chọn trang bị thêm bộ điều khiển thông minh, cài đặt dựa '
          'trên năng suất đầu ra, tự động ON/OFF và tự động kiểm soát lượng '
          'nước, dễ dàng vận hành.',
    ],
  ),
  _s(
    'GRADER_MMJX',
    'MMJX',
    'Sàng đảo / sàng phân cỡ MMJX160 - MMJX200',
    _gGrading,
    '22',
    'rice_grader_mmjx160',
    [
      'Bốn góc của sàng được thiết kế khớp nối mềm, linh hoạt, vận hành ổn '
          'định và hiệu suất cơ học cao.',
      'Model MMJX200 × (5+1)C và MMJX160 × (5+1)E được trang bị bộ điều khiển '
          'tốc độ nên tốc độ quay của sàng có thể điều chỉnh, thích hợp nhiều '
          'loại nguyên liệu khác nhau.',
      'Quy trình sàng phân cỡ đảm bảo năng suất tối ưu.',
      'Cổng nạp liệu kết nối với hút bụi, dễ dàng làm mát gạo, sạch bụi.',
      'Cổng xả được kết nối thiết bị làm mát để giảm độ ẩm và vón cục.',
      'Điều khiển tự động, trang bị màn hình điều khiển cảm ứng, vận hành dễ '
          'dàng.',
    ],
  ),
  _s(
    'GRADER_MMJX200_7',
    'MMJX 200',
    'Sàng đảo / sàng phân cỡ MMJX200 × (7+1)',
    _gGrading,
    '23',
    'rice_grader_mmjx200',
    [
      'Bốn góc của sàng được thiết kế khớp nối mềm, linh hoạt, vận hành ổn '
          'định và hiệu suất cao.',
      'Được trang bị bộ điều khiển tốc độ nên tốc độ quay của sàng có thể điều '
          'chỉnh, thích hợp nhiều loại nguyên liệu khác nhau.',
      'Quy trình sàng phân cỡ đảm bảo năng suất tối ưu.',
      'Cổng nạp liệu kết nối với hút bụi, dễ dàng làm mát gạo và làm sạch '
          'bụi.',
      'Cổng xả được kết nối thiết bị hút để làm mát và thông gió, làm giảm độ '
          'ẩm và vón cục.',
      'Điều khiển tự động, trang bị màn hình điều khiển cảm ứng, vận hành dễ '
          'dàng và trực quan.',
    ],
  ),
  _s(
    'GRADER_MMJX100',
    'MMJX 100',
    'Sàng đảo / sàng phân cỡ MMJX100 × 3',
    _gGrading,
    '23',
    'rice_grader_mmjx100',
    [
      'Có thể phân tách được nhiều cấp độ theo kích thước của hạt, 3 hướng '
          'chuyển động trên 1 tấm sàn.',
      'Có trang bị thiết bị hút để thông gió và làm mát nguyên liệu.',
    ],
  ),
  _s(
    'LENGTH_GRADER_MJXT',
    'MJXT',
    'Trống phân hạt',
    _gGrading,
    '24',
    'rice_length_grader',
    [
      'Sử dụng để phân loại gạo tấm.',
      'Điều chỉnh linh hoạt dựa theo vùng nguyên liệu và yêu cầu phân loại.',
      'Bảo vệ tốt bề mặt hạt.',
    ],
    application: 'Phân loại gạo tấm.',
  ),
  _s(
    'FILTER_TBHM',
    'TBHM',
    'Phin lọc bụi thân tròn',
    _gFilter,
    '25',
    'rice_filter_round',
    [
      'Thiết kế thân tròn, kết cấu vững chắc và ổn định cao.',
      'Giảm tiếng ồn.',
      'Bụi di chuyển theo luồng không khí được thổi ly tâm, giúp làm giảm sức '
          'cản, lọc bụi kép, tăng hiệu quả túi lọc.',
    ],
  ),
  _s(
    'FILTER_TBHM_WD',
    'TBHM-WD',
    'Phin lọc bụi hình hộp vuông',
    _gFilter,
    '25',
    'rice_filter_box',
    [
      'Túi lọc bụi được làm bằng túi chống thấm xếp đều.',
      'Trang bị van điện từ lưu lượng lớn, áp suất làm việc cao. Các đầu phun '
          'được phân bổ đều, áp suất đầu ra của mỗi đầu phun đều nhau.',
      'Trang bị bình tích khí áp cao, được xử lý chống gỉ để không ảnh hưởng '
          'đến hoạt động của van điện từ.',
      'Thiết kế hình hộp vuông, độ bền, kết cấu vững chắc; phần ống trên có '
          'thể lắp quạt hút, giảm tiếng ồn, sản xuất với công nghệ tiên tiến.',
    ],
  ),
  _s(
    'ELEVATOR_SEC',
    'SEC',
    'Gàu tải tốc độ chậm SEC',
    _gConveying,
    '26',
    'rice_elevator_sec',
    _slowElevatorFeatures,
  ),
  _s(
    'ELEVATOR_MS',
    'MS',
    'Gàu tải tốc độ chậm MS',
    _gConveying,
    '26',
    'rice_elevator_ms',
    _slowElevatorFeatures,
  ),
  _s(
    'ELEVATOR_TDTG',
    'TDTG',
    'Gàu tải',
    _gConveying,
    '27',
    'rice_elevator_tdtg',
    [
      'Là loại thiết bị vận chuyển theo phương thẳng đứng liên tục, phù hợp '
          'để vận chuyển vật liệu hạt, bột...',
      'Có cầu thang ở khe hở giữa 2 phần thân.',
    ],
    application:
        'Vận chuyển liên tục theo phương thẳng đứng vật liệu dạng '
        'hạt, bột.',
  ),
  _s('BELT_TDSG', 'TDSG', 'Băng tải', _gConveying, '27', 'rice_belt_conveyor', [
    'Phù hợp cho tất cả các quy mô sản xuất, tải hàng với khối lượng lớn.',
    'Hiệu suất ổn định, độ tin cậy cao, dễ dàng vận hành.',
    'Khả năng vận chuyển mạnh mẽ, khoảng cách vận chuyển xa, tiêu thụ năng '
        'lượng ít, chi phí sử dụng thấp.',
    'Thuận tiện trong điều khiển và khả năng tự động hóa cao.',
  ]),
  _s(
    'CHAIN_TGSH',
    'TGSH',
    'Xích cào TGSH',
    _gConveying,
    '28',
    'rice_chain_conveyor_tgsh',
    _chainFeatures,
    application: _chainApplication,
  ),
  _s(
    'CHAIN_TGSS',
    'TGSS',
    'Xích cào TGSS',
    _gConveying,
    '28',
    'rice_chain_conveyor',
    _chainFeatures,
    application: _chainApplication,
  ),
];

const _polisherFeatures = [
  'Trục lau bóng dài, làm cho bề mặt gạo mịn và sáng bóng hơn.',
  'Các thiết bị điện tử đặt bên trong máy, đảm bảo tính thẩm mỹ, không cần '
      'tủ điều khiển và tiết kiệm diện tích lắp đặt.',
  'Được trang bị thùng chứa nước di động, linh hoạt hơn khi máy hoạt động '
      'vào mùa đông.',
  'Lỗ trục chính lớn hơn so với các loại truyền thống giúp không khí lưu '
      'thông tốt hơn, tăng hiệu quả thông gió và xả bụi.',
  'Hệ thống điều khiển thông minh cho phép cài đặt trị số dòng điện đúng '
      'nhu cầu, thích hợp với tình hình sản xuất, tự động kiểm soát nguyên '
      'liệu và nước, đơn giản hóa vận hành và bảo trì.',
];

const _slowElevatorFeatures = [
  'Thiết kế tốc độ thấp để tăng độ bền, chống va đập.',
  'Tự động căng dây belt, phần chân đế dễ dàng làm sạch.',
  'Kiểu cấp liệu đặc biệt, giảm tỉ lệ gãy vỡ hạt.',
];

const _chainFeatures = [
  'Phạm vi ứng dụng rộng rãi, có thể dùng để vận chuyển bột, nguyên liệu '
      'dạng hạt và dạng khối nhỏ.',
  'Cấp và xả liệu đa điểm, dễ dàng hơn cho việc bố trí dây chuyền.',
  'Trang bị thiết bị làm sạch giúp hạn chế tích tụ nguyên liệu trong thiết '
      'bị và đầu cuối.',
  'Thành phần thiết bị từ các thương hiệu nổi tiếng, độ bền cao.',
  'Trang bị cảm biến, màn hình giám sát, theo dõi vận hành.',
  'Kích thước nhỏ gọn, dễ dàng lắp đặt và bảo trì.',
];

const _chainApplication =
    'Vận chuyển bột, nguyên liệu dạng hạt và dạng khối nhỏ.';

// ---------------------------------------------------------------------------
// Tiện ích dựng model
// ---------------------------------------------------------------------------

/// Dải giá trị trong catalog (VD 5~10). [min] == [max] là giá trị đơn.
class R {
  const R(this.min, this.max);
  const R.one(num v) : min = v, max = v;
  final num min;
  final num max;

  R operator +(R o) => R(min + o.min, max + o.max);
  R times(num k) => R(min * k, max * k);

  @override
  String toString() => min == max ? _n(min) : '${_n(min)} - ${_n(max)}';
}

String _n(num v) {
  final d = v.toDouble();
  if (d == d.roundToDouble()) return d.toInt().toString();
  return d.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
}

String _dim(String dxrxc) => '${dxrxc.replaceAll('x', ' x ')} mm';

Map<String, String> _t(String key, String label, String value) => {
  'group': 'technical',
  'key': key,
  'label': label,
  'value': value,
};
Map<String, String> _x(String key, String label, String value) => {
  'group': 'extra',
  'key': key,
  'label': label,
  'value': value,
};
Map<String, String> _i(String key, String label, String value) => {
  'group': 'install',
  'key': key,
  'label': label,
  'value': value,
};

Map<String, String> _h(String kind, String title, Object value) => {
  'kind': kind,
  'title': title,
  'value': '$value',
};

Map<String, String> _hCap(R cap) => _h('capacity', 'Năng suất (tấn/giờ)', cap);
Map<String, String> _hPower(Object kw) => _h('power', 'Công suất (kW)', kw);
Map<String, String> _hWeight(Object kg) => _h('weight', 'Khối lượng (kg)', kg);
Map<String, String> _hAir(R air) => _h('air', 'Lưu lượng gió (m³/giờ)', air);

Map<String, String> _power(String breakdown, R total) => _t(
  'power_kw',
  'Công suất điện',
  breakdown == '$total'
      ? '$total kW'
      : '$breakdown kW (tổng ${total.toString()} kW)',
);

Map<String, String> _air(R air, [String unit = 'm³/giờ']) =>
    _t('air_flow', 'Lưu lượng gió', '$air $unit');

Map<String, String> _dims(String d) =>
    _i('dimensions', 'Kích thước máy (D x R x C)', _dim(d));
Map<String, String> _weight(num kg, [String label = 'Khối lượng']) =>
    _i('weight', label, '${_n(kg)} kg');

Map<String, Object?> _m({
  required String id,
  required String series,
  required String model,
  required int page,
  required String stage,
  required R? capacity,
  required R? power,
  required List<Map<String, String>> highlights,
  required List<Map<String, String>> specs,
  String? image,
  Map<String, String> notes = const {},
  String? verificationNote,
}) => {
  'machineId': 'RICE__$id',
  'seriesCode': series,
  'model': model,
  'pdfPage': page,
  if (image != null) 'image': 'assets/images/$image.jpg',
  if (image != null) 'imageCaption': 'Ảnh minh họa $model',
  if (verificationNote != null) 'needsVerification': true,
  'verificationNote': ?verificationNote,
  'selection': {
    'stage': [stage],
    if (capacity != null)
      'capacity': {'min': capacity.min, 'max': capacity.max},
    if (power != null) 'power': {'max': power.max},
  },
  if (notes.isNotEmpty) 'selectionNotes': notes,
  'highlights': highlights,
  'specs': specs,
};

// ---------------------------------------------------------------------------
// 1. Máy sấy tháp tuần hoàn (trang 10)
// ---------------------------------------------------------------------------

List<Map<String, Object?>> _dryers() {
  // model, id, năng suất, công suất, gió, kích thước, khối lượng (tấn),
  // năng lượng, thời gian nạp, thời gian xả, tỉ lệ giảm ẩm
  final rows = [
    (
      '5H-10 (bản 5~10)',
      '5H-10-5-10',
      R(5, 10),
      9.2,
      R(10000, 14000),
      '2175x3590x10435',
      2.3,
      R(13, 15),
      R(50, 60),
      R(50, 65),
      R(0.5, 1.0),
    ),
    (
      '5H-10 (bản 5~12)',
      '5H-10-5-12',
      R(5, 12),
      9.2,
      R(10000, 14000),
      '2175x3590x11045',
      2.5,
      R(13, 15),
      R(50, 60),
      R(50, 65),
      R(0.5, 1.0),
    ),
    (
      '5H-10 (bản 5~15)',
      '5H-10-5-15',
      R(5, 15),
      9.2,
      R(10000, 14000),
      '2175x3590x12265',
      3.0,
      R(13, 15),
      R(50, 65),
      R(50, 70),
      R(0.5, 1.0),
    ),
    (
      '5H-20',
      '5H-20',
      R(7, 20),
      13.15,
      R(12500, 14000),
      '2270x4580x14230',
      3.7,
      R(20, 23),
      R(50, 65),
      R(50, 70),
      R(0.5, 1.0),
    ),
    (
      '5H-20A',
      '5H-20A',
      R(7, 20),
      15.15,
      R(17000, 20000),
      '2208x5040x12615',
      4.2,
      R(23, 26),
      R(50, 65),
      R(50, 70),
      R(0.6, 1.2),
    ),
    (
      '5H-30',
      '5H-30',
      R(10, 30),
      20.35,
      R(20000, 25000),
      '3525x4440x14720',
      5.0,
      R(30, 35),
      R(50, 70),
      R(50, 75),
      R(0.5, 1.0),
    ),
    (
      '5H-30A',
      '5H-30A',
      R(10, 30),
      20.35,
      R(20000, 25000),
      '3525x4940x13860',
      5.5,
      R(35, 40),
      R(50, 70),
      R(50, 75),
      R(0.55, 1.2),
    ),
  ];
  return [
    for (final (model, id, cap, kw, air, dims, tons, energy, load, out, moist)
        in rows)
      _m(
        id: id,
        series: 'DRYER_5H',
        model: model,
        page: 10,
        stage: 'drying',
        capacity: null,
        power: R.one(kw),
        notes: const {
          'capacity':
              'Máy sấy chọn theo khối lượng lúa mỗi mẻ sấy; cần xác nhận đơn '
              'vị năng suất với kỹ thuật trước khi so với năng suất dây '
              'chuyền.',
        },
        verificationNote:
            'Catalog ghi năng suất "tấn/giờ" và tiêu thụ năng lượng "kJ/giờ" '
            'cho máy sấy tuần hoàn (thường tính theo tấn/mẻ) — cần xác nhận '
            'đơn vị với nhà cung cấp.',
        highlights: [
          _hCap(cap),
          _hPower(_n(kw)),
          _h('weight', 'Khối lượng (tấn)', _n(tons)),
        ],
        specs: [
          _t('capacity', 'Năng suất', '$cap tấn/giờ (theo catalog)'),
          _t('power_kw', 'Công suất điện', '${_n(kw)} kW'),
          _air(air),
          _t('energy', 'Tiêu thụ năng lượng', '$energy kJ/giờ (theo catalog)'),
          _t('load_time', 'Thời gian nạp', '$load phút'),
          _t('discharge_time', 'Thời gian xả', '$out phút'),
          _t('moisture_rate', 'Tỉ lệ giảm độ ẩm', '$moist %/giờ'),
          _x(
            'fuel',
            'Nhiên liệu',
            'Trấu, rơm, gỗ, thân cây đậu phộng, lõi ngô, chất thải sinh khối '
                'khác...\nDầu diesel, dầu hỏa, khí gas tự nhiên, hơi nước...',
          ),
          _x(
            'safety',
            'Thiết bị an toàn',
            'Rơ le nhiệt, công tắc cảm biến áp suất, cảnh báo đầy đủ, Timer '
                'On/Off, cầu chì điều khiển.\nBảo vệ quá tải, cảm biến nhiệt '
                'độ, cảm biến quá nhiệt bất thường, máy tính kiểm soát độ ẩm.',
          ),
          _dims(dims),
          _i('weight', 'Khối lượng', '${_n(tons)} tấn'),
        ],
      ),
  ];
}

// ---------------------------------------------------------------------------
// 2. Sàng tạp chất (trang 11-12)
// ---------------------------------------------------------------------------

List<Map<String, Object?>> _cleaners() {
  final tqlg = [
    (
      'TQLG150A',
      'TQLG150A',
      R(10, 15),
      R(15, 20),
      '1.5 + 0.75 + 0.55',
      R.one(2.8),
      R(4000, 4500),
      2000,
      '2860x2010x2100',
    ),
    (
      'TQLG200',
      'TQLG200',
      R(20, 30),
      R(30, 50),
      '4 + 0.75 + 0.55',
      R.one(5.3),
      R(6000, 7500),
      3200,
      '2880x3320x2630',
    ),
    (
      'TQLG200 × 4',
      'TQLG200X4',
      R(40, 60),
      R(60, 100),
      '7.5 + 0.75 + 0.55 + 0.55',
      R.one(9.35),
      R(6000, 7500),
      4260,
      '3560x3320x3220',
    ),
  ];
  final tqlm = [
    (
      'TQLM125 × 2',
      'TQLM125X2',
      R(6, 9),
      0.75,
      '55 + 25',
      730,
      '2150x1650x1470',
    ),
    (
      'TQLM160 × 2',
      'TQLM160X2',
      R(8, 12),
      1.1,
      '70 + 32',
      950,
      '2150x2010x1470',
    ),
    (
      'TQLM200 × 2',
      'TQLM200X2',
      R(10, 15),
      1.1,
      '90 + 40',
      1100,
      '2150x2460x1470',
    ),
  ];
  return [
    for (final (model, id, cap, capLine, kw, total, air, kg, dims) in tqlg)
      _m(
        id: id,
        series: 'CLEANER_TQLG',
        model: model,
        page: 11,
        stage: 'cleaning',
        capacity: cap,
        power: total,
        highlights: [_hCap(cap), _hPower(total), _hWeight(kg)],
        specs: [
          _t('capacity', 'Năng suất - sàn nguyên liệu', '$cap tấn/giờ'),
          _t(
            'capacity_line',
            'Năng suất - sàn tạp chất trong dây chuyền',
            '$capLine tấn/giờ',
          ),
          _power(kw, total),
          _air(air),
          _dims(dims),
          _weight(kg),
        ],
      ),
    for (final (model, id, cap, kw, air, kg, dims) in tqlm)
      _m(
        id: id,
        series: 'CLEANER_TQLM',
        model: model,
        page: 12,
        stage: 'cleaning',
        capacity: cap,
        power: R.one(kw),
        highlights: [_hCap(cap), _hPower(_n(kw)), _hWeight(kg)],
        specs: [
          _t('capacity', 'Năng suất', '$cap tấn/giờ'),
          _t('power_kw', 'Công suất điện', '${_n(kw)} kW'),
          _t('air_flow', 'Lưu lượng gió', '$air m³/phút'),
          _dims(dims),
          _weight(kg),
        ],
      ),
  ];
}

List<Map<String, Object?>> _destoners() {
  final tqsx = [
    ('TQSX85B', R(3.5, 4.5), 0.75, R(3200, 3400), 340, '1520x1050x2200'),
    ('TQSX100B', R(5.0, 6.5), 0.75, R(3800, 4100), 380, '1520x1190x2200'),
    ('TQSX125A', R(7.0, 8.5), 1.1, R(4800, 5200), 400, '1520x1380x2200'),
  ];
  final tqsz = [
    ('TQSZ125', R(7, 9), R(5500, 7500), 0.25, 600, '1840x1600x2250'),
    ('TQSZ170', R(10, 13), R(9000, 10800), 0.25, 810, '2126x1935x2470'),
    ('TQSZ200', R(13, 15), R(10800, 12600), 0.25, 870, '2455x1925x2465'),
    ('TQSZ260', R(17, 20), R(13800, 17500), 0.37, 1150, '2954x1907x2764'),
  ];
  return [
    for (final (model, cap, kw, air, kg, dims) in tqsx)
      _m(
        id: model,
        series: 'DESTONER_TQSX',
        model: model,
        page: 12,
        stage: 'destoning',
        capacity: cap,
        power: R.one(kw),
        highlights: [_hCap(cap), _hPower(_n(kw)), _hWeight(kg)],
        specs: [
          _t('capacity', 'Năng suất', '$cap tấn/giờ'),
          _t('power_kw', 'Công suất điện', '${_n(kw)} kW'),
          _air(air),
          _t('pressure', 'Áp suất trong', '40 - 50 mmH₂O'),
          _dims(dims),
          _weight(kg),
        ],
      ),
    for (final (model, cap, air, kw, kg, dims) in tqsz)
      _m(
        id: model,
        series: 'DESTONER_TQSZ',
        model: model,
        page: 13,
        stage: 'destoning',
        capacity: cap,
        power: R.one(kw * 2),
        highlights: [_hCap(cap), _hPower('${_n(kw)} × 2'), _hWeight(kg)],
        specs: [
          _t('capacity', 'Năng suất', '$cap tấn/giờ'),
          _air(air),
          _power('${_n(kw)} × 2', R.one(kw * 2)),
          _dims(dims),
          _weight(kg),
        ],
      ),
  ];
}

// ---------------------------------------------------------------------------
// 3. Máy bóc vỏ lúa (trang 14-15)
// ---------------------------------------------------------------------------

List<Map<String, Object?>> _huskers() {
  // model, id, gạo dài, gạo tròn, công suất (chuỗi catalog), tổng, gió,
  // ru lô, khối lượng, kích thước, ảnh riêng
  final mlgq = [
    (
      'MLGQ25C',
      'MLGQ25C',
      R(3, 5),
      R(5, 6),
      '7.5',
      R.one(7.5),
      R(3400, 3700),
      'Φ 254 x 254',
      900,
      '1720x1350x2410',
      null,
    ),
    (
      'MLGQ36B',
      'MLGQ36B',
      R(5, 7),
      R(6, 9),
      '11',
      R.one(11),
      R(4000, 4500),
      'Φ 225 x 356',
      1000,
      '1720x1450x2410',
      null,
    ),
    (
      'MLGQ51B',
      'MLGQ51B',
      R(6, 9),
      R(8, 11),
      '15',
      R.one(15),
      R(5000, 5500),
      'Φ 254 x 508',
      1300,
      '1800x1620x2430',
      null,
    ),
    (
      'MLGQ25C + MKXF25',
      'MLGQ25C-MKXF25',
      R(3, 5),
      R(5, 6),
      '7.5 + 4 + 0.37',
      R.one(11.87),
      R(800, 1200),
      'Φ 254 x 254',
      1550,
      '2050x1560x2850',
      null,
    ),
    (
      'MLGQ25C × 2',
      'MLGQ25CX2',
      R(7, 10),
      R(9, 12),
      '2 × 7.5',
      R.one(15),
      R(5500, 6000),
      'Φ 254 x 254',
      1900,
      '2580x1350x2410',
      'rice_husker_mlgq_double',
    ),
    (
      'MLGQ36B × 2',
      'MLGQ36BX2',
      R(10, 14),
      R(12, 16),
      '2 × 11',
      R.one(22),
      R(6000, 6500),
      'Φ 225 x 356',
      2000,
      '2580x1450x2410',
      'rice_husker_mlgq_double',
    ),
  ];
  final smart = [
    (
      'MLGQ36D',
      'MLGQ36D',
      R(5, 7),
      R(6, 9),
      '2 × 22',
      R.one(44),
      R(4000, 4500),
      'Φ 225 x 356',
      1530,
      '1690x1470x2520',
    ),
    (
      'MLGQ36D × 2',
      'MLGQ36DX2',
      R(10, 14),
      R(12, 16),
      '4 × 22',
      R.one(88),
      R(6000, 6500),
      'Φ 225 x 356',
      2960,
      '2460x1620x2520',
    ),
    (
      'MLGQ51D',
      'MLGQ51D',
      R(7, 9),
      R(8, 11),
      '2 × 30',
      R.one(60),
      R(5500, 6000),
      'Φ 255 x 508',
      1700,
      '1690x1650x2520',
    ),
    (
      'MLGQ51D × 2',
      'MLGQ51DX2',
      R(12, 18),
      R(16, 22),
      '4 × 30',
      R.one(120),
      R(7000, 8000),
      'Φ 255 x 508',
      3400,
      '2540x1795x2520',
    ),
  ];
  List<Map<String, String>> specs(
    R long,
    R round,
    String kw,
    R total,
    R? air,
    String roller,
    num kg,
    String dims, {
    String powerLabel = 'Công suất điện',
    String capPrefix = 'Năng suất',
  }) => [
    _t('capacity_long', '$capPrefix - gạo dài', '$long tấn/giờ'),
    _t('capacity_round', '$capPrefix - gạo tròn', '$round tấn/giờ'),
    _t(
      'power_kw',
      powerLabel,
      kw == '$total' ? '$total kW' : '$kw kW (tổng $total kW)',
    ),
    if (air != null) _air(air),
    _t('roller', 'Ru lô (Φ x D)', '$roller mm'),
    _dims(dims),
    _weight(kg),
  ];
  return [
    for (final (model, id, long, round, kw, total, air, roller, kg, dims, img)
        in mlgq)
      _m(
        id: id,
        series: 'HUSKER_MLGQ',
        model: model,
        page: 14,
        stage: 'husking',
        capacity: long,
        power: total,
        image: img,
        highlights: [
          _h('capacity', 'Gạo dài (tấn/giờ)', long),
          _hPower(kw),
          _hWeight(kg),
        ],
        specs: specs(long, round, kw, total, air, roller, kg, dims),
      ),
    for (final (model, id, long, round, kw, total, air, roller, kg, dims)
        in smart)
      _m(
        id: id,
        series: 'HUSKER_SMART',
        model: model,
        page: 15,
        stage: 'husking',
        capacity: long,
        power: total,
        highlights: [
          _h('capacity', 'Gạo dài (tấn/giờ)', long),
          _hPower(kw),
          _hWeight(kg),
        ],
        specs: specs(
          long,
          round,
          kw,
          total,
          air,
          roller,
          kg,
          dims,
          powerLabel: 'Công suất mô tơ',
          capPrefix: 'Năng suất đầu vào',
        ),
      ),
    _m(
      id: 'MLGQ25D-MKXF25D',
      series: 'HUSKER_ASPIRATOR',
      model: 'MLGQ25D + MKXF25D',
      page: 15,
      stage: 'husking',
      capacity: const R(3, 5),
      power: R.one(34.37),
      highlights: [
        _h('capacity', 'Gạo dài (tấn/giờ)', const R(3, 5)),
        _hPower('34.37'),
        _hWeight(1750),
      ],
      specs: specs(
        const R(3, 5),
        const R(5, 6),
        '2 × 15 + 4 + 0.37',
        R.one(34.37),
        null,
        'Φ 254 x 254',
        1750,
        '2050x1560x2850',
        powerLabel: 'Công suất mô tơ',
        capPrefix: 'Năng suất đầu vào',
      ),
    ),
  ];
}

// ---------------------------------------------------------------------------
// 4. Gằng tách thóc (trang 16)
// ---------------------------------------------------------------------------

List<Map<String, Object?>> _separators() {
  final doubles = [
    (
      'MGCZ60 × 16 × 2',
      'MGCZ60X16X2',
      R(4.5, 5.5),
      R(5.5, 6.5),
      4,
      1350,
      '1980x1780x2100',
    ),
    (
      'MGCZ60 × 20 × 2',
      'MGCZ60X20X2',
      R(6.0, 8.0),
      R(7.0, 9.0),
      4,
      1450,
      '1980x1780x2250',
    ),
    (
      'MGCZ60B × 20 × 2',
      'MGCZ60BX20X2',
      R(9.0, 10),
      R(10, 12),
      2.2,
      2050,
      '2420x2130x2500',
    ),
    (
      'MGCZ80C × 20 × 2',
      'MGCZ80CX20X2',
      R(10, 12),
      R(12, 15),
      2.2,
      2850,
      '2800x2130x2400',
    ),
  ];
  final single = [
    ('MGCZ100 × 8B', 'MGCZ100X8B', R(2.2, 2.8), 550, '1700x1350x1550'),
    ('MGCZ100 × 12C', 'MGCZ100X12C', R(3.3, 4.2), 800, '1700x1350x1670'),
    ('MGCZ100 × 16C', 'MGCZ100X16C', R(4.4, 5.6), 900, '1700x1350x1810'),
  ];
  return [
    for (final (model, id, long, round, kw, kg, dims) in doubles)
      _m(
        id: id,
        series: 'SEPARATOR_DOUBLE',
        model: model,
        page: 16,
        stage: 'separating',
        capacity: long,
        power: R.one(kw),
        highlights: [
          _h('capacity', 'Gạo lứt - hạt dài (tấn/giờ)', long),
          _hPower(_n(kw)),
          _hWeight(kg),
        ],
        specs: [
          _t(
            'capacity_long',
            'Năng suất đầu ra gạo lứt - gạo dài',
            '$long tấn/giờ',
          ),
          _t(
            'capacity_round',
            'Năng suất đầu ra gạo lứt - gạo tròn',
            '$round tấn/giờ',
          ),
          _t('power_kw', 'Công suất điện', '${_n(kw)} kW'),
          _dims(dims),
          _weight(kg),
        ],
      ),
    for (final (model, id, cap, kg, dims) in single)
      _m(
        id: id,
        series: 'SEPARATOR_SINGLE',
        model: model,
        page: 16,
        stage: 'separating',
        capacity: cap,
        power: R.one(1.5),
        highlights: [
          _h('capacity', 'Gạo lứt (tấn/giờ)', cap),
          _hPower('1.5'),
          _hWeight(kg),
        ],
        specs: [
          _t('capacity', 'Năng suất đầu ra gạo lứt', '$cap tấn/giờ'),
          _t('power_kw', 'Công suất điện', '1.5 kW'),
          _i('dimensions', 'Kích thước bao (D x R x C)', _dim(dims)),
          _weight(kg),
        ],
      ),
  ];
}

// ---------------------------------------------------------------------------
// 5. Máy xát trắng (trang 17-19)
// ---------------------------------------------------------------------------

List<Map<String, Object?>> _whiteners() {
  // model, năng suất, động cơ chính, cấp liệu, quạt, kích thước, khối lượng
  final mnsl = [
    ('MNSL3000', R(2, 3.5), R.one(37), 1.5, 2.2, '1430x1390x1920', 1310),
    ('MNSL6500A', R(5, 8), R(37, 55), 1.5, 2.2, '1560x1470x2250', 1610),
    ('MNSL10000', R(10, 15), R(75, 90), 3.0, 2.2, '2800x1830x2340', 3080),
  ];
  final mntl = [
    ('MNTL21', R(4, 6), R(37, 45), 1.5, 2.2, '1430x1390x1920', 1310),
    ('MNTL26B', R(7, 10), R(45, 55), 1.5, 2.2, '1560x1470x2150', 1770),
    ('MNTL28A', R(9, 12), R(55, 75), 1.5, 2.2, '1560x1470x2250', 1850),
    ('MNTL30', R(10, 15), R(75, 90), 3.0, 2.2, '1880x1590x2330', 2280),
  ];
  Map<String, Object?> vertical(
    String series,
    int page,
    String model,
    R cap,
    R main,
    num feed,
    num fan,
    String dims,
    num kg, {
    required String mainLabel,
    required String feedLabel,
    required String fanLabel,
  }) {
    final total = main + R.one(feed) + R.one(fan);
    return _m(
      id: model,
      series: series,
      model: model,
      page: page,
      stage: 'whitening',
      capacity: cap,
      power: total,
      highlights: [_hCap(cap), _hPower(total), _hWeight(kg)],
      specs: [
        _t('capacity', 'Năng suất', '$cap tấn/giờ'),
        _t('power_main', mainLabel, '$main kW'),
        _t('power_feed', feedLabel, '${_n(feed)} kW'),
        _t('power_fan', fanLabel, '${_n(fan)} kW'),
        _t('power_kw', 'Tổng công suất điện', '$total kW'),
        _dims(dims),
        _weight(kg),
      ],
    );
  }

  final mnsw = [
    (
      'MNSW18F',
      'MNSW18F',
      R(2.0, 3.5),
      R(18.5, 30),
      R(1500, 2500),
      580,
      '2000x690x1860',
    ),
    (
      'MNSW21.5F',
      'MNSW21-5F',
      R(3.0, 6.0),
      R(30, 45),
      R(2000, 2500),
      660,
      '2050x700x1930',
    ),
    (
      'MNSW30D',
      'MNSW30D',
      R(5.5, 10),
      R(37, 55),
      R(2500, 3000),
      980,
      '2380x770x2170',
    ),
  ];
  final mnsw2 = [
    (
      'MNSW18F × 2',
      'MNSW18FX2',
      R(2, 3.5),
      R(18.5, 30),
      R(2000, 3000),
      1140,
      '2070x1050x2000',
    ),
    (
      'MNSW21.5F × 2',
      'MNSW21-5FX2',
      R(3, 6),
      R(30, 45),
      R(3000, 4000),
      1240,
      '2070x1100x2000',
    ),
    (
      'MNSW30D × 2',
      'MNSW30DX2',
      R(5.5, 10),
      R(37, 55),
      R(4000, 5000),
      1670,
      '2400x1170x2185',
    ),
  ];
  const noMotor = 'Khối lượng (không gồm động cơ)';
  return [
    for (final (model, cap, main, feed, fan, dims, kg) in mnsl)
      vertical(
        'WHITENER_MNSL',
        17,
        model,
        cap,
        main,
        feed,
        fan,
        dims,
        kg,
        mainLabel: 'Động cơ chính',
        feedLabel: 'Động cơ cấp liệu',
        fanLabel: 'Quạt thổi',
      ),
    for (final (model, cap, main, feed, fan, dims, kg) in mntl)
      vertical(
        'WHITENER_MNTL',
        18,
        model,
        cap,
        main,
        feed,
        fan,
        dims,
        kg,
        mainLabel: 'Máy chính',
        feedLabel: 'Động cơ trục vít cấp liệu',
        fanLabel: 'Động cơ quạt thổi',
      ),
    for (final (model, id, cap, kw, air, kg, dims) in mnsw)
      _m(
        id: id,
        series: 'WHITENER_MNSW',
        model: model,
        page: 19,
        stage: 'whitening',
        capacity: cap,
        power: kw,
        highlights: [_hCap(cap), _hPower(kw), _hWeight(kg)],
        specs: [
          _t('capacity', 'Năng suất', '$cap tấn/giờ'),
          _t('power_kw', 'Công suất điện', '$kw kW'),
          _air(air),
          _dims(dims),
          _weight(kg, noMotor),
        ],
      ),
    for (final (model, id, cap, kw, air, kg, dims) in mnsw2)
      _m(
        id: id,
        series: 'WHITENER_MNSW2',
        model: model,
        page: 19,
        stage: 'whitening',
        capacity: cap.times(2),
        power: kw.times(2),
        highlights: [
          _h('capacity', 'Năng suất (tấn/giờ)', '2 × ($cap)'),
          _hPower('2 × ($kw)'),
          _hWeight(kg),
        ],
        specs: [
          _t(
            'capacity',
            'Năng suất',
            '2 × ($cap) tấn/giờ (tổng ${cap.times(2)} tấn/giờ)',
          ),
          _t(
            'power_kw',
            'Công suất điện',
            '2 × ($kw) kW (tổng ${kw.times(2)} kW)',
          ),
          _air(air),
          _dims(dims),
          _weight(kg, noMotor),
        ],
      ),
  ];
}

// ---------------------------------------------------------------------------
// 6. Máy lau bóng (trang 20-22)
// ---------------------------------------------------------------------------

List<Map<String, Object?>> _polishers() {
  final mpgw = [
    (
      'MPGW19C',
      R(2.0, 3.5),
      R(37, 45),
      7.5,
      R(2000, 2500),
      1270,
      '1965x800x2155',
    ),
    (
      'MPGW158',
      R(4.0, 6.0),
      R(45, 55),
      15,
      R(3000, 3500),
      1840,
      '2520x850x2200',
    ),
    (
      'MPGW170',
      R(5.0, 7.0),
      R(55, 75),
      15,
      R(3500, 4000),
      1900,
      '2715x900x2200',
    ),
    (
      'MPGW188S',
      R(6.0, 9.0),
      R(55, 75),
      15,
      R(3500, 4000),
      2160,
      '2860x900x2270',
    ),
  ];
  // model, id, năng suất (chuỗi hiển thị), dải chọn máy, máy chính (chuỗi),
  // máy chính (dải), quạt, gió, khối lượng (null = catalog bỏ trống), kích
  // thước
  final mpgw2 = [
    (
      'MPGW19C × 2',
      'MPGW19CX2',
      '3 - 4.5 (liên tiếp) / 4 - 7 (song song)',
      R(3, 7),
      '55 - 75',
      R(55, 75),
      15,
      R(3500, 4000),
      1760,
      '2030x1500x2270',
    ),
    (
      'MPGW158 × 2',
      'MPGW158X2',
      '8 - 12',
      R(8, 12),
      '2 × (45 - 55)',
      R(90, 110),
      18.5,
      R(4000, 5000),
      3100,
      '2520x1350x2110',
    ),
    (
      'MPGW-PS158 × 2',
      'MPGW-PS158X2',
      '3.5 - 5 (liên tiếp) / 8 - 12 (song song)',
      R(3.5, 12),
      '75',
      R.one(75),
      18.5,
      R(4000, 5000),
      null,
      '3340x950x2575',
    ),
    (
      'MPGW190 × 2',
      'MPGW190X2',
      '12 - 18',
      R(12, 18),
      '2 × (55 - 75)',
      R(110, 150),
      22,
      R(5000, 6000),
      null,
      '3000x1660x2427',
    ),
  ];
  return [
    for (final (model, cap, main, fan, air, kg, dims) in mpgw)
      _polisher(
        'POLISHER_MPGW',
        20,
        model,
        model,
        '$cap',
        cap,
        '$main',
        main,
        fan,
        air,
        kg,
        dims,
      ),
    for (final (model, id, capText, cap, mainText, main, fan, air, kg, dims)
        in mpgw2)
      _polisher(
        'POLISHER_MPGW2',
        21,
        model,
        id,
        capText,
        cap,
        mainText,
        main,
        fan,
        air,
        kg,
        dims,
        capLabel: 'Năng suất (3 - 4 đường đánh bóng)',
      ),
    _m(
      id: 'MPGL16',
      series: 'POLISHER_MPGL',
      model: 'MPGL16',
      page: 22,
      stage: 'polishing',
      capacity: const R(2.0, 3.0),
      power: R.one(37),
      highlights: [_hCap(const R(2.0, 3.0)), _hPower('37'), _hWeight(1220)],
      specs: [
        _t('capacity', 'Năng suất', '2 - 3 tấn/giờ'),
        _t('power_kw', 'Công suất điện', '37 kW'),
        _air(const R(1500, 1800)),
        _t('resistance', 'Trở lực máy', '300 mmH₂O'),
        _dims('1760x1000x2170'),
        _weight(1220),
      ],
    ),
  ];
}

Map<String, Object?> _polisher(
  String series,
  int page,
  String model,
  String id,
  String capText,
  R cap,
  String mainText,
  R main,
  num fan,
  R air,
  num? kg,
  String dims, {
  String capLabel = 'Năng suất',
}) {
  final total = main + R.one(fan);
  return _m(
    id: id,
    series: series,
    model: model,
    page: page,
    stage: 'polishing',
    capacity: cap,
    power: total,
    highlights: [
      _hCap(cap),
      _hPower(total),
      if (kg != null) _hWeight(kg) else _hAir(air),
    ],
    specs: [
      _t('capacity', capLabel, '$capText tấn/giờ'),
      _t('power_main', 'Công suất máy chính', '$mainText kW'),
      _t('power_fan', 'Công suất quạt thổi', '${_n(fan)} kW'),
      _t('power_kw', 'Tổng công suất điện', '$total kW'),
      _air(air),
      _t('water_pressure', 'Áp suất nước', '0.25 - 0.3 MPa'),
      _dims(dims),
      if (kg != null) _weight(kg),
    ],
  );
}

// ---------------------------------------------------------------------------
// 7. Sàng đảo / sàng phân cỡ (trang 22-23) và trống phân hạt (trang 24)
// ---------------------------------------------------------------------------

List<Map<String, Object?>> _graders() {
  // series, trang, model, id, năng suất, công suất, gió, khối lượng, kích thước
  final rows = [
    (
      'GRADER_MMJX',
      22,
      'MMJX160 × (4+1)',
      'MMJX160X4-1',
      R(5, 6.5),
      1.5,
      800,
      1660,
      '2140x2240x2030',
    ),
    (
      'GRADER_MMJX',
      22,
      'MMJX160 × (5+1)E',
      'MMJX160X5-1E',
      R(8, 10),
      2.2,
      900,
      2000,
      '2220x2340x2290',
    ),
    (
      'GRADER_MMJX',
      22,
      'MMJX200 × (5+1)C',
      'MMJX200X5-1C',
      R(10, 13),
      2.2,
      900,
      2340,
      '2250x2680x2350',
    ),
    (
      'GRADER_MMJX200_7',
      23,
      'MMJX200 × (7+1)',
      'MMJX200X7-1',
      R(13, 18),
      3,
      null,
      3060,
      '2450x2600x3095',
    ),
    (
      'GRADER_MMJX100',
      23,
      'MMJX100 × 3',
      'MMJX100X3',
      R(2, 3),
      1.1,
      920,
      null,
      '1760x1520x1480',
    ),
  ];
  return [
    for (final (series, page, model, id, cap, kw, air, kg, dims) in rows)
      _m(
        id: id,
        series: series,
        model: model,
        page: page,
        stage: 'grading',
        capacity: cap,
        power: R.one(kw),
        highlights: [
          _hCap(cap),
          _hPower(_n(kw)),
          if (kg != null) _hWeight(kg) else _hAir(R.one(air!)),
        ],
        specs: [
          _t('capacity', 'Năng suất', '$cap tấn/giờ'),
          _t('power_kw', 'Công suất điện', '${_n(kw)} kW'),
          // MMJX200 × (7+1): lưu lượng gió 1500 - 2000 m³/giờ.
          _air(air == null ? const R(1500, 2000) : R.one(air)),
          _dims(dims),
          if (kg != null) _weight(kg),
        ],
      ),
  ];
}

List<Map<String, Object?>> _lengthGraders() {
  final rows = [
    ('MJXT42-1', R(0.6, 1.0), '0.75', 0.75, 350, '2760x600x1260'),
    ('MJXT42BL-2', R(1.2, 2.0), '2 × 0.75', 1.5, 660, '2780x600x1440'),
    ('MJXT42BL-3', R(1.8, 3.0), '3 × 0.75', 2.25, 940, '2780x600x2480'),
    ('MJXT42CL-3', R(1.6, 2.5), '3 × 0.75', 2.25, 940, '3080x600x2620'),
    ('MJXT71-1', R(1.5, 2.0), '1.5', 1.5, 750, '3540x1050x1020'),
    ('MJXT71CL-2', R(2.5, 3.0), '2 × 1.5', 3, 1450, '3640x1050x2100'),
    ('MJXT71BL-2', R(3.0, 4.0), '2 × 1.5', 3, 1450, '3540x1050x2560'),
  ];
  return [
    for (final (model, cap, kw, total, kg, dims) in rows)
      _m(
        id: model,
        series: 'LENGTH_GRADER_MJXT',
        model: model,
        page: 24,
        stage: 'broken_grading',
        capacity: cap,
        power: R.one(total),
        highlights: [_hCap(cap), _hPower(kw), _hWeight(kg)],
        specs: [
          _t('capacity', 'Năng suất', '$cap tấn/giờ'),
          _power(kw, R.one(total)),
          _dims(dims),
          _weight(kg),
        ],
      ),
  ];
}

// ---------------------------------------------------------------------------
// 8. Phin lọc bụi (trang 25)
// ---------------------------------------------------------------------------

const _filterCapacityNote =
    'Phin lọc bụi chọn theo lưu lượng gió của hệ thống hút, catalog không '
    'ghi năng suất tấn/giờ.';

List<Map<String, Object?>> _filters() {
  // model, công suất, gió, diện tích lọc, khối lượng — theo túi lọc
  // 1800 / 2000 / 2400 mm
  final round = [
    (
      'TBHM78',
      2.2,
      '15000 / 17000 / 20000',
      R(15000, 20000),
      '51.5 / 57.3 / 69.1',
      '1730 / 1770 / 1820',
    ),
    (
      'TBHM104',
      3.0,
      '20000 / 22000 / 25000',
      R(20000, 25000),
      '68.6 / 76.5 / 92.1',
      '2140 / 2210 / 2360',
    ),
    (
      'TBHM130',
      3.0,
      '25000 / 29000 / 35000',
      R(25000, 35000),
      '88.1 / 97.9 / 117.5',
      '2540 / 2580 / 2640',
    ),
    (
      'TBHM156',
      3.0,
      '30000 / 35000 / 41000',
      R(30000, 41000),
      '103 / 114.7 / 138.2',
      '3700 / 3770 / 3850',
    ),
  ];
  final box = [
    ('TBHM-WD322 × 2000', 'TBHM-WD322X2000', 2000, R(15000, 35000), 253, 2458),
    ('TBHM-WD322 × 2400', 'TBHM-WD322X2400', 2400, R(18000, 45000), 303, 2678),
  ];
  const bags = '(túi lọc 1800 / 2000 / 2400 mm)';
  return [
    for (final (model, kw, airText, air, area, kg) in round)
      _m(
        id: model,
        series: 'FILTER_TBHM',
        model: model,
        page: 25,
        stage: 'dust_filter',
        capacity: null,
        power: R.one(kw),
        notes: const {'capacity': _filterCapacityNote},
        verificationNote:
            'Catalog ghi đơn vị diện tích lọc là "m³"; app hiển thị m².',
        highlights: [
          _hAir(air),
          _h('size', 'Diện tích lọc (m²)', area.split(' / ').last),
          _hPower(_n(kw)),
        ],
        specs: [
          _t('air_flow', 'Lưu lượng gió', '$airText m³/giờ $bags'),
          _t('bag_length', 'Độ dài túi lọc', '1800 / 2000 / 2400 mm'),
          _t('filter_area', 'Diện tích lọc', '$area m² $bags'),
          _t('power_kw', 'Công suất điện', '${_n(kw)} kW'),
          _i('weight', 'Khối lượng', '$kg kg $bags'),
        ],
      ),
    for (final (model, id, bag, air, area, kg) in box)
      _m(
        id: id,
        series: 'FILTER_TBHM_WD',
        model: model,
        page: 25,
        stage: 'dust_filter',
        capacity: null,
        power: null,
        notes: const {
          'capacity': _filterCapacityNote,
          'power': 'Catalog chưa ghi công suất điện của phin lọc TBHM-WD.',
        },
        verificationNote:
            'Catalog ghi đơn vị lưu lượng gió là "m³"; app hiển thị m³/giờ '
            'như các phin lọc khác.',
        highlights: [
          _hAir(air),
          _h('size', 'Diện tích lọc (m²)', area),
          _hWeight(kg),
        ],
        specs: [
          _air(air),
          _t('bag_length', 'Độ dài túi lọc', '$bag mm'),
          _t('filter_area', 'Diện tích lọc', '$area m²'),
          _i('weight', 'Trọng lượng', '$kg kg'),
        ],
      ),
  ];
}

// ---------------------------------------------------------------------------
// 9. Thiết bị tải hàng (trang 26-28)
// ---------------------------------------------------------------------------

List<Map<String, Object?>> _conveyors() {
  final sec = [
    ('SEC6S-A', R(6, 8), R(1.1, 1.5)),
    ('SEC7S-A', R(9, 12), R(1.5, 2.2)),
    ('SEC8S-A', R(12, 18), R(2.2, 3.0)),
    ('SEC-10S', R(27, 35), R(4.0, 11)),
    ('SEC-12S', R(40, 50), R(4.0, 11)),
  ];
  final ms = [
    ('MS-6TB', R(5, 7), R(1.1, 1.5)),
    ('MS-10TA', R(7, 10), R.one(1.5)),
    ('MS-15T', R(12, 15), R(2.2, 3.0)),
    ('MS-25T', R(20, 25), R(4.0, 5.5)),
  ];
  // model, id, đường kính đầu, năng suất, chiều dài, công suất
  final tdtg = [
    ('TDTG20/15A', 'TDTG20-15A', 200, R(4.5, 5.5), 15, R(1.1, 1.5)),
    ('TDTG26/18D', 'TDTG26-18D', 260, R(9, 11), 17, R.one(2.2)),
    ('TDTG30/23', 'TDTG30-23', 300, R(15, 18), 20, R(3, 4)),
    ('TDTG30/26', 'TDTG30-26', 300, R(18, 22), 20, R(3, 5.5)),
    ('TDTG40/28', 'TDTG40-28', 400, R(35, 45), 25, R(4, 7.5)),
    ('TDTG50/33', 'TDTG50-33', 500, R(50, 60), 35, R(5.5, 15)),
    ('TDTG60/47', 'TDTG60-47', 600, R(100, 120), 45, R(15, 22)),
    ('TDTG80/56', 'TDTG80-56', 800, R(200, 300), 50, R(22, 55)),
  ];
  // model, gạo, lúa, công suất
  final tdsg = [
    ('TDSG40', R(15, 25), R(12, 20), R(1.1, 7.5)),
    ('TDSG50', R(22, 36), R(20, 32), R(1.1, 7.5)),
    ('TDSG65', R(50, 60), R(48, 54), R(2.2, 7.5)),
    ('TDSG80', R(80, 100), R(70, 90), R(3, 15)),
  ];
  // model, chiều rộng, chiều cao, năng suất khuyến cáo
  final tgsh = [
    ('TGSH20', 200, 250, R(10, 18)),
    ('TGSH25', 250, 250, R(15, 23)),
    ('TGSH32', 320, 390, R(20, 32)),
  ];
  final tgss = [
    ('TGSS25', 250, 370, R(24, 40)),
    ('TGSS32', 320, 370, R(35, 60)),
    ('TGSS40', 400, 500, R(50, 80)),
    ('TGSS50', 500, 610, R(80, 120)),
  ];
  Map<String, Object?> slow(String series, String model, R cap, R kw) => _m(
    id: model,
    series: series,
    model: model,
    page: 26,
    stage: 'conveying',
    capacity: cap,
    power: kw,
    highlights: [_hCap(cap), _hPower(kw)],
    specs: [
      _t('capacity', 'Năng suất tải hàng', '$cap tấn/giờ'),
      _t('power_kw', 'Công suất điện', '$kw kW'),
    ],
  );
  Map<String, Object?> chain(
    String series,
    String model,
    int width,
    int height,
    R cap,
    int distance,
    R kw,
  ) => _m(
    id: model,
    series: series,
    model: model,
    page: 28,
    stage: 'conveying',
    capacity: cap,
    power: kw,
    highlights: [
      _h('capacity', 'Năng suất khuyến cáo (tấn/giờ)', cap),
      _hPower(kw),
      _h('size', 'Chiều rộng (mm)', width),
    ],
    specs: [
      _t('capacity', 'Năng suất (khuyến cáo)', '$cap tấn/giờ'),
      _t('power_kw', 'Công suất điện', '$kw kW'),
      _t('distance', 'Khoảng cách truyền tải', '$distance m'),
      _i('width_mm', 'Chiều rộng', '$width mm'),
      _i('height_mm', 'Chiều cao', '$height mm'),
    ],
  );
  return [
    for (final (model, cap, kw) in sec) slow('ELEVATOR_SEC', model, cap, kw),
    for (final (model, cap, kw) in ms) slow('ELEVATOR_MS', model, cap, kw),
    for (final (model, id, head, cap, length, kw) in tdtg)
      _m(
        id: id,
        series: 'ELEVATOR_TDTG',
        model: model,
        page: 27,
        stage: 'conveying',
        capacity: cap,
        power: kw,
        highlights: [
          _hCap(cap),
          _hPower(kw),
          _h('size', 'Chiều dài (m)', length),
        ],
        specs: [
          _t('capacity', 'Năng suất tải hàng', '$cap tấn/giờ'),
          _t('power_kw', 'Công suất điện', '$kw kW'),
          _t('head_diameter', 'Đường kính đầu', 'Φ $head mm'),
          _i('length', 'Chiều dài', '$length m'),
        ],
      ),
    for (final (model, rice, paddy, kw) in tdsg)
      _m(
        id: model,
        series: 'BELT_TDSG',
        model: model,
        page: 27,
        stage: 'conveying',
        capacity: paddy,
        power: kw,
        highlights: [
          _h('capacity', 'Năng suất gạo (tấn/giờ)', rice),
          _h('capacity', 'Năng suất lúa (tấn/giờ)', paddy),
          _hPower(kw),
        ],
        specs: [
          _t('capacity_rice', 'Năng suất gạo', '$rice tấn/giờ'),
          _t('capacity_paddy', 'Năng suất lúa', '$paddy tấn/giờ'),
          _t('power_kw', 'Công suất điện', '$kw kW'),
        ],
      ),
    for (final (model, width, height, cap) in tgsh)
      chain('CHAIN_TGSH', model, width, height, cap, 30, const R(1.5, 7.5)),
    for (final (model, width, height, cap) in tgss)
      chain('CHAIN_TGSS', model, width, height, cap, 40, const R(3, 15)),
  ];
}
