import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'routes/app_routes.dart';
import 'providers/electricity_bill_provider.dart';
import 'providers/processing_profit_provider.dart';
import 'providers/self_business_provider.dart';
import 'providers/payback_period_provider.dart';
import 'providers/color_sorter_provider.dart';
import 'providers/tea_color_sorter_provider.dart';
import 'providers/paddy_color_sorter_provider.dart';
import 'providers/acomp_spec_provider.dart';
import 'providers/acomp_suitable_provider.dart';
import 'providers/acomp_tank_provider.dart';
import 'providers/packing_provider.dart';
import 'providers/machine_selector_provider.dart';
import 'providers/compare_provider.dart';
import 'providers/maintenance_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/storage_provider.dart';
import 'providers/daily_goals_provider.dart';
import 'services/note_notification_service.dart';

// Projects Module
import 'features/projects/providers/project_provider.dart';
import 'features/projects/repositories/local_project_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Không chờ init() xong mới vẽ khung hình đầu tiên — dịch vụ thông báo tự
  // khởi tạo song song trong lúc UI hiển thị; schedule()/cancel()/
  // requestPermission() đã tự đảm bảo init() hoàn tất trước khi dùng.
  unawaited(
    NoteNotificationService.init().catchError((Object error) {
      debugPrint('Không thể khởi tạo dịch vụ thông báo: $error');
    }),
  );

  FlutterError.onError = FlutterError.presentError;
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              kDebugMode
                  ? '${details.exceptionAsString()}\n\n${details.stack?.toString() ?? ''}'
                  : 'Đã xảy ra lỗi khi hiển thị nội dung. Vui lòng quay lại và thử lại.',
              style: TextStyle(
                color: kDebugMode ? Colors.red : const Color(0xFF102F46),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  };
  runApp(MyApp(settingsProvider: SettingsProvider(prefs)));
}

/// Xây dựng ThemeData dùng chung cho cả bản sáng và tối từ cùng một cấu trúc,
/// tránh lệch nhau khi chỉnh sửa về sau.
ThemeData _buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF007F7A),
    brightness: brightness,
    primary: isDark ? const Color(0xFF4FD1C7) : const Color(0xFF087F78),
    secondary: isDark ? const Color(0xFF8FC4DA) : const Color(0xFF176B87),
    surface: isDark ? const Color(0xFF162229) : Colors.white,
  );
  final scaffoldBackground = isDark
      ? const Color(0xFF0D1418)
      : const Color(0xFFF3F7F9);
  final headingColor = isDark
      ? const Color(0xFFECF3F6)
      : const Color(0xFF102F46);
  final bodyColor = isDark ? const Color(0xFFB7C4CB) : const Color(0xFF29495E);
  final borderColor = isDark
      ? const Color(0xFF2B3B43)
      : const Color(0xFFDCE7EB);
  final surfaceColor = isDark ? const Color(0xFF162229) : Colors.white;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackground,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    textTheme: TextTheme(
      headlineSmall: TextStyle(
        color: headingColor,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(color: headingColor, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(
        color: headingColor,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: TextStyle(color: bodyColor, height: 1.35),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      backgroundColor: surfaceColor,
      titleTextStyle: TextStyle(
        color: headingColor,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.settingsProvider});

  final SettingsProvider settingsProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => ElectricityBillProvider()),
        ChangeNotifierProvider(create: (_) => ProcessingProfitProvider()),
        ChangeNotifierProvider(create: (_) => SelfBusinessProvider()),
        ChangeNotifierProvider(create: (_) => PaybackPeriodProvider()),
        ChangeNotifierProvider(create: (_) => ColorSorterProvider()),
        ChangeNotifierProvider(create: (_) => TeaColorSorterProvider()),
        ChangeNotifierProvider(create: (_) => PaddyColorSorterProvider()),
        ChangeNotifierProvider(create: (_) => AcompSpecProvider()),
        ChangeNotifierProvider(create: (_) => AcompSuitableProvider()),
        ChangeNotifierProvider(create: (_) => AcompTankProvider()),
        // Packing module providers
        ChangeNotifierProvider(create: (_) => PackingProvider()),
        ChangeNotifierProvider(create: (_) => MachineSelectorProvider()),
        ChangeNotifierProvider(create: (_) => CompareProvider()),
        ChangeNotifierProvider(
          create: (_) => MaintenanceProvider()..loadRecords(),
        ),
        ChangeNotifierProvider(
          create: (_) => NotesProvider()..loadNotes(),
        ),
        ChangeNotifierProvider(
          create: (_) => ProjectProvider(LocalProjectRepository()),
        ),
        ChangeNotifierProvider(create: (_) => StorageProvider()),
        ChangeNotifierProvider(create: (_) => DailyGoalsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp.router(
            title: 'DTC Product',
            locale: const Locale('vi', 'VN'),
            supportedLocales: const [Locale('vi', 'VN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: _buildAppTheme(Brightness.light),
            darkTheme: _buildAppTheme(Brightness.dark),
            themeMode: settings.themeMode,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(settings.textScale.scale),
                ),
                child: child!,
              );
            },
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
