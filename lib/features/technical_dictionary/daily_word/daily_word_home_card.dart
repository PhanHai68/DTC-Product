import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../providers/settings_provider.dart';
import '../../../theme/dtc_palette.dart';
import '../models/technical_term.dart';
import '../widgets/en_vi_badge.dart';
import 'daily_word_controller.dart';

/// Thẻ "Từ vựng hôm nay" trên Home: học thụ động một thuật ngữ trong Từ điển
/// chuyên ngành. Tự ẩn khi tắt trong Cá nhân hóa trang chủ, và chỉ hiện khi
/// đã nạp xong từ điển (nạp sau khung hình đầu để không làm chậm Home).
class DailyWordHomeCard extends StatefulWidget {
  const DailyWordHomeCard({super.key, this.createController});

  /// Chỉ dùng trong test.
  final DailyWordController Function()? createController;

  @override
  State<DailyWordHomeCard> createState() => _DailyWordHomeCardState();
}

enum _MenuAction { learned, hide, settings }

class _DailyWordHomeCardState extends State<DailyWordHomeCard> {
  late final DailyWordController _controller =
      widget.createController?.call() ?? DailyWordController();
  bool _started = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply(SettingsProvider settings) {
    final options = DailyWordOptions.fromSettings(settings);
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.apply(options);
      });
    } else {
      _controller.apply(options);
    }
  }

  Future<void> _onMenu(_MenuAction action) async {
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case _MenuAction.learned:
        final term = _controller.current;
        await _controller.markLearned();
        if (term == null || !mounted) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Đã đánh dấu "${term.term}" là đã thuộc.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      case _MenuAction.hide:
        final settings = context.read<SettingsProvider>();
        await settings.setHomeDailyWordEnabled(false);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text(
                'Đã ẩn "Từ vựng hôm nay". Bật lại trong Cá nhân hóa trang chủ.',
              ),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Hoàn tác',
                onPressed: () => settings.setHomeDailyWordEnabled(true),
              ),
            ),
          );
      case _MenuAction.settings:
        context.push('/settings/home_personalization');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (!settings.homeDailyWordEnabled) return const SizedBox.shrink();
    _apply(settings);

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final term = _controller.current;
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: term == null
              ? const SizedBox(width: double.infinity)
              : _Card(
                  term: term,
                  onOpen: () =>
                      context.push('/technical-dictionary/term/${term.id}'),
                  onNext: _controller.next,
                  onMenu: _onMenu,
                ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.term,
    required this.onOpen,
    required this.onNext,
    required this.onMenu,
  });

  final TechnicalTerm term;
  final VoidCallback onOpen;
  final VoidCallback onNext;
  final ValueChanged<_MenuAction> onMenu;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Card(
            key: const Key('daily_word_home_card'),
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: palette.border),
            ),
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 6, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const EnViBadge(size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Từ vựng hôm nay',
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('daily_word_next'),
                          tooltip: 'Từ khác',
                          visualDensity: VisualDensity.compact,
                          onPressed: onNext,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                        ),
                        PopupMenuButton<_MenuAction>(
                          key: const Key('daily_word_menu'),
                          tooltip: 'Tùy chọn',
                          icon: const Icon(Icons.more_vert_rounded, size: 20),
                          onSelected: onMenu,
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: _MenuAction.learned,
                              child: ListTile(
                                leading: Icon(Icons.check_circle_outline_rounded),
                                title: Text('Đã thuộc từ này'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: _MenuAction.settings,
                              child: ListTile(
                                leading: Icon(Icons.tune_rounded),
                                title: Text('Cài đặt thẻ'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: _MenuAction.hide,
                              child: ListTile(
                                leading: Icon(Icons.visibility_off_outlined),
                                title: Text('Ẩn thẻ'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                term.term,
                                key: const Key('daily_word_term'),
                                style: TextStyle(
                                  color: palette.navy,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (term.abbreviation.isNotEmpty &&
                                  term.abbreviation != term.term)
                                Text(
                                  term.abbreviation,
                                  style: TextStyle(
                                    color: palette.cyan,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              if (term.ipa.isNotEmpty)
                                Text(
                                  term.ipa,
                                  style: TextStyle(color: palette.muted),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            term.meaning,
                            style: TextStyle(
                              color: palette.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${term.group} · ${term.type}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
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
