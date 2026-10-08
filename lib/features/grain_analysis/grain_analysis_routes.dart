import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'models/analysis_session.dart';
import 'providers/grain_analysis_provider.dart';
import 'screens/grain_analysis_home_screen.dart';
import 'screens/grain_capture_screen.dart';
import 'screens/grain_session_screen.dart';

/// Nhóm route của Phân tích mẫu AI. [GrainAnalysisProvider] chỉ sống trong
/// nhóm này (tạo khi vào module, hủy khi rời) — không đăng ký toàn app.
/// [createProvider] chỉ dùng trong test.
ShellRoute buildGrainAnalysisRoutes({
  GrainAnalysisProvider Function()? createProvider,
}) => ShellRoute(
  builder: (context, state, child) => ChangeNotifierProvider(
    create: (_) => (createProvider?.call() ?? GrainAnalysisProvider())..init(),
    child: child,
  ),
  routes: [
    GoRoute(
      path: '/grain-analysis',
      builder: (_, _) => const GrainAnalysisHomeScreen(),
    ),
    GoRoute(
      path: '/grain-analysis/new',
      builder: (_, state) => GrainCaptureScreen(
        mode: AnalysisMode.byName(state.uri.queryParameters['mode']),
      ),
    ),
    GoRoute(
      path: '/grain-analysis/session/:id',
      builder: (_, state) =>
          GrainSessionScreen(sessionId: state.pathParameters['id']!),
    ),
  ],
);
