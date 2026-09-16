import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/project_provider.dart';
import '../models/project.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProjectProvider>().loadProjects();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final theme = Theme.of(context);
    final tealColor = const Color(0xFF007F7A);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F9),
      appBar: AppBar(
        title: const Text('THEO DÕI DỰ ÁN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF102F46),
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm dự án...',
                    prefixIcon: Icon(Icons.search, color: tealColor),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: tealColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: tealColor,
                tabs: const [
                  Tab(text: 'Tất cả'),
                  Tab(text: 'Đang triển khai'),
                  Tab(text: 'Hoàn thành'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: provider.isLoadingProjects
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
              ? Center(child: Text(provider.error!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProjectList(provider.projects),
                    _buildProjectList(provider.projects.where((p) => p.status != 'Hoàn thành').toList()),
                    _buildProjectList(provider.projects.where((p) => p.status == 'Hoàn thành').toList()),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tính năng thêm dự án đang phát triển (Phase 2)')),
          );
        },
        backgroundColor: tealColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildProjectList(List<Project> projects) {
    if (projects.isEmpty) {
      return const Center(child: Text('Không có dự án nào.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return _buildProjectCard(context, project);
      },
    );
  }

  Widget _buildProjectCard(BuildContext context, Project project) {
    final tealColor = const Color(0xFF007F7A);
    final isCompleted = project.progress >= 1.0;
    
    String machinesText = project.machines.map((m) => '\${m.model} × \${m.quantity}').join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () {
          context.push('/projects/${project.id}');
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      project.customerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF102F46),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isCompleted ? 'Hoàn thành' : 'Đang triển khai',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isCompleted ? Colors.green.shade700 : Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                project.projectName,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.precision_manufacturing, size: 16, color: Colors.blueGrey.shade400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      machinesText.isNotEmpty ? machinesText : 'Chưa có thông tin máy',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tiến độ: ${(project.progress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: project.progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(tealColor),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    project.location,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${project.startDate.day}/${project.startDate.month}/${project.startDate.year}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
