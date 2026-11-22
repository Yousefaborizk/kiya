class ProductCategoryModel {
  final String id;
  final String name;
  final String? nameEn;
  final String? nameZh;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductCategoryModel({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameZh,
    this.description,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductCategoryModel.fromJson(Map<String, dynamic> json) {
    return ProductCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      nameEn: json['name_en'] as String?,
      nameZh: json['name_zh'] as String?,
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
      'description': description,
      'is_active': isActive,
    };
  }

  /// بيرجع الاسم حسب اللغة
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

  ProductCategoryModel copyWith({
    String? id,
    String? name,
    String? nameEn,
    String? nameZh,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      nameZh: nameZh ?? this.nameZh,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
