import 'package:dtc_product/features/fault_bank/utils/fault_duration.dart';
import 'package:dtc_product/features/fault_bank/utils/fault_groups.dart';
import 'package:dtc_product/features/fault_bank/utils/fault_ids.dart';
import 'package:dtc_product/features/fault_bank/utils/vietnamese_fold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaultIds', () {
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('mã bản ghi = mã kỹ sư + "-" + UUID v4', () {
      final id = FaultIds.newRecordId('KS012');
      expect(id, startsWith('KS012-'));
      expect(uuidPattern.hasMatch(id.substring('KS012-'.length)), isTrue);
    });

    test('mỗi lần tạo ra 1 mã khác nhau', () {
      final ids = {for (var i = 0; i < 1000; i++) FaultIds.newRecordId('KS1')};
      expect(ids.length, 1000);
    });

    test('từ chối mã kỹ sư không hợp lệ', () {
      expect(() => FaultIds.newRecordId('ks012'), throwsArgumentError);
      expect(() => FaultIds.newRecordId('K'), throwsArgumentError);
      expect(() => FaultIds.newRecordId('KS-012'), throwsArgumentError);
      expect(() => FaultIds.newRecordId(''), throwsArgumentError);
    });

    test('chuẩn hóa mã kỹ sư: bỏ khoảng trắng, viết hoa', () {
      expect(FaultIds.normalizeEngineerCode(' ks 012 '), 'KS012');
      expect(FaultIds.isValidEngineerCode('KS012'), isTrue);
      expect(FaultIds.isValidEngineerCode('ABCDEFGHIJK'), isFalse);
    });
  });

  group('VietnameseFold', () {
    test('bỏ dấu tiếng Việt, chữ thường', () {
      expect(VietnameseFold.fold('Động cơ quá nhiệt'), 'dong co qua nhiet');
      expect(VietnameseFold.fold('ĐÈN LED Hỏng'), 'den led hong');
      expect(
        VietnameseFold.fold('Ắc quy, ưu tiên, ỷ lại, Ổ đỡ'),
        'ac quy, uu tien, y lai, o do',
      );
    });

    test('đủ 12 nguyên âm có dấu và đ', () {
      expect(
        VietnameseFold.fold(
          'àáạảã âầấậẩẫ ăằắặẳẵ èéẹẻẽ êềếệểễ ìíịỉĩ '
          'òóọỏõ ôồốộổỗ ơờớợởỡ ùúụủũ ưừứựửữ ỳýỵỷỹ đĐ',
        ),
        'aaaaa aaaaaa aaaaaa eeeee eeeeee iiiii '
        'ooooo oooooo oooooo uuuuu uuuuuu yyyyy dd',
      );
    });

    test('chuỗi dạng tổ hợp (NFD) cũng bỏ được dấu', () {
      // "đồng cơ" viết bằng dấu kết hợp.
      final nfd =
          'đo${String.fromCharCodes([0x0302, 0x0323])}ng '
          'co${String.fromCharCode(0x031B)}';
      expect(VietnameseFold.fold(nfd), 'dong co');
    });

    test('gộp khoảng trắng, giữ ký tự khác', () {
      expect(VietnameseFold.fold('  Lỗi   E-102 \n'), 'loi e-102');
    });

    test('tách từ khóa chỉ gồm a-z0-9', () {
      expect(VietnameseFold.tokens('Động cơ (E-102)!'), [
        'dong',
        'co',
        'e',
        '102',
      ]);
      expect(VietnameseFold.tokens('  '), isEmpty);
    });

    test('khóa so sánh tên gần giống', () {
      expect(
        VietnameseFold.compactKey('SC16 Pro'),
        VietnameseFold.compactKey('sc16-PRO'),
      );
      expect(VietnameseFold.compactKey('Máy nén'), 'maynen');
    });
  });

  group('FaultGroups', () {
    test('nhóm tự thêm nằm sau nhóm cố định, KHÁC ở cuối', () {
      final options = FaultGroups.options(['băng  tải', 'CAMERA', 'ÂM THANH']);
      expect(options.take(FaultGroups.fixed.length), FaultGroups.fixed);
      expect(options.sublist(FaultGroups.fixed.length), [
        'BĂNG TẢI',
        'ÂM THANH',
        'KHÁC',
      ]);
    });
  });

  group('FaultDuration (nhập theo giờ, lưu theo phút)', () {
    test('đọc giờ, chấp nhận dấu phẩy hoặc dấu chấm', () {
      expect(FaultDuration.parseHours('1,5'), 90);
      expect(FaultDuration.parseHours('1.5'), 90);
      expect(FaultDuration.parseHours('2'), 120);
      expect(FaultDuration.parseHours('0,75'), 45);
      expect(FaultDuration.parseHours(''), isNull);
      expect(FaultDuration.parseHours('0'), isNull);
      expect(FaultDuration.parseHours(','), isNull);
    });

    test('hiển thị giờ gọn, dấu phẩy thập phân', () {
      expect(FaultDuration.label(90), '1,5 giờ');
      expect(FaultDuration.label(120), '2 giờ');
      expect(FaultDuration.label(45), '0,75 giờ');
      expect(FaultDuration.label(20), '0,33 giờ');
      expect(FaultDuration.label(600), '10 giờ');
      expect(FaultDuration.hours(90), 1.5);
    });
  });
}
