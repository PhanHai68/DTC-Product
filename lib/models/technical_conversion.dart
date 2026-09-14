/// Model và bảng dữ liệu kỹ thuật chuyển đổi máy tách màu
/// Dựa trên Database_QuyDoi_KyThuat_MayTachMau.xlsx
library;

class MeshConversionItem {
  final String mesh;
  final String micron;
  final String mm;
  final String inch;

  const MeshConversionItem({
    required this.mesh,
    required this.micron,
    required this.mm,
    required this.inch,
  });
}

class PipeSizeItem {
  final String dn;
  final String inch;
  final String odMm;
  final String idMm;

  const PipeSizeItem({
    required this.dn,
    required this.inch,
    required this.odMm,
    required this.idMm,
  });
}

abstract final class TechnicalConversionData {
  static const List<MeshConversionItem> meshList = [
    MeshConversionItem(mesh: '3', micron: '6730', mm: '6.73', inch: '0.265'),
    MeshConversionItem(mesh: '4', micron: '4760', mm: '4.76', inch: '0.187'),
    MeshConversionItem(mesh: '5', micron: '4000', mm: '4', inch: '0.157'),
    MeshConversionItem(mesh: '6', micron: '3360', mm: '3.36', inch: '0.132'),
    MeshConversionItem(mesh: '7', micron: '2830', mm: '2.83', inch: '0.111'),
    MeshConversionItem(mesh: '8', micron: '2380', mm: '2.38', inch: '0.0937'),
    MeshConversionItem(mesh: '10', micron: '2000', mm: '2', inch: '0.0787'),
    MeshConversionItem(mesh: '12', micron: '1680', mm: '1.68', inch: '0.0661'),
    MeshConversionItem(mesh: '14', micron: '1410', mm: '1.41', inch: '0.0555'),
    MeshConversionItem(mesh: '16', micron: '1190', mm: '1.19', inch: '0.0469'),
    MeshConversionItem(mesh: '18', micron: '1000', mm: '1', inch: '0.0394'),
    MeshConversionItem(mesh: '20', micron: '841', mm: '0.841', inch: '0.0331'),
    MeshConversionItem(mesh: '25', micron: '707', mm: '0.707', inch: '0.0278'),
    MeshConversionItem(mesh: '30', micron: '595', mm: '0.595', inch: '0.0234'),
    MeshConversionItem(mesh: '35', micron: '500', mm: '0.5', inch: '0.0197'),
    MeshConversionItem(mesh: '40', micron: '420', mm: '0.42', inch: '0.0165'),
    MeshConversionItem(mesh: '45', micron: '354', mm: '0.354', inch: '0.0139'),
    MeshConversionItem(mesh: '50', micron: '297', mm: '0.297', inch: '0.0117'),
    MeshConversionItem(mesh: '60', micron: '250', mm: '0.25', inch: '0.0098'),
    MeshConversionItem(mesh: '70', micron: '210', mm: '0.21', inch: '0.0083'),
    MeshConversionItem(mesh: '80', micron: '177', mm: '0.177', inch: '0.007'),
    MeshConversionItem(mesh: '100', micron: '149', mm: '0.149', inch: '0.0059'),
    MeshConversionItem(mesh: '120', micron: '125', mm: '0.125', inch: '0.0049'),
    MeshConversionItem(mesh: '140', micron: '105', mm: '0.105', inch: '0.0041'),
    MeshConversionItem(mesh: '170', micron: '88', mm: '0.088', inch: '0.0035'),
    MeshConversionItem(mesh: '200', micron: '74', mm: '0.074', inch: '0.0029'),
    MeshConversionItem(mesh: '230', micron: '63', mm: '0.063', inch: '0.0025'),
    MeshConversionItem(mesh: '270', micron: '53', mm: '0.053', inch: '0.0021'),
    MeshConversionItem(mesh: '325', micron: '44', mm: '0.044', inch: '0.0017'),
    MeshConversionItem(mesh: '400', micron: '37', mm: '0.037', inch: '0.0015'),
    MeshConversionItem(mesh: '500', micron: '25', mm: '0.025', inch: '0.001'),
    MeshConversionItem(mesh: '600', micron: '20', mm: '0.02', inch: '0.0008'),
    MeshConversionItem(mesh: '800', micron: '15', mm: '0.015', inch: '0.0006'),
    MeshConversionItem(mesh: '1000', micron: '10', mm: '0.01', inch: '0.0004'),
    MeshConversionItem(mesh: '1200', micron: '5', mm: '0.005', inch: '0.0002'),
  ];

  static const List<PipeSizeItem> pipeSizeList = [
    PipeSizeItem(dn: 'DN6', inch: '1/8"', odMm: '10.3', idMm: '6.8'),
    PipeSizeItem(dn: 'DN8', inch: '1/4"', odMm: '13.7', idMm: '9.2'),
    PipeSizeItem(dn: 'DN10', inch: '3/8"', odMm: '17.1', idMm: '12.5'),
    PipeSizeItem(dn: 'DN15', inch: '1/2"', odMm: '21.3', idMm: '15.8'),
    PipeSizeItem(dn: 'DN20', inch: '3/4"', odMm: '26.7', idMm: '20.9'),
    PipeSizeItem(dn: 'DN25', inch: '1"', odMm: '33.4', idMm: '26.6'),
    PipeSizeItem(dn: 'DN32', inch: '1-1/4"', odMm: '42.2', idMm: '35.1'),
    PipeSizeItem(dn: 'DN40', inch: '1-1/2"', odMm: '48.3', idMm: '40.9'),
    PipeSizeItem(dn: 'DN50', inch: '2"', odMm: '60.3', idMm: '52.5'),
    PipeSizeItem(dn: 'DN65', inch: '2-1/2"', odMm: '73', idMm: '62.7'),
    PipeSizeItem(dn: 'DN80', inch: '3"', odMm: '88.9', idMm: '77.9'),
    PipeSizeItem(dn: 'DN100', inch: '4"', odMm: '114.3', idMm: '102.3'),
    PipeSizeItem(dn: 'DN125', inch: '5"', odMm: '141.3', idMm: '128.2'),
    PipeSizeItem(dn: 'DN150', inch: '6"', odMm: '168.3', idMm: '154.1'),
    PipeSizeItem(dn: 'DN200', inch: '8"', odMm: '219.1', idMm: '202.7'),
    PipeSizeItem(dn: 'DN250', inch: '10"', odMm: '273.1', idMm: '254.5'),
    PipeSizeItem(dn: 'DN300', inch: '12"', odMm: '323.9', idMm: '304.8'),
  ];

  /// Chuyển đổi áp suất từ đơn vị cơ sở Bar
  /// Bar, PSI, MPa, kgf/cm² (Ký), kPa
  static Map<String, double> convertPressure(double value, String fromUnit) {
    // Đổi về Bar trước
    double bar = 0.0;
    switch (fromUnit) {
      case 'Bar':
        bar = value;
        break;
      case 'PSI':
        bar = value / 14.5038;
        break;
      case 'MPa':
        bar = value * 10.0;
        break;
      case 'kgf/cm²':
        bar = value / 1.01972;
        break;
      case 'kPa':
        bar = value / 100.0;
        break;
    }

    return {
      'Bar': bar,
      'PSI': bar * 14.5038,
      'MPa': bar * 0.1,
      'kgf/cm²': bar * 1.01972,
      'kPa': bar * 100.0,
    };
  }

  /// Chuyển đổi lưu lượng khí từ đơn vị cơ sở m³/min
  /// m³/min, L/min, CFM, m³/h, L/s
  static Map<String, double> convertAirFlow(double value, String fromUnit) {
    // Đổi về m³/min trước
    double m3PerMin = 0.0;
    switch (fromUnit) {
      case 'm³/min':
        m3PerMin = value;
        break;
      case 'L/min':
        m3PerMin = value / 1000.0;
        break;
      case 'CFM':
        m3PerMin = value / 35.3147;
        break;
      case 'm³/h':
        m3PerMin = value / 60.0;
        break;
      case 'L/s':
        m3PerMin = (value * 60.0) / 1000.0;
        break;
    }

    return {
      'm³/min': m3PerMin,
      'L/min': m3PerMin * 1000.0,
      'CFM': m3PerMin * 35.3147,
      'm³/h': m3PerMin * 60.0,
      'L/s': (m3PerMin * 1000.0) / 60.0,
    };
  }
}
