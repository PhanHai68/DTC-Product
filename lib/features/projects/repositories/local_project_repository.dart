import 'project_repository.dart';
import '../models/project.dart';
import '../models/project_log.dart';
import '../models/project_machine.dart';
import '../models/project_stage.dart';

class LocalProjectRepository implements ProjectRepository {
  final List<Project> _projects = [
    Project(
      id: 'p1',
      projectCode: 'PRJ-2026-0901',
      customerName: 'Nhà máy Trà ABC',
      projectName: 'Nâng cấp dây chuyền phân loại trà Oolong',
      location: 'Bảo Lộc, Lâm Đồng',
      startDate: DateTime(2026, 9, 10),
      progress: 0.8,
      status: 'Đang triển khai',
      engineers: ['Kevin', 'Hải'],
      machines: [
        ProjectMachine(
          id: 'm1',
          projectId: 'p1',
          model: 'DF53S',
          quantity: 2,
          serialNumber: 'DF53S-2026-0018',
        ),
      ],
    ),
    Project(
      id: 'p2',
      projectCode: 'PRJ-2026-0815',
      customerName: 'HTX Nông Nghiệp XYZ',
      projectName: 'Lắp đặt máy tách màu gạo xuất khẩu',
      location: 'Cần Thơ',
      startDate: DateTime(2026, 8, 15),
      endDate: DateTime(2026, 8, 25),
      progress: 1.0,
      status: 'Hoàn thành',
      engineers: ['Tuấn'],
      machines: [
        ProjectMachine(
          id: 'm2',
          projectId: 'p2',
          model: 'SC16 Pro',
          quantity: 1,
          serialNumber: 'SC16P-2026-0099',
        ),
      ],
    ),
  ];

  final List<ProjectLog> _logs = [
    ProjectLog(
      id: 'log1',
      projectId: 'p1',
      stage: ProjectStage.delivery,
      createdAt: DateTime(2026, 9, 14, 8, 30),
      createdBy: 'Kevin',
      notes: 'Thiết bị đã được vận chuyển đến nhà máy an toàn.',
    ),
    ProjectLog(
      id: 'log2',
      projectId: 'p1',
      stage: ProjectStage.installation,
      createdAt: DateTime(2026, 9, 15, 14, 00),
      createdBy: 'Hải',
      notes: 'Hoàn thành kết nối:\n- Điện 3 pha\n- Khí nén\n- Đường hút bụi',
    ),
    ProjectLog(
      id: 'log3',
      projectId: 'p1',
      stage: ProjectStage.commissioning,
      createdAt: DateTime(2026, 9, 16, 10, 15),
      createdBy: 'Kevin',
      notes: 'Chương trình hoạt động ổn định.',
      technicalData: {
        'Nguyên liệu': 'Trà Oolong',
        'Công suất test': '650 kg/h',
        'Áp suất khí': '0.6 MPa',
      },
    ),
  ];

  @override
  Future<List<Project>> getProjects() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _projects;
  }

  @override
  Future<Project?> getProjectById(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _projects.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<ProjectLog>> getProjectLogs(String projectId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final logs = _logs.where((l) => l.projectId == projectId).toList();
    // Sort descending by date
    logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return logs;
  }

  @override
  Future<void> addProjectLog(ProjectLog log) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _logs.insert(0, log);
  }
}
