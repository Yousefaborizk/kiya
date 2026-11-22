class WarehouseModel {
  final String id;
  final String name;
  final String? location;
  final String? branchId;
  final String? managerId;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WarehouseModel({
    required this.id,
    required this.name,
    this.location,
    this.branchId,
    this.managerId,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    return WarehouseModel(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String?,
      branchId: json['branch_id'] as String?,
      managerId: json['manager_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'location': location,
      'branch_id': branchId,
      'manager_id': managerId,
      'is_active': isActive,
      'notes': notes,
    };
  }
}
