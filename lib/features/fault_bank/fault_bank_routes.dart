import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/fault_bank_provider.dart';
import 'screens/fault_bank_home_screen.dart';
import 'screens/fault_bank_settings_screen.dart';
import 'screens/fault_record_detail_screen.dart';
import 'screens/fault_record_form_screen.dart';

/// Nhóm route của Ngân hàng lỗi. [FaultBankProvider] chỉ sống trong nhóm
/// này (tạo khi vào module, hủy khi rời) — không đăng ký toàn app.
/// [createProvider] chỉ dùng trong test (database tạm, thư mục ảnh tạm).
ShellRoute buildFaultBankRoutes({
  FaultBankProvider Function()? createProvider,
}) => ShellRoute(
  builder: (context, state, child) => ChangeNotifierProvider(
    create: (_) => (createProvider?.call() ?? FaultBankProvider())..init(),
    child: child,
  ),
  routes: [
    GoRoute(
      path: '/fault-bank',
      builder: (_, _) => const FaultBankHomeScreen(),
    ),
    GoRoute(
      path: '/fault-bank/new',
      builder: (_, _) => const FaultRecordFormScreen(),
    ),
    GoRoute(
      path: '/fault-bank/record/:id',
      builder: (_, state) =>
          FaultRecordDetailScreen(recordId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/fault-bank/record/:id/edit',
      builder: (_, state) =>
          FaultRecordFormScreen(recordId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/fault-bank/settings',
      builder: (_, _) => const FaultBankSettingsScreen(),
    ),
    GoRoute(
      path: '/fault-bank/profile',
      builder: (_, _) => const FaultProfileScreen(),
    ),
    GoRoute(
      path: '/fault-bank/machine-models',
      builder: (_, _) => const FaultMachineModelsScreen(),
    ),
  ],
);
