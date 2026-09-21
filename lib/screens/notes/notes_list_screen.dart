import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../providers/notes_provider.dart';
import '../../widgets/notes/note_card.dart';
import '../../widgets/notes/note_share_sheet.dart';

class NotesListScreen extends StatelessWidget {
  const NotesListScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bạn có chắc muốn xóa ghi chú này không?'),
        content: Text(
          note.title.trim().isEmpty
              ? 'Ghi chú sẽ bị xóa vĩnh viễn khỏi thiết bị.'
              : '"${note.title}" sẽ bị xóa vĩnh viễn khỏi thiết bị.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || note.id == null) return;
    if (!context.mounted) return;
    try {
      await context.read<NotesProvider>().deleteNote(note.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xóa ghi chú.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xóa ghi chú. Vui lòng thử lại.')),
        );
      }
    }
  }

  void _handleAction(
    BuildContext context,
    Note note,
    NoteCardAction action,
  ) {
    switch (action) {
      case NoteCardAction.edit:
        context.push('/notes/edit', extra: {'noteId': note.id});
        break;
      case NoteCardAction.togglePin:
        context.read<NotesProvider>().togglePinned(note);
        break;
      case NoteCardAction.share:
        showNoteShareSheet(context, note);
        break;
      case NoteCardAction.exportPdf:
        exportNotePdf(context, note);
        break;
      case NoteCardAction.exportImage:
        showNoteImageExportDialog(context, note);
        break;
      case NoteCardAction.delete:
        _confirmDelete(context, note);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ghi chú & Nhắc hẹn'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                SearchBar(
                  key: const Key('notes_search_field'),
                  hintText: 'Tìm kiếm ghi chú...',
                  leading: const Icon(Icons.search_rounded),
                  onChanged: (value) =>
                      context.read<NotesProvider>().setSearchQuery(value),
                ),
                const SizedBox(height: 10),
                Consumer<NotesProvider>(
                  builder: (context, provider, _) => SegmentedButton<NoteFilter>(
                    segments: const [
                      ButtonSegment(
                        value: NoteFilter.all,
                        label: Text('Tất cả'),
                      ),
                      ButtonSegment(
                        value: NoteFilter.reminder,
                        label: Text('Có nhắc hẹn'),
                        icon: Icon(Icons.notifications_active_outlined),
                      ),
                      ButtonSegment(
                        value: NoteFilter.pinned,
                        label: Text('Đã ghim'),
                        icon: Icon(Icons.push_pin_outlined),
                      ),
                    ],
                    selected: {provider.filter},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        provider.setFilter(selection.first),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Consumer<NotesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.notes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 56,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(provider.errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: provider.loadNotes,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final notes = provider.filteredNotes;

          if (notes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.note_alt_outlined,
                      size: 64,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      provider.searchQuery.isEmpty &&
                              provider.filter == NoteFilter.all
                          ? 'Chưa có ghi chú nào.\nBấm nút + để tạo ghi chú đầu tiên.'
                          : 'Không tìm thấy ghi chú phù hợp.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.loadNotes,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return NoteCard(
                  note: note,
                  onTap: () =>
                      context.push('/notes/edit', extra: {'noteId': note.id}),
                  onAction: (action) => _handleAction(context, note, action),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('notes_add_button'),
        tooltip: 'Tạo ghi chú mới',
        onPressed: () => context.push('/notes/edit'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
