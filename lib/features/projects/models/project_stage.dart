enum ProjectStage {
  delivery,          // Giao hàng
  unpacking,         // Mở kiện / kiểm tra thiết bị
  installation,      // Lắp đặt
  commissioning,     // Chạy thử
  training,          // Đào tạo vận hành
  acceptance,        // Nghiệm thu
  maintenance,       // Bảo trì
  issue              // Sự cố
}

extension ProjectStageExtension on ProjectStage {
  String get displayName {
    switch (this) {
      case ProjectStage.delivery: return 'Giao hàng';
      case ProjectStage.unpacking: return 'Mở kiện';
      case ProjectStage.installation: return 'Lắp đặt';
      case ProjectStage.commissioning: return 'Chạy thử';
      case ProjectStage.training: return 'Đào tạo';
      case ProjectStage.acceptance: return 'Nghiệm thu';
      case ProjectStage.maintenance: return 'Bảo trì';
      case ProjectStage.issue: return 'Sự cố';
    }
  }
}
