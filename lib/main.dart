import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'routes/app_routes.dart';
import 'providers/electricity_bill_provider.dart';
import 'providers/processing_profit_provider.dart';
import 'providers/self_business_provider.dart';
import 'providers/payback_period_provider.dart';
import 'providers/color_sorter_provider.dart';
import 'providers/acomp_spec_provider.dart';
import 'providers/acomp_suitable_provider.dart';
import 'providers/acomp_tank_provider.dart';
import 'providers/packing_provider.dart';
import 'providers/machine_selector_provider.dart';
import 'providers/compare_provider.dart';
import 'providers/maintenance_provider.dart';

void main() {
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ElectricityBillProvider()),
        ChangeNotifierProvider(create: (_) => ProcessingProfitProvider()),
        ChangeNotifierProvider(create: (_) => SelfBusinessProvider()),
        ChangeNotifierProvider(create: (_) => PaybackPeriodProvider()),
        ChangeNotifierProvider(create: (_) => ColorSorterProvider()),
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
      ],
      child: MaterialApp.router(
        title: 'DTC Product',
        locale: const Locale('vi', 'VN'),
        supportedLocales: const [Locale('vi', 'VN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF007F7A),
            primary: const Color(0xFF087F78),
            secondary: const Color(0xFF176B87),
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFFF3F7F9),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 1,
            surfaceTintColor: Colors.transparent,
            titleTextStyle: TextStyle(
              color: Color(0xFF102F46),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFDCE7EB)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDCE7EB)),
            ),
          ),
        ),
        routerConfig: appRouter,
      ),
    );
  }
}
