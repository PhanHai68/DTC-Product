import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/dtc_palette.dart';

export '../theme/dtc_palette.dart';

class TechnologyMenuEntry {
  final String id;
  final String title;
  final IconData icon; // Fallback icon if imagePath is null
  final String? imagePath;
  final VoidCallback? onTap;
  final bool featured;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final String? subtitle;
  final String? statusLabel;

  const TechnologyMenuEntry({
    required this.id,
    required this.title,
    required this.icon,
    this.imagePath,
    this.onTap,
    this.featured = false,
    this.iconColor,
    this.iconBackgroundColor,
    this.subtitle,
    this.statusLabel,
  });

  bool get enabled => onTap != null;
}

class TechnologyMenuScaffold extends StatelessWidget {
  final String title;
  final List<TechnologyMenuEntry> entries;
  final Key? backButtonKey;

  const TechnologyMenuScaffold({
    super.key,
    required this.title,
    required this.entries,
    this.backButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            toolbarHeight: 68,
            backgroundColor: palette.surface,
            foregroundColor: palette.navy,
            surfaceTintColor: Colors.transparent,
            shadowColor: palette.navy.withValues(alpha: 0.08),
            scrolledUnderElevation: 2,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.all(10),
              child: IconButton.filledTonal(
                key: backButtonKey,
                tooltip: 'Về màn hình chính',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                style: IconButton.styleFrom(
                  foregroundColor: palette.navy,
                  backgroundColor: palette.cyan.withValues(alpha: 0.14),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.navy,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeading(itemCount: entries.length),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 980
                              ? 3
                              : constraints.maxWidth >= 640
                              ? 2
                              : 1;
                          const spacing = 10.0;
                          final cardWidth =
                              (constraints.maxWidth - spacing * (columns - 1)) /
                              columns;

                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: entries.asMap().entries.map((entry) {
                              return SizedBox(
                                width: cardWidth,
                                child: _TechnologyActionCard(
                                  index: entry.key + 1,
                                  entry: entry.value,
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final int itemCount;

  const _SectionHeading({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 38,
          decoration: BoxDecoration(
            color: palette.cyan,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Trung tâm chức năng',
            style: TextStyle(
              color: palette.ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: palette.cyan.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$itemCount mục',
            style: TextStyle(
              color: palette.cyan,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _TechnologyActionCard extends StatelessWidget {
  final int index;
  final TechnologyMenuEntry entry;

  const _TechnologyActionCard({required this.index, required this.entry});

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Semantics(
      button: entry.enabled,
      enabled: entry.enabled,
      label: entry.title,
      hint: entry.statusLabel,
      child: Material(
        color: entry.enabled
            ? (entry.featured
                  ? palette.cyan.withValues(alpha: 0.10)
                  : palette.surface)
            : palette.canvas,
        elevation: entry.enabled && entry.featured ? 2 : 0,
        shadowColor: palette.navy.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: entry.featured && entry.enabled
                ? palette.cyan.withValues(alpha: 0.48)
                : palette.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key(entry.id),
          onTap: entry.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 82),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: entry.iconBackgroundColor == null
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                palette.cyan.withValues(alpha: 0.14),
                                palette.cyan.withValues(alpha: 0.22),
                              ],
                            )
                          : null,
                      color: entry.iconBackgroundColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: entry.imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              entry.imagePath!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                entry.icon,
                                color: entry.iconColor ?? palette.navyLight,
                              ),
                            ),
                          )
                        : Icon(
                            entry.icon,
                            color: entry.iconColor ?? palette.navyLight,
                            size: 23,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: TextStyle(
                            color: entry.enabled
                                ? palette.ink
                                : palette.muted,
                            fontSize: 15.5,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (entry.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.subtitle!,
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 12,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (entry.statusLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF4A3B12)
                            : const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        entry.statusLabel!,
                        style: TextStyle(
                          color: Theme.of(context).brightness ==
                                  Brightness.dark
                              ? const Color(0xFFFFD966)
                              : const Color(0xFF725400),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    Text(
                      index.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: palette.navy.withValues(alpha: 0.28),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    entry.enabled
                        ? Icons.chevron_right_rounded
                        : Icons.schedule_rounded,
                    size: 22,
                    color: entry.enabled ? palette.cyan : palette.muted,
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
