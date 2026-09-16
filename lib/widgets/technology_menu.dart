import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

abstract final class DtcPalette {
  static const navy = Color(0xFF0A2740);
  static const navyLight = Color(0xFF123D5A);
  static const cyan = Color(0xFF00A6A6);
  static const cyanLight = Color(0xFF37C6B7);
  static const ink = Color(0xFF102F46);
  static const muted = Color(0xFF607786);
  static const canvas = Color(0xFFF3F7F9);
  static const border = Color(0xFFDCE7EB);
}

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
    return Scaffold(
      backgroundColor: DtcPalette.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            toolbarHeight: 68,
            backgroundColor: Colors.white,
            foregroundColor: DtcPalette.navy,
            surfaceTintColor: Colors.transparent,
            shadowColor: DtcPalette.navy.withValues(alpha: 0.08),
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
                  foregroundColor: DtcPalette.navy,
                  backgroundColor: const Color(0xFFE8F5F3),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: DtcPalette.navy,
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
    return Row(
      children: [
        Container(
          width: 4,
          height: 38,
          decoration: BoxDecoration(
            color: DtcPalette.cyan,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Trung tâm chức năng',
            style: TextStyle(
              color: DtcPalette.ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F7F5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$itemCount mục',
            style: const TextStyle(
              color: Color(0xFF087F78),
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
    return Semantics(
      button: entry.enabled,
      enabled: entry.enabled,
      label: entry.title,
      hint: entry.statusLabel,
      child: Material(
        color: entry.enabled
            ? (entry.featured ? const Color(0xFFF0FAF9) : Colors.white)
            : const Color(0xFFF4F6F7),
        elevation: entry.enabled && entry.featured ? 2 : 0,
        shadowColor: DtcPalette.navy.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: entry.featured && entry.enabled
                ? DtcPalette.cyan.withValues(alpha: 0.48)
                : DtcPalette.border,
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
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFE4F5F4), Color(0xFFD8F0F2)],
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
                                color: entry.iconColor ?? DtcPalette.navyLight,
                              ),
                            ),
                          )
                        : Icon(
                            entry.icon,
                            color: entry.iconColor ?? DtcPalette.navyLight,
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
                                ? DtcPalette.ink
                                : DtcPalette.muted,
                            fontSize: 15.5,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (entry.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.subtitle!,
                            style: const TextStyle(
                              color: DtcPalette.muted,
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
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        entry.statusLabel!,
                        style: const TextStyle(
                          color: Color(0xFF725400),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    Text(
                      index.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: DtcPalette.navy.withValues(alpha: 0.28),
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
                    color: entry.enabled
                        ? const Color(0xFF087F78)
                        : DtcPalette.muted,
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
