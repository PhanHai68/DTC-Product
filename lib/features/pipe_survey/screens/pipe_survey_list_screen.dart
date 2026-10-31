import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pipe_survey.dart';
import '../repositories/pipe_survey_repository.dart';
import 'pipe_survey_editor_screen.dart';

/// Danh sách công trình đã khảo sát tuyến ống: mở, nhân bản, xoá, tạo mới.
class PipeSurveyListScreen extends StatefulWidget {
  const PipeSurveyListScreen({super.key, this.repository});
  final PipeSurveyRepository? repository;

  @override
  State<PipeSurveyListScreen> createState() => _PipeSurveyListScreenState();
}

class _PipeSurveyListScreenState extends State<PipeSurveyListScreen> {
  late final PipeSurveyRepository _repository =
      widget.repository ?? PipeSurveyRepository();
  late Future<List<PipeSurveySummary>> _items = _repository.list();

  void _reload() => setState(() {
    _items = _repository.list();
  });

  Future<void> _open({String? id, PipeSurvey? initial}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PipeSurveyEditorScreen(
          surveyId: id,
          initial: initial,
          repository: _repository,
        ),
      ),
    );
    _reload();
  }

  Future<void> _duplicate(String id) async {
    final survey = await _repository.get(id);
    if (survey == null) return;
    final copy = PipeSurvey.fromJson({
      ...survey.toJson(),
      'id': null,
      'name': '${survey.name} (bản sao)',
      'createdAt': null,
      'updatedAt': null,
    });
    await _repository.save(copy);
    _reload();
  }

  Future<void> _delete(PipeSurveySummary item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá khảo sát?'),
        content: Text(
          'Xoá "${item.name.isEmpty ? 'Chưa đặt tên' : item.name}"? Không khôi phục được.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repository.delete(item.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Khảo sát vật tư ngoại tuyến')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('survey_new'),
        onPressed: () => _open(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Khảo sát mới'),
      ),
      body: FutureBuilder<List<PipeSurveySummary>>(
        future: _items,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Chưa có khảo sát nào.\nBấm "Khảo sát mới" để vẽ tuyến ống tại công trình.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, k) {
              final item = items[k];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.route_outlined),
                  title: Text(
                    item.name.isEmpty ? 'Chưa đặt tên' : item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      if (item.customer.isNotEmpty) item.customer,
                      '${item.usePoints} điểm sử dụng',
                      'Sửa ${DateFormat('dd/MM/yyyy HH:mm').format(item.updatedAt)}',
                    ].join(' · '),
                  ),
                  onTap: () => _open(id: item.id),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) =>
                        v == 'copy' ? _duplicate(item.id) : _delete(item),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'copy', child: Text('Nhân bản')),
                      PopupMenuItem(value: 'delete', child: Text('Xoá')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
