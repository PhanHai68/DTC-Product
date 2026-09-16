class ProjectMachine {
  final String id;
  final String projectId;
  final String model;
  final int quantity;
  final String? serialNumber;

  ProjectMachine({
    required this.id,
    required this.projectId,
    required this.model,
    required this.quantity,
    this.serialNumber,
  });

  factory ProjectMachine.fromJson(Map<String, dynamic> json) {
    return ProjectMachine(
      id: json['id'] as String,
      projectId: json['projectId'] as String,
      model: json['model'] as String,
      quantity: json['quantity'] as int,
      serialNumber: json['serialNumber'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'model': model,
      'quantity': quantity,
      'serialNumber': serialNumber,
    };
  }
}
