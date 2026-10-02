import 'package:dtc_product/features/factory_location/data/factory_location_database.dart';
import 'package:dtc_product/features/factory_location/models/factory_location.dart';
import 'package:dtc_product/features/factory_location/providers/factory_location_provider.dart';
import 'package:dtc_product/features/factory_location/repositories/factory_location_repository.dart';
import 'package:dtc_product/features/factory_location/screens/factory_location_form_screen.dart';
import 'package:dtc_product/features/factory_location/services/location_service.dart';
import 'package:dtc_product/features/factory_location/utils/maps_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

FactoryLocation _location({
  int? id,
  String name = 'Nhà máy gạo Tân Long',
  double? accuracy = 8.4,
  String note = 'Cổng số 2, gửi xe bên trái',
}) => FactoryLocation(
  id: id,
  name: name,
  latitude: 10.7769,
  longitude: 106.7009,
  accuracy: accuracy,
  note: note,
  createdAt: DateTime(2026, 10, 1, 8),
  updatedAt: DateTime(2026, 10, 1, 9),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FactoryLocation model', () {
    test('toMap/fromMap giữ nguyên dữ liệu', () {
      final original = _location(id: 3);
      final restored = FactoryLocation.fromMap(original.toMap());
      expect(restored.id, 3);
      expect(restored.name, original.name);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.accuracy, original.accuracy);
      expect(restored.note, original.note);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('fromMap chấp nhận accuracy null và tọa độ kiểu int', () {
      final restored = FactoryLocation.fromMap({
        'id': 1,
        'name': 'A',
        'latitude': 10,
        'longitude': 106,
        'accuracy': null,
        'note': null,
        'createdAt': '2026-10-01T08:00:00.000',
        'updatedAt': '2026-10-01T08:00:00.000',
      });
      expect(restored.latitude, 10.0);
      expect(restored.accuracy, isNull);
      expect(restored.note, '');
    });

    test('toMap không chứa id khi tạo mới', () {
      expect(_location().toMap().containsKey('id'), isFalse);
    });

    test('copyWith có thể xóa accuracy', () {
      final updated = _location().copyWith(clearAccuracy: true, note: 'Mới');
      expect(updated.accuracy, isNull);
      expect(updated.note, 'Mới');
      expect(updated.name, _location().name);
    });

    test('mapsUrl và nội dung chia sẻ được tạo từ tọa độ', () {
      final item = _location();
      expect(
        item.mapsUrl,
        'https://www.google.com/maps/search/?api=1&query=10.776900,106.700900',
      );
      expect(
        item.shareText,
        'Nhà máy gạo Tân Long\n'
        'Ghi chú: Cổng số 2, gửi xe bên trái\n'
        'https://www.google.com/maps/search/?api=1&query=10.776900,106.700900',
      );
      expect(_location(note: '  ').shareText.contains('Ghi chú'), isFalse);
    });
  });

  group('Tạo và đọc link Google Maps', () {
    test('buildMapsUrl làm tròn 6 chữ số và hỗ trợ tọa độ âm', () {
      expect(
        buildMapsUrl(-33.8688197, 151.2092958),
        'https://www.google.com/maps/search/?api=1&query=-33.868820,151.209296',
      );
    });

    test('đọc lại được link do app tạo', () {
      final coords = parseMapsCoordinates(buildMapsUrl(21.028511, 105.804817));
      expect(coords?.latitude, closeTo(21.028511, 1e-9));
      expect(coords?.longitude, closeTo(105.804817, 1e-9));
    });

    final cases = <String, (double, double)>{
      '10.7769, 106.7009': (10.7769, 106.7009),
      'https://maps.google.com/?q=10.7769,106.7009': (10.7769, 106.7009),
      'https://www.google.com/maps?ll=21.0285,105.8048&z=15': (
        21.0285,
        105.8048,
      ),
      'https://www.google.com/maps/@10.8231,106.6297,15z': (10.8231, 106.6297),
      'https://www.google.com/maps/place/Nh%C3%A0+m%C3%A1y/@10.80,106.60,17z/data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d10.8123456!4d106.6123456':
          (10.8123456, 106.6123456),
      'https://www.google.com/maps/dir/?api=1&destination=16.0544,108.2022': (
        16.0544,
        108.2022,
      ),
    };
    cases.forEach((input, expected) {
      test('đọc tọa độ từ: $input', () {
        final coords = parseMapsCoordinates(input);
        expect(coords, isNotNull);
        expect(coords!.latitude, closeTo(expected.$1, 1e-9));
        expect(coords.longitude, closeTo(expected.$2, 1e-9));
      });
    });

    test('trả về null khi link không có tọa độ hoặc tọa độ sai', () {
      expect(parseMapsCoordinates(''), isNull);
      expect(
        parseMapsCoordinates('https://www.google.com/maps?q=Nha+may'),
        isNull,
      );
      expect(parseMapsCoordinates('95.0, 106.0'), isNull);
      expect(parseMapsCoordinates('10.0, 190.0'), isNull);
      expect(parseMapsCoordinates('không phải link'), isNull);
    });

    test('nhận diện link rút gọn', () {
      expect(isShortMapsLink('https://maps.app.goo.gl/AbCdEf123'), isTrue);
      expect(isShortMapsLink('https://goo.gl/maps/AbCdEf'), isTrue);
      expect(
        isShortMapsLink('https://www.google.com/maps/@10,106,15z'),
        isFalse,
      );
    });

    test('normalizeForSearch bỏ dấu tiếng Việt và khoảng trắng thừa', () {
      expect(normalizeForSearch('  Nhà  Máy ĐƯỜNG  '), 'nha may duong');
    });
  });

  group('Repository và provider', () {
    late Database database;
    late FactoryLocationRepository repository;
    late FactoryLocationProvider provider;

    setUp(() async {
      sqfliteFfiInit();
      database = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      final wrapper = FactoryLocationDatabase.forTesting(database);
      await wrapper.createSchemaForTesting(database);
      repository = FactoryLocationRepository(database: wrapper);
      provider = FactoryLocationProvider(repository: repository);
    });

    tearDown(() async => database.close());

    test('thêm, sửa, xóa nhà máy', () async {
      await provider.save(_location());
      expect(provider.items, hasLength(1));
      final saved = provider.items.single;
      expect(saved.id, isNotNull);

      await provider.save(saved.copyWith(note: 'Cổng số 3'));
      expect(provider.items.single.note, 'Cổng số 3');

      await provider.delete(saved.id!);
      expect(provider.items, isEmpty);
    });

    test('tìm kiếm không phân biệt dấu và hoa thường', () async {
      await provider.save(_location(name: 'Nhà máy gạo Tân Long'));
      await provider.save(_location(name: 'Kho cà phê Đắk Lắk'));
      provider.setQuery('dak lak');
      expect(provider.filtered.map((e) => e.name), ['Kho cà phê Đắk Lắk']);
      provider.setQuery('');
      expect(provider.filtered, hasLength(2));
    });

    test('cảnh báo trùng tên, bỏ qua chính bản ghi đang sửa', () async {
      await provider.save(_location(name: 'Nhà máy A'));
      final id = provider.items.single.id;
      expect(provider.hasDuplicateName('  nhà MÁY a '), isTrue);
      expect(provider.hasDuplicateName('Nhà máy A', excludeId: id), isFalse);
      expect(provider.hasDuplicateName('Nhà máy B'), isFalse);
    });
  });

  group('Màn hình thêm nhà máy', () {
    Future<void> pumpForm(WidgetTester tester, LocationService service) =>
        tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => FactoryLocationProvider(),
            child: MaterialApp(
              home: FactoryLocationFormScreen(locationService: service),
            ),
          ),
        );

    testWidgets('định vị thành công hiển thị link và độ chính xác', (
      tester,
    ) async {
      await pumpForm(tester, const _FakeLocationService());
      await tester.tap(find.byKey(const Key('factory_location_locate')));
      await tester.pumpAndSettle();

      expect(find.text('±8 m'), findsOneWidget);
      expect(
        find.text(
          'https://www.google.com/maps/search/?api=1&query=10.776900,106.700900',
        ),
        findsOneWidget,
      );
      expect(find.text('Định vị lại'), findsOneWidget);
    });

    testWidgets(
      'quyền bị từ chối vĩnh viễn hiển thị giải thích và nút Cài đặt',
      (tester) async {
        await pumpForm(
          tester,
          const _FakeLocationService(
            failure: LocationFailure(
              LocationFailureType.permissionDeniedForever,
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('factory_location_locate')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('factory_location_error')), findsOneWidget);
        expect(
          find.textContaining('Quyền vị trí đã bị từ chối'),
          findsOneWidget,
        );
        expect(find.text('Mở Cài đặt'), findsOneWidget);
        expect(find.text('Thử lại'), findsOneWidget);
      },
    );

    testWidgets('hết thời gian chờ cho phép thử lại, không có nút Cài đặt', (
      tester,
    ) async {
      await pumpForm(
        tester,
        const _FakeLocationService(
          failure: LocationFailure(LocationFailureType.timeout),
        ),
      );
      await tester.tap(find.byKey(const Key('factory_location_locate')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hết thời gian chờ'), findsOneWidget);
      expect(find.text('Mở Cài đặt'), findsNothing);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('dán link đầy đủ lấy được tọa độ', (tester) async {
      await pumpForm(tester, const _FakeLocationService());
      await tester.enterText(
        find.byKey(const Key('factory_location_link')),
        'https://www.google.com/maps/@21.0285,105.8048,15z',
      );
      await tester.tap(find.text('Lấy tọa độ từ link'));
      await tester.pumpAndSettle();

      expect(find.text('21.028500, 105.804800'), findsOneWidget);
      expect(find.text('Từ link'), findsOneWidget);
    });
  });
}

class _FakeLocationService extends LocationService {
  const _FakeLocationService({this.failure});
  final LocationFailure? failure;

  @override
  Future<Position> getCurrentPosition() async {
    if (failure != null) throw failure!;
    return Position(
      latitude: 10.7769,
      longitude: 106.7009,
      timestamp: DateTime(2026, 10, 1),
      accuracy: 8.2,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  @override
  Future<bool> openSettingsFor(LocationFailure failure) async => true;
}
