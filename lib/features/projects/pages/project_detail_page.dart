import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../models/project.dart';
import '../models/project_log.dart';
import '../models/project_stage.dart';

class ProjectDetailPage extends StatefulWidget {
  final String projectId;
  const ProjectDetailPage({super.key, required this.projectId});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProjectProvider>().loadProjectDetail(widget.projectId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final tealColor = const Color(0xFF007F7A);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F9),
      appBar: AppBar(
        title: const Text('CHI TIẾT DỰ ÁN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF102F46),
        elevation: 0,
        centerTitle: true,
      ),
      body: provider.isLoadingDetail
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
              ? Center(child: Text(provider.error!))
              : provider.currentProject == null
                  ? const Center(child: Text('Không tìm thấy dự án'))
                  : _buildBody(context, provider.currentProject!, provider.currentLogs),
      bottomNavigationBar: provider.currentProject != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tính năng chụp ảnh/thêm nhật ký đang phát triển (Phase 2)')),
                    );
                  },
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text('CHỤP ẢNH / THÊM NHẬT KÝ', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context, Project project, List<ProjectLog> logs) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderInfo(project),
          _buildStageProgress(project, logs),
          _buildTimeline(logs),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(Project project) {
    final tealColor = const Color(0xFF007F7A);
    String machinesText = project.machines.map((m) => '${m.model} × ${m.quantity}').join('\n');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.customerName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF102F46),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Máy:', machinesText),
          const SizedBox(height: 10),
          _buildInfoRow('Địa điểm:', project.location),
          const SizedBox(height: 10),
          _buildInfoRow('Kỹ thuật viên:', project.engineers.join(', ')),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tiến độ:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('\${(project.progress * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.w900, color: tealColor)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: project.progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(tealColor),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF102F46)),
          ),
        ),
      ],
    );
  }

  Widget _buildStageProgress(Project project, List<ProjectLog> logs) {
    final stages = ProjectStage.values;
    final reachedStages = logs.map((e) => e.stage).toSet();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      margin: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: stages.map((stage) {
            final isReached = reachedStages.contains(stage);
            return Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isReached ? const Color(0xFF007F7A) : Colors.grey.shade200,
                    ),
                    child: Icon(
                      isReached ? Icons.check : Icons.circle_outlined,
                      color: isReached ? Colors.white : Colors.grey.shade400,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stage.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isReached ? FontWeight.bold : FontWeight.normal,
                      color: isReached ? const Color(0xFF102F46) : Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTimeline(List<ProjectLog> logs) {
    if (logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: Text('Chưa có nhật ký nào.', style: TextStyle(color: Colors.grey))),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NHẬT KÝ DỰ ÁN',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF102F46),
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return _buildTimelineItem(log, isLast: index == logs.length - 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(ProjectLog log, {required bool isLast}) {
    final tealColor = const Color(0xFF007F7A);
    final dateStr = '${log.createdAt.day.toString().padLeft(2, "0")}/${log.createdAt.month.toString().padLeft(2, "0")}/${log.createdAt.year}';
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: tealColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                )
              else
                const SizedBox(height: 24),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.stage.displayName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF102F46),
                    ),
                  ),
                  if (log.photos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          '[ Khu vực hiển thị Ảnh - Phase 2 ]',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                  if (log.technicalData.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: log.technicalData.entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Text('${e.key}: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Expanded(child: Text('${e.value}', style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  if (log.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Ghi chú:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      log.notes,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text('Bởi: ${log.createdBy}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
