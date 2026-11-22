class JobTitleModel {
  final String id;
  final String name;
  final String? nameEn;
  final String? nameZh;
  final String? departmentId;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JobTitleModel({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameZh,
    this.departmentId,
    this.description,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JobTitleModel.fromJson(Map<String, dynamic> json) {
    return JobTitleModel(
      id: json['id'] as String,
      name: json['name'] as String,
      nameEn: json['name_en'] as String?,
      nameZh: json['name_zh'] as String?,
      departmentId: json['department_id'] as String?,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'name_en': nameEn,
      'name_zh': nameZh,
      'department_id': departmentId,
      'description': description,
      'is_active': isActive,
    };
  }

  /// بيرجع الاسم حسب اللغة الممررة
  String getLocalizedName(String langCode) {
    switch (langCode) {
      case 'en':
        return nameEn ?? name;
      case 'zh':
        return nameZh ?? name;
      default:
        return name;
    }
  }

  JobTitleModel copyWith({
    String? id,
    String? name,
    String? nameEn,
    String? nameZh,
    String? departmentId,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobTitleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      nameZh: nameZh ?? this.nameZh,
      departmentId: departmentId ?? this.departmentId,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
