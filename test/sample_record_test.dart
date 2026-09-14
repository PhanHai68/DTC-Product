import 'dart:convert';

import 'package:dtc_product/models/sample_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tính toán form lưu mẫu', () {
    test('tính năng suất tấn/giờ theo khối lượng và thời gian', () {
      const stream = SampleStreamData(
        type: SampleStreamType.rawMaterial,
        measuredWeightKg: 25.5,
        minutes: 0,
        seconds: 6,
        sampleWeightGram: 1000,
        defectWeightsGram: [4, 6, 2, 0, 0],
      );

      expect(stream.totalSeconds, 6);
      expect(stream.capacityTonPerHour, closeTo(15.3, 0.0001));
      expect(stream.defectPercentage, closeTo(1.2, 0.0001));
      expect(stream.goodPercentage, closeTo(98.8, 0.0001));
      expect(stream.hasValidProductivity, isTrue);
      expect(stream.hasValidAnalysis, isTrue);
    });

    test('không chấp nhận tổng hạt lỗi lớn hơn tổng mẫu', () {
      const stream = SampleStreamData(
        type: SampleStreamType.accepted,
        measuredWeightKg: 10,
        seconds: 5,
        sampleWeightGram: 100,
        defectWeightsGram: [60, 50, 0, 0, 0],
      );

      expect(stream.hasValidAnalysis, isFalse);
      expect(stream.goodPercentage, 0);
    });

    test('bản nháp tuần tự hóa và khôi phục đầy đủ để lưu offline', () {
      final original = SampleRecordData(
        factoryName: 'Thành Tín',
        tagName: 'SC16PRO-JX26010333',
        machineOperator: 'Nguyễn Văn B',
        preparedBy: 'Nguyễn Văn C',
        createdAt: DateTime(2026, 6, 18, 8, 30),
        streams: const [
          SampleStreamData(
            type: SampleStreamType.rawMaterial,
            measuredWeightKg: 25.5,
            seconds: 6,
            sampleWeightGram: 1000,
            defectWeightsGram: [4, 14, 0, 0, 0],
            photoPath: '/local/raw.jpg',
          ),
        ],
        conclusion: 'Đạt',
        note: 'Mẫu chạy ổn định',
      );

      final restored = SampleRecordData.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(original.toJson()))),
      );

      expect(restored.factoryName, original.factoryName);
      expect(restored.tagName, original.tagName);
      expect(restored.createdAt, original.createdAt);
      expect(restored.streams.single.defectPercentage, closeTo(1.8, 0.0001));
      expect(restored.note, original.note);
    });

    test('hỗ trợ số thập phân dùng dấu phẩy', () {
      expect(parseSampleNumber('15,3'), 15.3);
      expect(parseSampleNumber(' 1,25 '), 1.25);
      expect(parseSampleNumber('không hợp lệ'), 0);
    });

    test('tên loại và ảnh phân loại được tùy chỉnh, lưu offline đầy đủ', () {
      const stream = SampleStreamData(
        type: SampleStreamType.rawMaterial,
        defectLabels: ['Lỗi màu', 'Lỗi hình dạng'],
        defectWeightsGram: [2, 3],
        sampleWeightGram: 100,
        categoryImages: [
          SampleCategoryImageData(
            label: 'Sản phẩm đạt',
            photoPath: '/local/good.jpg',
          ),
          SampleCategoryImageData(
            label: 'Sai màu',
            photoPath: '/local/color.jpg',
          ),
        ],
      );

      final restored = SampleStreamData.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(stream.toJson()))),
      );

      expect(restored.defectLabels, ['Lỗi màu', 'Lỗi hình dạng']);
      expect(restored.categoryImages.first.label, 'Sản phẩm đạt');
      expect(restored.hasAllCategoryPhotos, isTrue);
      expect(restored.hasValidAnalysis, isTrue);
    });

    test('ảnh phân loại có tên là bắt buộc trước khi xuất PDF', () {
      const stream = SampleStreamData(
        type: SampleStreamType.accepted,
        categoryImages: [
          SampleCategoryImageData(label: 'Hạt tốt'),
          SampleCategoryImageData(label: ''),
        ],
      );

      expect(stream.hasAllCategoryPhotos, isFalse);
    });
  });
}
