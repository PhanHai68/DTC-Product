import '../engine/grain_analyzer.dart';
import '../engine/tray_layout.dart';

/// Web: không hỗ trợ (xử lý ảnh 12 MP trên trình duyệt quá chậm).
class GrainAnalysisRunner {
  const GrainAnalysisRunner();

  Future<GrainImageAnalysis> analyzeFile(
    String path, {
    required TrayLayout layout,
    int imageIndex = 0,
    double? minPixelsPerMm,
    AnalysisProgress? onProgress,
  }) => throw UnsupportedError(
    'Phân tích mẫu AI chỉ dùng trên ứng dụng Android/iOS.',
  );
}
