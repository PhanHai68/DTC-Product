import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/home_personalization_widget.dart';
import '../widgets/technology_menu.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _actions = [
    _HomeAction(
      title: 'Máy tách màu',
      imagePath: 'assets/images/home_color_sorter_5_chutes_v5.png',
      route: '/color_sorter_categories',
    ),
    _HomeAction(
      title: 'Cân đóng gói',
      imagePath: 'assets/images/home_packing_lzb1200.jpg',
      route: '/packing_menu',
    ),
    _HomeAction(
      title: 'Máy nén khí',
      imagePath: 'assets/images/home_air_compressor_v5.png',
      route: '/acomp_menu',
    ),
    _HomeAction(
      title: 'Công cụ & Tiện ích',
      icon: Icons.dashboard_customize_outlined,
      route: '/extensions',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _BrandHeader()),
            const SliverToBoxAdapter(child: HomePersonalizationWidget()),
            const SliverToBoxAdapter(child: _QuickSearchBar()),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth < 300
                            ? 1
                            : constraints.maxWidth >= 900
                            ? 4
                            : 2;
                        final spacing = constraints.maxWidth >= 900
                            ? 18.0
                            : 12.0;
                        final cardWidth =
                            (constraints.maxWidth - spacing * (columns - 1)) /
                            columns;
                        final cardHeight = columns == 1
                            ? 190.0
                            : cardWidth >= 230
                            ? 258.0
                            : 198.0;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: _actions.map((action) {
                            return SizedBox(
                              width: cardWidth,
                              height: cardHeight,
                              child: _HomeActionCard(
                                action: action,
                                compact: cardWidth < 200,
                                onTap: () => context.push(action.route),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _MinimalFooter(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 14),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Image.asset(
              'assets/images/dtc_product_wordmark_full.png',
              key: const Key('home_brand_wordmark'),
              height: 52,
              semanticLabel: 'DTC Product',
            ),
          ),
          Positioned(
            right: 12,
            child: IconButton(
              key: const ValueKey('home_settings_button'),
              tooltip: 'Cài đặt',
              onPressed: () => context.push('/settings'),
              icon: Icon(Icons.settings_outlined, color: palette.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAction {
  final String title;
  final String? imagePath;
  final IconData? icon;
  final String route;

  const _HomeAction({
    required this.title,
    this.imagePath,
    this.icon,
    required this.route,
  });
}

class _HomeActionCard extends StatelessWidget {
  final _HomeAction action;
  final bool compact;
  final VoidCallback onTap;

  const _HomeActionCard({
    required this.action,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Semantics(
      button: true,
      label: 'Mở ${action.title}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: palette.navy.withValues(alpha: 0.055),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('home_solution_${action.route}'),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(compact ? 9 : 11),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(compact ? 8 : 12),
                      decoration: BoxDecoration(
                        color: palette.canvas,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: _ActionVisual(action: action, compact: compact),
                    ),
                  ),
                  SizedBox(height: compact ? 9 : 11),
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: compact ? 33 : 38),
                    child: Center(
                      child: Text(
                        action.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: compact ? 15.5 : 17,
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickSearchBar extends StatelessWidget {
  const _QuickSearchBar();

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: Material(
            color: palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: palette.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/search'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: palette.cyan),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tra cứu model hoặc chức năng',
                        style: TextStyle(
                          color: palette.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: palette.cyan),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionVisual extends StatelessWidget {
  final _HomeAction action;
  final bool compact;

  const _ActionVisual({required this.action, required this.compact});

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final imagePath = action.imagePath;
    if (imagePath != null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      // Ảnh gốc lớn hơn nhiều so với kích thước hiển thị trong card (chỉ
      // ~150-280px) — giới hạn cacheWidth để Flutter giải mã ảnh ở độ phân
      // giải phù hợp thay vì decode nguyên ảnh gốc rồi mới thu nhỏ, giảm
      // thời gian và bộ nhớ khi vẽ Home.
      final cacheWidth =
          (280 * MediaQuery.of(context).devicePixelRatio).round();
      final image = Image.asset(
        imagePath,
        fit: BoxFit.contain,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => Icon(
          Icons.precision_manufacturing_outlined,
          color: palette.navy,
          size: 54,
        ),
      );
      // Chỉ áp filter làm dịu ảnh ở chế độ sáng; ở chế độ tối filter multiply
      // với nền tối sẽ làm ảnh gần như biến mất nên bỏ qua, giữ ảnh gốc.
      if (isDark) return image;
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0xFFF5F7F8),
          BlendMode.multiply,
        ),
        child: image,
      );
    }
    return Padding(
      padding: EdgeInsets.all(compact ? 4.0 : 8.0),
      child: Center(
        child: Icon(
          action.icon ?? Icons.extension_outlined,
          size: compact ? 72.0 : 96.0,
          color: const Color(0xFF168052),
          shadows: const [
            Shadow(
              color: Color(0x55000000),
              blurRadius: 12.0,
              offset: Offset(4.0, 5.0),
            ),
            Shadow(
              color: Color(0x33168052),
              blurRadius: 15.0,
              offset: Offset(-2.0, -2.0),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimalFooter extends StatelessWidget {
  const _MinimalFooter();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'DTC',
                style: TextStyle(color: Color(0xFF138347)),
              ),
              TextSpan(
                text: 'Group',
                style: TextStyle(color: Color(0xFF72AD30)),
              ),
            ],
          ),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
