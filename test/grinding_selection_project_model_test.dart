import 'package:dtc_product/features/grinding_machine/models/grinding_selection_project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 24, 15, 30);

  test('Field optional không nhập giữ null, không tự thành rỗng/0', () {
    final project = GrindingSelectionProject(
      projectName: 'Dự án tối thiểu',
      createdAt: now,
      updatedAt: now,
    );

    expect(project.customerName, isNull);
    expect(project.contactName, isNull);
    expect(project.contactInfo, isNull);
    expect(project.materialId, isNull);
    expect(project.requiredCapacityKgH, isNull);
    expect(project.requiredFinenessValue, isNull);
    expect(project.requiredFinenessUnit, isNull);
    expect(project.feedSizeMm, isNull);
    expect(project.maxMotorKw, isNull);
    expect(project.application, isNull);
    expect(project.notes, isNull);
    expect(project.status, GrindingProjectStatus.draft);
  });

  test('GrindingProjectStatus.fromValue parse đúng, giá trị lạ về draft (không throw)', () {
    expect(GrindingProjectStatus.fromValue('draft'), GrindingProjectStatus.draft);
    expect(
      GrindingProjectStatus.fromValue('evaluating'),
      GrindingProjectStatus.evaluating,
    );
    expect(GrindingProjectStatus.fromValue('selected'), GrindingProjectStatus.selected);
    expect(GrindingProjectStatus.fromValue('completed'), GrindingProjectStatus.completed);
    expect(GrindingProjectStatus.fromValue('khong-ton-tai'), GrindingProjectStatus.draft);
    expect(GrindingProjectStatus.fromValue(null), GrindingProjectStatus.draft);
  });

  test('toRow/fromRow giữ đúng dữ liệu kể cả field null', () {
    final project = GrindingSelectionProject(
      id: 7,
      projectName: 'Trà xanh Bảo Lộc',
      customerName: 'Công ty ABC',
      contactName: null,
      materialId: 'TEA',
      requiredCapacityKgH: 500,
      requiredFinenessValue: 20,
      requiredFinenessUnit: 'µm',
      feedSizeMm: null,
      maxMotorKw: 75,
      status: GrindingProjectStatus.selected,
      createdAt: now,
      updatedAt: now,
    );

    final row = project.toRow();
    expect(row['id'], 7);
    expect(row['contactName'], isNull);
    expect(row['feedSizeMm'], isNull);
    expect(row['status'], 'selected');
    expect(row['createdAt'], now.toIso8601String());

    final roundTrip = GrindingSelectionProject.fromRow(row);
    expect(roundTrip.id, project.id);
    expect(roundTrip.projectName, project.projectName);
    expect(roundTrip.customerName, project.customerName);
    expect(roundTrip.contactName, isNull);
    expect(roundTrip.materialId, project.materialId);
    expect(roundTrip.requiredCapacityKgH, project.requiredCapacityKgH);
    expect(roundTrip.requiredFinenessUnit, project.requiredFinenessUnit);
    expect(roundTrip.feedSizeMm, isNull);
    expect(roundTrip.maxMotorKw, project.maxMotorKw);
    expect(roundTrip.status, GrindingProjectStatus.selected);
    expect(roundTrip.createdAt, now);
    expect(roundTrip.updatedAt, now);
  });

  test('toRow không có id khi id null (tránh ghi id=null đè AUTOINCREMENT)', () {
    final project = GrindingSelectionProject(
      projectName: 'Chưa lưu',
      createdAt: now,
      updatedAt: now,
    );
    expect(project.toRow().containsKey('id'), isFalse);
  });

  test('copyWith giữ nguyên field không truyền, xóa đúng field có cờ clear', () {
    final project = GrindingSelectionProject(
      projectName: 'Gốc',
      customerName: 'Khách cũ',
      requiredCapacityKgH: 500,
      createdAt: now,
      updatedAt: now,
    );

    final renamed = project.copyWith(projectName: 'Đổi tên');
    expect(renamed.projectName, 'Đổi tên');
    expect(renamed.customerName, 'Khách cũ');
    expect(renamed.requiredCapacityKgH, 500);

    final cleared = project.copyWith(clearCustomerName: true, clearCapacity: true);
    expect(cleared.customerName, isNull);
    expect(cleared.requiredCapacityKgH, isNull);
    expect(cleared.projectName, 'Gốc');
  });
}
