import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/technical_dictionary_provider.dart';
import 'screens/technical_dictionary_screen.dart';
import 'screens/technical_term_detail_screen.dart';

/// Nhóm route của Từ điển chuyên ngành. [TechnicalDictionaryProvider] chỉ
/// sống trong nhóm này (nạp từ điển khi vào, giải phóng khi rời).
/// [createProvider] chỉ dùng trong test.
ShellRoute buildTechnicalDictionaryRoutes({
  TechnicalDictionaryProvider Function()? createProvider,
}) => ShellRoute(
  builder: (context, state, child) => ChangeNotifierProvider(
    create: (_) =>
        (createProvider?.call() ?? TechnicalDictionaryProvider())..init(),
    child: child,
  ),
  routes: [
    GoRoute(
      path: '/technical-dictionary',
      builder: (_, _) => const TechnicalDictionaryScreen(),
    ),
    GoRoute(
      path: '/technical-dictionary/term/:id',
      builder: (_, state) => TechnicalTermDetailScreen(
        termId: int.tryParse(state.pathParameters['id']!) ?? -1,
      ),
    ),
  ],
);
