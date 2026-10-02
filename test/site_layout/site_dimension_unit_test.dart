import 'package:flutter_test/flutter_test.dart';
import 'package:dtc_product/features/site_layout/models/site_layout_models.dart';

void main() {
  group('SiteDimensionUnit', () {
    test('quy đổi m/cm/mm sang millimet và ngược lại', () {
      expect(SiteDimensionUnit.meter.parseToMillimeters('12,345'), 12345);
      expect(SiteDimensionUnit.centimeter.parseToMillimeters('1234.5'), 12345);
      expect(SiteDimensionUnit.millimeter.parseToMillimeters('12345'), 12345);

      expect(SiteDimensionUnit.meter.format(12345), '12.345 m');
      expect(SiteDimensionUnit.centimeter.format(12345), '1234.5 cm');
      expect(SiteDimensionUnit.millimeter.format(12345), '12345 mm');
    });

    test('loại bỏ số 0 thập phân dư và mặc định dữ liệu cũ là mét', () {
      expect(SiteDimensionUnit.meter.formatValue(10000), '10');
      expect(SiteDimensionUnit.centimeter.formatValue(10000), '1000');
      expect(SiteDimensionUnit.fromStorage(null), SiteDimensionUnit.meter);
      expect(SiteDimensionUnit.fromStorage('unknown'), SiteDimensionUnit.meter);
    });
  });

  test('SiteLayoutProject lưu và đọc lại đơn vị', () {
    final now = DateTime(2026, 9, 26);
    final project = SiteLayoutProject(
      id: 'project_unit',
      name: 'Mặt bằng',
      surveyDate: now,
      siteWidthMm: 12000,
      siteLengthMm: 8000,
      dimensionUnit: SiteDimensionUnit.centimeter,
      createdAt: now,
      updatedAt: now,
    );

    expect(
      SiteLayoutProject.fromMap(project.toMap()).dimensionUnit,
      SiteDimensionUnit.centimeter,
    );
  });
}
