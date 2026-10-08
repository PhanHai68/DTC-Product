// Chọn bản chạy phân tích theo nền tảng: isolate riêng (io) hoặc stub (web).
export 'grain_analysis_runner_stub.dart'
    if (dart.library.io) 'grain_analysis_runner_io.dart';
