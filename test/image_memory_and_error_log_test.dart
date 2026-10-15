import 'dart:typed_data';

import 'package:dtc_product/core/errors/app_error_log.dart';
import 'package:dtc_product/widgets/thumbnail_image_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('thumbnailImageProvider', () {
    final source = MemoryImage(Uint8List(0));

    test('ô thu nhỏ (cover) giải mã vừa ô, không theo ảnh gốc', () {
      final provider = thumbnailImageProvider(
        source,
        constraints: BoxConstraints.tight(const Size(120, 90)),
        devicePixelRatio: 3,
        fit: BoxFit.cover,
      );
      expect(provider, isA<ResizeImage>());
      final resized = provider as ResizeImage;
      expect(resized.width, 720); // 120 × 3 × 2
      expect(resized.height, 720);
      expect(resized.policy, ResizeImagePolicy.fit);
      expect(resized.allowUpscaling, isFalse);
    });

    test('xem đầy đủ (contain) giữ ảnh gốc để phóng to không mờ', () {
      final provider = thumbnailImageProvider(
        source,
        constraints: BoxConstraints.tight(const Size(400, 800)),
        devicePixelRatio: 3,
        fit: BoxFit.contain,
      );
      expect(identical(provider, source), isTrue);
    });

    test('không biết kích thước ô thì giữ ảnh gốc', () {
      final provider = thumbnailImageProvider(
        source,
        constraints: const BoxConstraints(),
        devicePixelRatio: 3,
        fit: BoxFit.cover,
      );
      expect(identical(provider, source), isTrue);
    });
  });

  group('AppErrorLog', () {
    final log = AppErrorLog.instance;
    tearDown(log.clear);

    test('giữ tối đa 50 lỗi gần nhất, mới nhất trước', () {
      for (var i = 0; i < AppErrorLog.maxEntries + 5; i++) {
        log.record(StateError('lỗi $i'), StackTrace.current, source: 'async');
      }
      expect(log.entries, hasLength(AppErrorLog.maxEntries));
      expect(log.entries.first.message, contains('lỗi 54'));
      expect(log.entries.last.message, contains('lỗi 5'));
    });

    test('nội dung chia sẻ có phiên bản và từng lỗi', () {
      log.record(StateError('không lưu được'), null, source: 'flutter');
      final text = log.exportText(appVersion: '1.0.20 (build 21)');
      expect(text, contains('phiên bản 1.0.20 (build 21)'));
      expect(text, contains('(flutter)'));
      expect(text, contains('không lưu được'));
    });
  });
}
