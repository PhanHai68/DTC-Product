// Chọn bản lưu ảnh theo nền tảng: Android/iOS (io) hoặc stub (web).
export 'fault_file_storage_stub.dart'
    if (dart.library.io) 'fault_file_storage_io.dart';
