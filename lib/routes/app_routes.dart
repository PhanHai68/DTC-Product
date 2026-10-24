import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home_screen.dart';
import '../screens/global_search_screen.dart';
import '../screens/extensions_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/error_log_screen.dart';
import '../screens/home_personalization_screen.dart';
import '../screens/notes/notes_list_screen.dart';
import '../screens/notes/note_edit_screen.dart';
import '../screens/daily_goals/daily_goals_screen.dart';
import '../screens/daily_goals/daily_goal_form_screen.dart';
import '../screens/daily_goals/daily_goals_calendar_screen.dart';
import '../models/daily_goal.dart';
import '../screens/storage/storage_overview_screen.dart';
import '../screens/storage/stored_pdf_viewer_screen.dart';
import '../screens/storage/stored_image_viewer_screen.dart';
import '../screens/storage/stored_model_viewer_screen.dart';
import '../models/stored_file.dart';
import '../screens/sample_record/sample_record_screen.dart';
import '../features/drive_docs/models/drive_item.dart';
import '../features/drive_docs/screens/drive_docs_screen.dart';
import '../features/drive_docs/screens/drive_media_viewer_screens.dart';
import '../features/drive_docs/screens/drive_pdf_viewer_screen.dart';
import '../features/maintenance_report/screens/maintenance_report_list_screen.dart';
import '../features/maintenance_report/screens/maintenance_report_form_screen.dart';
import '../features/maintenance_report/screens/maintenance_report_workspace_screen.dart';
import '../features/maintenance_report/models/maintenance_report.dart';
import '../features/grinding_machine/screens/grinding_machine_home_screen.dart';
import '../features/grinding_machine/screens/grinding_menu_screen.dart';
import '../features/equipment_catalog/equipment_catalog_config.dart';
import '../features/equipment_catalog/equipment_routes.dart';
import '../features/grinding_machine/screens/grinding_machine_search_screen.dart';
import '../features/grinding_machine/screens/grinding_series_machines_screen.dart';
import '../features/grinding_machine/screens/grinding_machine_detail_screen.dart';
import '../features/grinding_machine/screens/grinding_asp_3d_screen.dart';
import '../features/grinding_machine/screens/grinding_machine_filter_screen.dart';
import '../features/grinding_machine/screens/grinding_machine_compare_screen.dart';
import '../features/grinding_machine/screens/grinding_machine_selection_screen.dart';
import '../features/grinding_machine/screens/grinding_machine_recommendation_screen.dart';
import '../features/grinding_machine/screens/grinding_machine_list_screen.dart';
import '../features/grinding_machine/screens/grinding_machine_selector_screen.dart';
import '../features/grinding_machine/screens/grinding_selection_project_list_screen.dart';
import '../features/grinding_machine/screens/grinding_selection_project_detail_screen.dart';
import '../features/grinding_machine/screens/grinding_proposal_editor_screen.dart';
import '../features/grinding_machine/models/grinding_selection_request.dart';
import '../features/grinding_machine/models/grinding_selection_project.dart';
import '../features/fault_bank/fault_bank_routes.dart';
import '../features/technical_dictionary/technical_dictionary_routes.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/services/auth_service.dart';
import '../screens/productivity/productivity_calc_screen.dart';
import '../screens/technical_converter/technical_converter_screen.dart';
import '../screens/color_sorter_categories_screen.dart';
import '../screens/color_sorter_menu_screen.dart';
import '../screens/color_sorter/color_sorter_screen.dart';
import '../screens/color_sorter/color_sorter_3d_screen.dart';
import '../screens/paddy_color_sorter/paddy_color_sorter_menu_screen.dart';
import '../screens/paddy_color_sorter/paddy_color_sorter_screen.dart';
import '../screens/tea_color_sorter_menu_screen.dart';
import '../screens/tea_color_sorter/tea_color_sorter_screen.dart';
import '../screens/tea_color_sorter/tea_aux_equip_screen.dart';
import '../screens/mineral_color_sorter_menu_screen.dart';
import '../screens/mineral_color_sorter/mineral_color_sorter_screen.dart';
import '../screens/mineral_color_sorter/mineral_sorter_selector_screen.dart';
import '../screens/agro_color_sorter_menu_screen.dart';
import '../screens/agro_color_sorter/agro_color_sorter_screen.dart';
import '../screens/aux_equip/aux_equip_screen.dart';
import '../screens/paddy_color_sorter/paddy_aux_equip_screen.dart';
import '../screens/payback_analysis_menu_screen.dart';
import '../screens/payback/power_consumption_screen.dart';
import '../screens/payback/electricity_bill_screen.dart';
import '../screens/payback/processing_profit_screen.dart';
import '../screens/payback/payback_period_screen.dart';
import '../screens/payback/self_business_screen.dart';
import '../screens/payback/payback_chart_screen.dart';
import '../screens/acomp/acomp_menu_screen.dart';
import '../screens/acomp/acomp_tech_category_screen.dart';
import '../screens/acomp/acomp_tech_detail_screen.dart';
import '../screens/acomp/acomp_suitable_screen.dart';
import '../screens/acomp/acomp_tank_screen.dart';
import '../screens/acomp/acomp_mccb_cable_screen.dart';
import '../screens/acomp/acomp_pipe_screen.dart';
import '../screens/acomp/acomp_tank_fill_time_screen.dart';
import '../screens/acomp/acomp_vsd_compare_screen.dart';
import '../screens/acomp/acomp_troubleshooting_menu_screen.dart';
import '../screens/acomp/acomp_common_errors_screen.dart';
import '../screens/color_sorter_errors/color_sorter_errors_screen.dart';
import '../screens/acomp/acomp_ds8011_settings_screen.dart';
// Packing module screens
import '../screens/packing/packing_menu_screen.dart';
import '../screens/packing/packing_search_screen.dart';
import '../screens/packing/machine_detail_screen.dart';
import '../screens/packing/machine_selector_screen.dart';

// Projects Module
import '../features/projects/pages/projects_page.dart';
import '../features/projects/pages/project_detail_page.dart';
import '../features/projects/pages/project_create_page.dart';
import '../features/projects/pages/project_machine_page.dart';
import '../features/projects/pages/project_stage_page.dart';
import '../features/projects/pages/project_schedule_page.dart';
import '../screens/packing/machine_catalog_screen.dart';
import '../screens/packing/compare_screen.dart';
import '../screens/extensions/maintenance_list_screen.dart';
import '../screens/extensions/maintenance_form_screen.dart';
import '../models/maintenance_record.dart';
import '../features/site_layout/screens/site_layout_home_screen.dart';
import '../features/site_layout/screens/site_project_form_screen.dart';
import '../features/site_layout/screens/site_layout_editor_screen.dart';
import '../features/site_layout/screens/site_photo_gallery_screen.dart';
import '../features/site_layout/screens/site_layout_export_screen.dart';
import '../features/site_layout/screens/site_elevation_screen.dart';
import '../features/factory_location/models/factory_location.dart';
import '../features/factory_location/screens/factory_location_list_screen.dart';
import '../features/factory_location/screens/factory_location_form_screen.dart';
import '../data/product_data.dart' show ColorSorterLine;

/// `?line=paddy|brownRice|tea` → luồng hoàn vốn của máy lúa giống/lúa và gạo
/// lứt/trà; mặc định máy gạo.
ColorSorterLine _colorSorterLine(GoRouterState state) =>
    ColorSorterLine.values.asNameMap()[state.uri.queryParameters['line']] ??
    ColorSorterLine.rice;

/// `?line=brownRice` → dòng Lúa và Gạo lứt; mặc định Lúa giống (màn dòng SF
/// Pro dùng chung).
ColorSorterLine _sfLine(GoRouterState state) =>
    state.uri.queryParameters['line'] == ColorSorterLine.brownRice.name
    ? ColorSorterLine.brownRice
    : ColorSorterLine.paddy;

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  // Chưa đăng nhập thì mọi đường dẫn đều về /login; đăng nhập xong về trang chủ.
  refreshListenable: AuthService.instance,
  redirect: (context, state) {
    final signedIn = AuthService.instance.isSignedIn;
    final atLogin = state.matchedLocation == '/login';
    if (!signedIn) return atLogin ? null : '/login';
    return atLogin ? '/' : null;
  },
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Không tìm thấy nội dung')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              'Đường dẫn không hợp lệ hoặc nội dung không còn tồn tại.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home_rounded),
              label: const Text('Về trang chủ'),
            ),
          ],
        ),
      ),
    ),
  ),
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/search',
      builder: (context, state) => const GlobalSearchScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/home_personalization',
      builder: (context, state) => const HomePersonalizationScreen(),
    ),
    GoRoute(
      path: '/settings/error_log',
      builder: (context, state) => const ErrorLogScreen(),
    ),
    GoRoute(
      path: '/notes',
      builder: (context, state) => const NotesListScreen(),
    ),
    GoRoute(
      path: '/notes/edit',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final noteId = extra?['noteId'] as int?;
        return NoteEditScreen(noteId: noteId);
      },
    ),
    GoRoute(
      path: '/daily_goals',
      builder: (context, state) => const DailyGoalsScreen(),
    ),
    GoRoute(
      path: '/daily_goals/day',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final date = extra?['date'] as DateTime?;
        return DailyGoalsScreen(date: date);
      },
    ),
    GoRoute(
      path: '/daily_goals/calendar',
      builder: (context, state) => const DailyGoalsCalendarScreen(),
    ),
    GoRoute(
      path: '/daily_goals/form',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final goal = extra?['goal'] as DailyGoal?;
        return DailyGoalFormScreen(goal: goal);
      },
    ),
    GoRoute(
      path: '/storage',
      builder: (context, state) => const StorageOverviewScreen(),
    ),
    GoRoute(
      path: '/storage/pdf',
      builder: (context, state) => switch (state.extra) {
        final StoredFile file => StoredPdfViewerScreen(file: file),
        // Mất extra (tải lại trang web, hệ điều hành khôi phục app): về danh sách.
        _ => const StorageOverviewScreen(),
      },
    ),
    GoRoute(
      path: '/storage/image',
      builder: (context, state) => switch (state.extra) {
        final StoredFile file => StoredImageViewerScreen(file: file),
        _ => const StorageOverviewScreen(),
      },
    ),
    GoRoute(
      path: '/storage/model',
      builder: (context, state) => switch (state.extra) {
        final StoredFile file => StoredModelViewerScreen(file: file),
        _ => const StorageOverviewScreen(),
      },
    ),
    GoRoute(
      path: '/extensions',
      builder: (context, state) => const ExtensionsScreen(),
    ),
    GoRoute(
      path: '/documents',
      builder: (context, state) => const DriveDocsScreen(),
    ),
    GoRoute(
      path: '/documents/folder',
      builder: (context, state) => DriveDocsScreen(
        folderId: state.uri.queryParameters['id'],
        title: state.uri.queryParameters['title'],
      ),
    ),
    GoRoute(
      path: '/documents/image',
      builder: (context, state) {
        final item = state.extra as DriveItem?;
        if (item == null) return const DriveDocsScreen();
        return DriveImageViewerScreen(item: item);
      },
    ),
    GoRoute(
      path: '/documents/video',
      builder: (context, state) {
        final item = state.extra as DriveItem?;
        if (item == null) return const DriveDocsScreen();
        return DriveVideoPlayerScreen(item: item);
      },
    ),
    GoRoute(
      path: '/documents/view',
      builder: (context, state) {
        // Mở từ thư viện: extra là DriveItem. Mở từ màn hình khác (hoặc tải
        // lại trang web, mất extra): tìm theo ?name=<tên file>.
        final item = state.extra as DriveItem?;
        final query = state.uri.queryParameters;
        final fileName = query['name'];
        if (item == null && fileName == null) {
          return const DriveDocsScreen();
        }
        return DrivePdfViewerScreen(
          item: item,
          fileName: fileName,
          title: query['title'] ?? item?.name ?? fileName!,
          initialPage: int.tryParse(query['page'] ?? '') ?? 1,
        );
      },
    ),
    GoRoute(
      path: '/factory-locations',
      builder: (context, state) => const FactoryLocationListScreen(),
    ),
    // Ngân hàng lỗi (/fault-bank/...) — provider riêng của module.
    buildFaultBankRoutes(),
    // Từ điển chuyên ngành (/technical-dictionary/...) — provider riêng.
    buildTechnicalDictionaryRoutes(),
    GoRoute(
      path: '/factory-locations/form',
      builder: (context, state) => FactoryLocationFormScreen(
        location: state.extra is FactoryLocation
            ? state.extra as FactoryLocation
            : null,
      ),
    ),
    GoRoute(
      path: '/site-layout',
      builder: (context, state) => const SiteLayoutHomeScreen(),
    ),
    GoRoute(
      path: '/site-layout/project/new',
      builder: (context, state) => const SiteProjectFormScreen(),
    ),
    GoRoute(
      path: '/site-layout/project/:projectId/photos',
      builder: (context, state) =>
          SitePhotoGalleryScreen(projectId: state.pathParameters['projectId']!),
    ),
    GoRoute(
      path: '/site-layout/project/:projectId/export',
      builder: (context, state) =>
          SiteLayoutExportScreen(projectId: state.pathParameters['projectId']!),
    ),
    GoRoute(
      path: '/site-layout/project/:projectId/layout/:layoutId/elevation/:machineId',
      builder: (context, state) =>
          SiteElevationScreen(machineId: state.pathParameters['machineId']!),
    ),
    GoRoute(
      path: '/site-layout/project/:projectId',
      builder: (context, state) =>
          SiteLayoutEditorScreen(projectId: state.pathParameters['projectId']!),
    ),
    GoRoute(
      path: '/sample_record',
      builder: (context, state) => const SampleRecordScreen(),
    ),
    GoRoute(
      path: '/maintenance_report',
      builder: (context, state) => const MaintenanceReportListScreen(),
    ),
    GoRoute(
      path: '/maintenance_report/new',
      builder: (context, state) => const MaintenanceReportFormScreen(),
    ),
    GoRoute(
      path: '/maintenance_report/:id/edit',
      builder: (context, state) => MaintenanceReportFormScreen(
        report: state.extra as MaintenanceReport?,
      ),
    ),
    GoRoute(
      path: '/maintenance_report/:id',
      builder: (context, state) => MaintenanceReportWorkspaceScreen(
        reportId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/grinding_menu',
      builder: (context, state) => const GrindingMenuScreen(),
    ),
    for (final config in EquipmentCatalogs.all) ...equipmentRoutes(config),
    GoRoute(
      path: '/grinding_machine',
      builder: (context, state) => const GrindingMachineHomeScreen(),
    ),
    GoRoute(
      path: '/grinding_machine/search',
      builder: (context, state) => const GrindingMachineSearchScreen(),
    ),
    GoRoute(
      path: '/grinding_machine/series',
      builder: (context, state) {
        final code =
            state.uri.queryParameters['code'] ??
            (state.extra is String ? state.extra as String : null);
        if (code == null) return const GrindingMachineHomeScreen();
        return GrindingSeriesMachinesScreen(seriesCode: code);
      },
    ),
    GoRoute(
      path: '/grinding_machine/detail/:machineId',
      builder: (context, state) => GrindingMachineDetailScreen(
        machineId: state.pathParameters['machineId']!,
      ),
    ),
    GoRoute(
      path: '/grinding_machine/asp-3d',
      builder: (context, state) => const GrindingAsp3dScreen(),
    ),
    GoRoute(
      path: '/grinding_machine/filter',
      builder: (context, state) => const GrindingMachineFilterScreen(),
    ),
    GoRoute(
      path: '/grinding_machine/compare',
      // Phase 7 mục 10: extra có thể là List<String> machineId để preset
      // sẵn slot (VD từ Selector/Project Detail) — không truyền vẫn hoạt
      // động y hệt trước (route/test cũ không đổi).
      builder: (context, state) => GrindingMachineCompareScreen(
        initialMachineIds: state.extra is List<String>
            ? state.extra as List<String>
            : null,
      ),
    ),
    GoRoute(
      path: '/grinding_machine/list',
      builder: (context, state) => const GrindingMachineListScreen(),
    ),
    GoRoute(
      path: '/grinding_machine/selector',
      // Phase 7 mục 8: extra là int (projectId) -> mở ở chế độ sửa hồ sơ đã
      // lưu; không truyền -> tạo hồ sơ mới (mặc định, y hệt Phase 6).
      builder: (context, state) => GrindingMachineSelectorScreen(
        existingProjectId: state.extra is int ? state.extra as int : null,
      ),
    ),
    GoRoute(
      path: '/grinding_machine/projects',
      // Phase 10 mục 21: extra có thể là GrindingProjectStatus để preset
      // filter khi mở từ Dashboard — không truyền vẫn hoạt động y hệt trước
      // (hiện toàn bộ, route/test cũ không đổi).
      builder: (context, state) => GrindingSelectionProjectListScreen(
        initialStatusFilter: state.extra is GrindingProjectStatus
            ? state.extra as GrindingProjectStatus
            : null,
      ),
    ),
    GoRoute(
      path: '/grinding_machine/projects/:id',
      builder: (context, state) => GrindingSelectionProjectDetailScreen(
        projectId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/grinding_machine/projects/:id/proposals/new',
      builder: (context, state) => GrindingProposalEditorScreen(
        projectId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/grinding_machine/projects/:id/proposals/:proposalId',
      builder: (context, state) => GrindingProposalEditorScreen(
        projectId: int.parse(state.pathParameters['id']!),
        proposalId: int.parse(state.pathParameters['proposalId']!),
      ),
    ),
    GoRoute(
      // Giữ lại để tránh regression (Phase 4) — Home không còn liên kết tới
      // route này, đã thay bằng /grinding_machine/selector (Phase 6) để
      // tránh 2 chức năng "chọn máy" gần giống nhau cùng hiện trên Home.
      path: '/grinding_machine/selection',
      builder: (context, state) => const GrindingMachineSelectionScreen(),
    ),
    GoRoute(
      path: '/grinding_machine/recommendation',
      builder: (context, state) {
        // Kết quả tính không đưa lên địa chỉ được: mất extra thì quay về màn
        // chọn máy để nhập lại.
        final extra = state.extra;
        if (extra is! Map ||
            extra['request'] is! GrindingSelectionRequest ||
            extra['materialName'] is! String) {
          return const GrindingMachineSelectionScreen();
        }
        return GrindingMachineRecommendationScreen(
          request: extra['request'] as GrindingSelectionRequest,
          materialName: extra['materialName'] as String,
        );
      },
    ),
    GoRoute(
      path: '/productivity_calc',
      builder: (context, state) => const ProductivityCalcScreen(),
    ),
    GoRoute(
      path: '/technical_converter',
      builder: (context, state) => const TechnicalConverterScreen(),
    ),
    GoRoute(
      path: '/color_sorter_categories',
      builder: (context, state) => const ColorSorterCategoriesScreen(),
    ),
    GoRoute(
      path: '/paddy_color_sorter_menu',
      builder: (context, state) =>
          PaddyColorSorterMenuScreen(line: _sfLine(state)),
    ),
    GoRoute(
      path: '/paddy_color_sorter',
      builder: (context, state) => PaddyColorSorterScreen(
        initialModel: state.uri.queryParameters['model'],
        line: _sfLine(state),
      ),
    ),
    GoRoute(
      path: '/paddy_aux_equip',
      builder: (context, state) => PaddyAuxEquipScreen(line: _sfLine(state)),
    ),
    GoRoute(
      path: '/color_sorter_menu',
      builder: (context, state) => const ColorSorterMenuScreen(),
    ),
    GoRoute(
      path: '/tea_color_sorter_menu',
      builder: (context, state) => const TeaColorSorterMenuScreen(),
    ),
    GoRoute(
      path: '/tea_color_sorter',
      builder: (context, state) => TeaColorSorterScreen(
        initialModel: state.uri.queryParameters['model'],
      ),
    ),
    GoRoute(
      path: '/tea_aux_equip',
      builder: (context, state) {
        final modelName = state.extra as String? ?? 'DF53 PRO';
        return TeaAuxEquipScreen(modelName: modelName);
      },
    ),
    GoRoute(
      path: '/mineral_color_sorter_menu',
      builder: (context, state) => const MineralColorSorterMenuScreen(),
    ),
    GoRoute(
      path: '/mineral_color_sorter',
      builder: (context, state) => MineralColorSorterScreen(
        initialModel: state.uri.queryParameters['model'],
      ),
    ),
    GoRoute(
      path: '/mineral_color_sorter/select',
      builder: (context, state) => const MineralSorterSelectorScreen(),
    ),
    GoRoute(
      path: '/agro_color_sorter_menu',
      builder: (context, state) => const AgroColorSorterMenuScreen(),
    ),
    GoRoute(
      path: '/agro_color_sorter',
      builder: (context, state) => AgroColorSorterScreen(
        initialModel: state.uri.queryParameters['model'],
      ),
    ),
    GoRoute(
      path: '/acomp_menu',
      builder: (context, state) => const AcompMenuScreen(),
    ),
    GoRoute(
      path: '/acomp_tech_category',
      builder: (context, state) => const AcompTechCategoryScreen(),
    ),
    GoRoute(
      path: '/acomp_tech_detail',
      builder: (context, state) {
        final categoryType =
            state.uri.queryParameters['type'] ?? state.extra as String? ?? 'PV';
        return AcompTechDetailScreen(categoryType: categoryType);
      },
    ),
    GoRoute(
      path: '/acomp_suitable',
      builder: (context, state) => const AcompSuitableScreen(),
    ),
    GoRoute(
      path: '/acomp_tank',
      builder: (context, state) => const AcompTankScreen(),
    ),
    GoRoute(
      path: '/acomp_mccb_cable',
      builder: (context, state) => const AcompMccbCableScreen(),
    ),
    GoRoute(
      path: '/acomp_pipe',
      builder: (context, state) => const AcompPipeScreen(),
    ),
    GoRoute(
      path: '/acomp_tank_fill_time',
      builder: (context, state) => const AcompTankFillTimeScreen(),
    ),
    GoRoute(
      path: '/acomp_vsd_compare',
      builder: (context, state) =>
          AcompVsdCompareScreen(initialSize: state.uri.queryParameters['size']),
    ),
    GoRoute(
      path: '/acomp_troubleshooting',
      builder: (context, state) => const AcompTroubleshootingMenuScreen(),
    ),
    GoRoute(
      path: '/acomp_common_errors',
      builder: (context, state) => const AcompCommonErrorsScreen(),
    ),
    GoRoute(
      path: '/color_sorter_errors',
      builder: (context, state) => ColorSorterErrorsScreen(
        machineLine: state.uri.queryParameters['line'],
      ),
    ),
    GoRoute(
      path: '/acomp_ds8011_settings',
      builder: (context, state) => const AcompDs8011SettingsScreen(),
    ),
    GoRoute(
      path: '/color_sorter',
      builder: (context, state) =>
          ColorSorterScreen(initialModel: state.uri.queryParameters['model']),
    ),
    GoRoute(
      path: '/color_sorter_3d',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final modelName = extra?['modelName'] ?? 'SC16 Pro';
        final modelPath = extra?['modelPath'] ?? 'assets/models/sc16_pro.glb';
        final posterPath =
            extra?['posterPath'] ?? 'assets/images/color_sorter/sc16.jpeg';
        final dimensions = extra?['dimensions'] ?? '4830x1690x1915 mm';
        final configuration = extra?['configuration'] ?? '7:3:2';
        final technology = extra?['technology'] ?? 'AI Deep Learning';
        final exposure = extra?['exposure'] ?? 0.85;
        final showHotspots = extra?['showHotspots'] as bool? ?? false;
        final environmentImage =
            extra?['environmentImage'] as String? ?? 'neutral';
        return ColorSorter3dScreen(
          modelName: modelName as String,
          modelPath: modelPath as String,
          posterPath: posterPath as String,
          dimensions: dimensions as String,
          configuration: configuration as String,
          technology: technology as String,
          exposure: (exposure as num).toDouble(),
          showHotspots: showHotspots,
          environmentImage: environmentImage,
        );
      },
    ),
    GoRoute(
      path: '/aux_equip',
      builder: (context, state) {
        final initialModel = state.extra as String?;
        return AuxEquipScreen(initialModel: initialModel);
      },
    ),
    GoRoute(
      path: '/payback_analysis',
      builder: (context, state) =>
          PaybackAnalysisMenuScreen(line: _colorSorterLine(state)),
    ),
    GoRoute(
      path: '/power_consumption',
      builder: (context, state) =>
          PowerConsumptionScreen(line: _colorSorterLine(state)),
    ),
    GoRoute(
      path: '/electricity_bill',
      builder: (context, state) =>
          ElectricityBillScreen(line: _colorSorterLine(state)),
    ),
    GoRoute(
      path: '/processing_profit',
      builder: (context, state) => const ProcessingProfitScreen(),
    ),
    GoRoute(
      path: '/payback_period',
      builder: (context, state) => const PaybackPeriodScreen(),
    ),
    GoRoute(
      path: '/self_business',
      builder: (context, state) => const SelfBusinessScreen(),
    ),
    GoRoute(
      path: '/payback_chart',
      builder: (context, state) => const PaybackChartScreen(),
    ),
    // ─── Packing Module ──────────────────────────────────────────────────────
    GoRoute(
      path: '/packing_menu',
      builder: (context, state) => const PackingMenuScreen(),
    ),
    GoRoute(
      path: '/packing_search',
      builder: (context, state) => const PackingSearchScreen(),
    ),
    GoRoute(
      path: '/packing_detail',
      builder: (context, state) {
        final extra = state.extra;
        var modelName = state.uri.queryParameters['model'] ?? '';
        var showCatalog = state.uri.queryParameters['catalog'] != 'false';
        if (extra is Map) {
          modelName = modelName.isNotEmpty
              ? modelName
              : extra['model'] as String? ?? '';
          if (!state.uri.queryParameters.containsKey('catalog')) {
            showCatalog = extra['showCatalog'] as bool? ?? true;
          }
        } else if (modelName.isEmpty) {
          modelName = extra as String? ?? '';
        }
        return MachineDetailScreen(
          modelName: modelName,
          showCatalog: showCatalog,
        );
      },
    ),
    GoRoute(
      path: '/machine_selector',
      builder: (context, state) => const MachineSelectorScreen(),
    ),
    GoRoute(
      path: '/machine_catalog',
      builder: (context, state) => const MachineCatalogScreen(),
    ),
    GoRoute(
      path: '/machine_compare',
      builder: (context, state) => const CompareScreen(),
    ),
    GoRoute(
      path: '/packing_catalog_viewer',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final query = state.uri.queryParameters;
        return PackingCatalogViewerScreen(
          assetPath: query['path'] ?? extra['path'] as String? ?? '',
          initialPage:
              int.tryParse(query['page'] ?? '') ?? extra['page'] as int? ?? 1,
          modelName: query['model'] ?? extra['model'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/maintenance',
      builder: (context, state) => const MaintenanceListScreen(),
    ),
    GoRoute(
      path: '/maintenance_form',
      builder: (context, state) {
        final record = state.extra as MaintenanceRecord?;
        return MaintenanceFormScreen(record: record);
      },
    ),
    // Projects module routes
    GoRoute(
      path: '/projects',
      builder: (context, state) => const ProjectsPage(),
    ),
    GoRoute(
      path: '/projects/create',
      builder: (context, state) => const ProjectCreatePage(),
    ),
    GoRoute(
      path: '/projects/schedule',
      builder: (context, state) => const ProjectSchedulePage(),
    ),
    GoRoute(
      path: '/projects/:id/machines',
      builder: (context, state) =>
          ProjectMachinePage(projectId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/projects/:id/stages/:stageId',
      builder: (context, state) => ProjectStagePage(
        projectId: state.pathParameters['id']!,
        stageId: state.pathParameters['stageId']!,
      ),
    ),
    GoRoute(
      path: '/projects/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ProjectDetailPage(projectId: id);
      },
    ),
  ],
);
