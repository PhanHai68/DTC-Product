import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/technology_menu.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _actions = [
    _HomeAction(
      title: 'Máy tách màu',
      imagePath: 'assets/images/home_color_sorter_5_chutes_v5.png',
      route: '/color_sorter_menu',
      tint: Color(0xFFF5F7F8),
    ),
    _HomeAction(
      title: 'Cân đóng gói',
      imagePath: 'assets/images/home_packing_v2.png',
      route: '/packing_menu',
      tint: Color(0xFFF5F7F8),
    ),
    _HomeAction(
      title: 'Máy nén khí',
      imagePath: 'assets/images/home_air_compressor_v5.png',
      route: '/acomp_menu',
      tint: Color(0xFFF5F7F8),
    ),
    _HomeAction(
      title: 'Tiện ích mở rộng',
      icon: Icons.extension_outlined,
      route: '/extensions',
      tint: Color(0xFFF5F7F8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _BrandHeader()),
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
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Center(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'DTC',
                style: TextStyle(color: Color(0xFF138347)),
              ),
              TextSpan(
                text: ' Product',
                style: TextStyle(color: Color(0xFF72AD30)),
              ),
            ],
          ),
          maxLines: 1,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
      ),
    );
  }
}

class _HomeAction {
  final String title;
  final String? imagePath;
  final IconData? icon;
  final String route;
  final Color tint;

  const _HomeAction({
    required this.title,
    this.imagePath,
    this.icon,
    required this.route,
    required this.tint,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE6E9)),
        boxShadow: [
          BoxShadow(
            color: DtcPalette.navy.withValues(alpha: 0.055),
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
                      color: action.tint,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: _ActionVisual(action: action, compact: compact),
                  ),
                ),
                SizedBox(height: compact ? 9 : 11),
                SizedBox(
                  height: compact ? 33 : 38,
                  child: Center(
                    child: Text(
                      action.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: DtcPalette.ink,
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
    );
  }
}

class _ActionVisual extends StatelessWidget {
  final _HomeAction action;
  final bool compact;

  const _ActionVisual({required this.action, required this.compact});

  @override
  Widget build(BuildContext context) {
    final imagePath = action.imagePath;
    if (imagePath != null) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0xFFF5F7F8),
          BlendMode.multiply,
        ),
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.precision_manufacturing_outlined,
            color: DtcPalette.navy,
            size: 54,
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.all(compact ? 12.0 : 16.0),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: Icon(
            action.icon ?? Icons.extension_outlined,
            color: const Color(0xFF168052),
          ),
        ),
      ),
    );
  }
}

class _MinimalFooter extends StatelessWidget {
  const _MinimalFooter();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Text(
          'DTCGroup  •  v1.0.0',
          style: TextStyle(
            color: Color(0xFF8FA2AD),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
