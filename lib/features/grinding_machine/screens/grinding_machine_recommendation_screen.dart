import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/grinding_recommendation.dart';
import '../models/grinding_selection_request.dart';
import '../providers/grinding_machine_provider.dart';

/// Kết quả đề xuất (mục 7-8) — tối đa 3 model, kèm Reason/Warning; nếu
/// không có model nào đạt yêu cầu thì hiển thị rõ "Insufficient data",
/// KHÔNG tự suy đoán 1 model bất kỳ.
class GrindingMachineRecommendationScreen extends StatefulWidget {
  const GrindingMachineRecommendationScreen({
    super.key,
    required this.request,
    required this.materialName,
  });

  final GrindingSelectionRequest request;
  final String materialName;

  @override
  State<GrindingMachineRecommendationScreen> createState() =>
      _GrindingMachineRecommendationScreenState();
}

class _GrindingMachineRecommendationScreenState
    extends State<GrindingMachineRecommendationScreen> {
  List<GrindingRecommendation>? _results;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final results = await context
            .read<GrindingMachineProvider>()
            .recommend(widget.request, materialName: widget.materialName);
        if (!mounted) return;
        setState(() => _results = results);
      } catch (error) {
        if (!mounted) return;
        setState(() => _error = 'Không thể chấm điểm đề xuất: $error');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final results = _results;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: const Text('Model đề xuất')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.muted),
                ),
              ),
            )
          : results == null
          ? const Center(child: CircularProgressIndicator())
          : results.isEmpty
          ? _InsufficientDataView(request: widget.request)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  '${results.length} model phù hợp nhất',
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < results.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RecommendationCard(
                      rank: i + 1,
                      recommendation: results[i],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _InsufficientDataView extends StatelessWidget {
  const _InsufficientDataView({required this.request});

  final GrindingSelectionRequest request;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: palette.muted),
            const SizedBox(height: 14),
            Text(
              'Insufficient data',
              style: TextStyle(
                color: palette.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Không có model nào trong database đạt đủ yêu cầu kỹ thuật '
              '(công suất ${request.capacityKgH.toStringAsFixed(0)} kg/h, độ mịn '
              '${request.finenessValue} ${request.finenessUnit}'
              '${request.inputSizeMm != null ? ', đầu vào ${request.inputSizeMm} mm' : ''}). '
              'Hãy thử điều chỉnh yêu cầu hoặc liên hệ DTC để được tư vấn thêm.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.muted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.rank, required this.recommendation});

  final int rank;
  final GrindingRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final machine = recommendation.machine;
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: recommendation.isStrongCandidate
              ? palette.cyan.withValues(alpha: 0.5)
              : palette.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('grinding_recommendation_card_${machine.machineId}'),
        onTap: () =>
            context.push('/grinding_machine/detail/${machine.machineId}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.cyan.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        color: palette.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      machine.model,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: recommendation.isStrongCandidate
                          ? palette.cyan.withValues(alpha: 0.16)
                          : palette.canvas,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      recommendation.isStrongCandidate
                          ? 'ỨNG VIÊN MẠNH'
                          : 'ỨNG VIÊN',
                      style: TextStyle(
                        color: recommendation.isStrongCandidate
                            ? palette.navy
                            : palette.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (recommendation.series != null) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    recommendation.series!.nameVi,
                    style: TextStyle(color: palette.muted, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (recommendation.reasons.isNotEmpty) ...[
                Text(
                  'Lý do đề xuất',
                  style: TextStyle(
                    color: palette.navy,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                for (final reason in recommendation.reasons)
                  _BulletLine(text: reason, color: palette.ink),
              ],
              if (recommendation.warnings.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Lưu ý',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                for (final warning in recommendation.warnings)
                  _BulletLine(
                    text: warning,
                    color: Colors.orange.shade900,
                    icon: Icons.warning_amber_rounded,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({
    required this.text,
    required this.color,
    this.icon = Icons.check_circle_outline_rounded,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
