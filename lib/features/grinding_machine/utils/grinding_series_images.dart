/// Ảnh thực tế theo dòng máy nghiền (1 ảnh dùng chung cho mọi model trong
/// dòng). Dùng ở header dòng máy, ảnh nhỏ trong danh sách model, trang
/// thông số và PDF. Bổ sung ảnh cho dòng khác: thêm 1 dòng vào 2 bảng dưới.
abstract final class GrindingSeriesImages {
  static const _paths = <String, String>{
    'ASP_ULTRAFINE': 'assets/images/home_grinding_machine_asp350.png',
    // Ảnh từ docs_database/06_May_Nghien_BR/Hinh_anh_may.docx.
    'AS_SMALL_HAMMER': 'assets/images/grinding_as_small_hammer.jpg',
    'ASDF_MULTISTAGE': 'assets/images/grinding_asdf_multistage.jpg',
    'ASZ_PIN': 'assets/images/grinding_asz_pin.jpg',
    'ASC_COARSE': 'assets/images/grinding_asc_coarse.png',
    'AS_ROLLER': 'assets/images/grinding_as_roller.png',
    'ASU_UNIVERSAL': 'assets/images/grinding_asu_turbine.png',
    'ASK_JET': 'assets/images/grinding_ask_jet.png',
    'ASG_UNIVERSAL_SYSTEM': 'assets/images/grinding_asg_cyclone.png',
    'ASF_FITZ_MILL': 'assets/images/grinding_asf_fitz.png',
    'ASF_AS_HAMMER': 'assets/images/grinding_as_hammer.jpg',
    'AS_CRYOGENIC': 'assets/images/grinding_as_cryogenic.jpg',
  };

  /// Chú thích khi ảnh là ảnh đại diện cho cả dòng (không phải đúng model).
  static const _captions = <String, String>{
    'ASP_ULTRAFINE': 'Ảnh đại diện: ASP-350',
    'AS_SMALL_HAMMER': 'Ảnh đại diện dòng AS',
    'ASDF_MULTISTAGE': 'Ảnh đại diện dòng ASDF',
    'ASZ_PIN': 'Ảnh đại diện dòng ASZ',
    'ASC_COARSE': 'Ảnh đại diện dòng ASC',
    'AS_ROLLER': 'Ảnh đại diện: Roller mill',
    'ASU_UNIVERSAL': 'Ảnh đại diện dòng ASU',
    'ASK_JET': 'Ảnh đại diện dòng ASK',
    'ASG_UNIVERSAL_SYSTEM': 'Ảnh đại diện dòng ASG',
    'ASF_FITZ_MILL': 'Ảnh đại diện dòng ASF',
    'ASF_AS_HAMMER': 'Ảnh đại diện dòng AS (Hammer mill)',
    'AS_CRYOGENIC': 'Ảnh đại diện dòng máy nghiền siêu lạnh',
  };

  static String? pathFor(String seriesCode) => _paths[seriesCode];

  static String? captionFor(String seriesCode) => _captions[seriesCode];
}
