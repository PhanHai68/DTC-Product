class AcompSpecModel {
  final String modelCode;
  final String series;
  final double powerKW;
  final double powerHP;
  final double flow7Bar;
  final double flow8Bar;
  final String airOutlet;
  final double lubricant;
  final double weight;
  final String dimensions;

  AcompSpecModel({
    required this.modelCode,
    required this.series,
    required this.powerKW,
    required this.powerHP,
    required this.flow7Bar,
    required this.flow8Bar,
    required this.airOutlet,
    required this.lubricant,
    required this.weight,
    required this.dimensions,
  });

  factory AcompSpecModel.fromExcelRow(List<dynamic> row) {
    return AcompSpecModel(
      modelCode: row[0]?.toString() ?? '',
      series: row[1]?.toString() ?? '',
      powerKW: double.tryParse(row[2]?.toString() ?? '0') ?? 0,
      powerHP: double.tryParse(row[3]?.toString() ?? '0') ?? 0,
      flow7Bar: double.tryParse(row[4]?.toString() ?? '0') ?? 0,
      flow8Bar: double.tryParse(row[5]?.toString() ?? '0') ?? 0,
      airOutlet: row[6]?.toString() ?? '',
      lubricant: double.tryParse(row[7]?.toString() ?? '0') ?? 0,
      weight: double.tryParse(row[8]?.toString() ?? '0') ?? 0,
      dimensions: row[9]?.toString() ?? '',
    );
  }
}
