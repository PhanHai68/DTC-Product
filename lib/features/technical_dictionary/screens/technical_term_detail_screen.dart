import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/technical_term.dart';
import '../providers/technical_dictionary_provider.dart';

class TechnicalTermDetailScreen extends StatelessWidget {
  const TechnicalTermDetailScreen({super.key, required this.termId});

  final int termId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TechnicalDictionaryProvider>();
    final term = provider.termById(termId);
    if (term == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Từ điển chuyên ngành')),
        body: Center(
          child: provider.loading || !provider.ready
              ? const CircularProgressIndicator()
              : const Text('Không tìm thấy thuật ngữ này.'),
        ),
      );
    }
    final progress = provider.progressOf(term);
    return Scaffold(
      appBar: AppBar(title: Text(term.term)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _Header(term: term),
          if (term.explanation.isNotEmpty)
            _Section(
              title: 'Giải thích',
              child: Text(term.explanation, style: const TextStyle(height: 1.45)),
            ),
          if (term.example.isNotEmpty)
            _Section(
              title: 'Câu mẫu',
              trailing: IconButton(
                key: const Key('dictionary_copy_example'),
                tooltip: 'Sao chép câu mẫu',
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: () => _copyExample(context, term),
              ),
              child: _Example(term: term),
            ),
          if (term.related.isNotEmpty)
            _Section(
              title: 'Từ liên quan',
              child: _RelatedTerms(provider: provider, term: term),
            ),
          _Section(
            title: 'Học & ghi chú',
            child: _ProgressEditor(
              key: ValueKey(term.id),
              term: term,
              progress: progress,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyExample(BuildContext context, TechnicalTerm term) async {
    await Clipboard.setData(ClipboardData(text: term.example));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép câu mẫu.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.term});

  final TechnicalTerm term;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              term.term,
              style: TextStyle(
                color: palette.navy,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (term.abbreviation.isNotEmpty || term.ipa.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
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
                    Text(term.ipa, style: TextStyle(color: palette.muted)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            SelectableText(
              term.meaning,
              style: TextStyle(
                color: palette.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag(icon: Icons.settings_outlined, text: term.group),
                _Tag(icon: Icons.label_outline_rounded, text: term.type),
              ],
            ),
            if (term.aliases.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Tên gọi khác: ',
                      style: TextStyle(
                        color: palette.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: term.aliases.join(' · ')),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: palette.navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _Example extends StatelessWidget {
  const _Example({required this.term});

  final TechnicalTerm term;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: palette.cyan, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            term.example,
            style: const TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          if (term.exampleMeaning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              term.exampleMeaning,
              style: TextStyle(color: palette.muted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// Từ có trong từ điển thì bấm để mở; từ chưa có chỉ hiện chữ.
class _RelatedTerms extends StatelessWidget {
  const _RelatedTerms({required this.provider, required this.term});

  final TechnicalDictionaryProvider provider;
  final TechnicalTerm term;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in term.related)
          if (provider.lookup(name) case final target?
              when target.id != term.id)
            ActionChip(
              key: Key('dictionary_related_${target.id}'),
              avatar: Icon(Icons.link_rounded, size: 16, color: palette.cyan),
              label: Text(name),
              tooltip: '${target.term}: ${target.meaning}',
              onPressed: () =>
                  context.push('/technical-dictionary/term/${target.id}'),
            )
          else
            Tooltip(
              message: 'Chưa có trong từ điển',
              child: Chip(
                label: Text(name, style: TextStyle(color: palette.muted)),
              ),
            ),
      ],
    );
  }
}

class _ProgressEditor extends StatefulWidget {
  const _ProgressEditor({
    super.key,
    required this.term,
    required this.progress,
  });

  final TechnicalTerm term;
  final TermProgress progress;

  @override
  State<_ProgressEditor> createState() => _ProgressEditorState();
}

class _ProgressEditorState extends State<_ProgressEditor> {
  late final TextEditingController _note;
  late final TechnicalDictionaryProvider _provider;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.progress.note);
    _provider = context.read<TechnicalDictionaryProvider>();
  }

  @override
  void dispose() {
    // Rời màn hình khi vừa gõ xong: lưu nốt ghi chú (sau khi cây widget đã
    // hủy xong, tránh báo cập nhật giữa lúc đang dựng lại).
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      final provider = _provider;
      final term = widget.term;
      final note = _note.text;
      Future.microtask(() => provider.setNote(term, note));
    }
    _note.dispose();
    super.dispose();
  }

  void _onNoteChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 600),
      () => _provider.setNote(widget.term, value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.progress.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TermStatus?>(
          key: const Key('dictionary_status'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: null, label: Text('Chưa học')),
            ButtonSegment(
              value: TermStatus.learning,
              icon: Icon(Icons.school_outlined),
              label: Text('Đang học'),
            ),
            ButtonSegment(
              value: TermStatus.learned,
              icon: Icon(Icons.check_circle_outline_rounded),
              label: Text('Đã thuộc'),
            ),
          ],
          selected: {status},
          onSelectionChanged: (value) =>
              _provider.setStatus(widget.term, value.first),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('dictionary_note'),
          controller: _note,
          onChanged: _onNoteChanged,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Ghi chú của bạn',
            hintText: 'Cách hãng gọi riêng, mã phụ tùng, model liên quan…',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ghi chú và trạng thái tự lưu trên máy này, có trong bản sao lưu dữ liệu.',
          style: TextStyle(color: DtcPalette.of(context).muted, fontSize: 12),
        ),
      ],
    );
  }
}
