class AccountModel {
  final String id;
  final String code;
  final String name;
  final String? nameEn;
  final String? nameZh;
  final String accountType; // asset, liability, equity, revenue, expense
  final String? parentId;
  final bool isActive;
  final bool isSystem;
  final double openingBalance;
  final String currency;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AccountModel({
    required this.id,
    required this.code,
    required this.name,
    this.nameEn,
    this.nameZh,
    required this.accountType,
    this.parentId,
    this.isActive = true,
    this.isSystem = false,
    this.openingBalance = 0,
    this.currency = 'EGP',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      nameEn: json['name_en'] as String?,
      nameZh: json['name_zh'] as String?,
      accountType: json['account_type'] as String,
      parentId: json['parent_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isSystem: json['is_system'] as bool? ?? false,
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'EGP',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'name_en': nameEn,
      'name_zh': nameZh,
      'account_type': accountType,
      'parent_id': parentId,
      'is_active': isActive,
      'opening_balance': openingBalance,
      'currency': currency,
      'notes': notes,
    };
  }

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

  AccountModel copyWith({
    String? id,
    String? code,
    String? name,
    String? nameEn,
    String? nameZh,
    String? accountType,
    String? parentId,
    bool? isActive,
    bool? isSystem,
    double? openingBalance,
    String? currency,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      nameZh: nameZh ?? this.nameZh,
      accountType: accountType ?? this.accountType,
      parentId: parentId ?? this.parentId,
      isActive: isActive ?? this.isActive,
      isSystem: isSystem ?? this.isSystem,
      openingBalance: openingBalance ?? this.openingBalance,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
