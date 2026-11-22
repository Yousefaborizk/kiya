class ProductModel {
  final String id;
  final String? productCode;
  final String name;
  final String? categoryId;
  final String? description;
  final String? notes;
  final String unit;
  final double purchasePrice;
  final double sellingPrice;
  final int minStockLevel;
  final String? imageUrl;
  final bool isActive;
  final String? branchId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    this.productCode,
    required this.name,
    this.categoryId,
    this.description,
    this.notes,
    this.unit = 'قطعة',
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.minStockLevel = 0,
    this.imageUrl,
    this.isActive = true,
    this.branchId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      productCode: json['product_code'] as String?,
      name: json['name'] as String,
      categoryId: json['category_id'] as String?,
      description: json['description'] as String?,
      notes: json['notes'] as String?,
      unit: json['unit'] as String? ?? 'قطعة',
      purchasePrice: (json['purchase_price'] as num?)?.toDouble() ?? 0,
      sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0,
      minStockLevel: (json['min_stock_level'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      branchId: json['branch_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_code': productCode,
      'name': name,
      'category_id': categoryId,
      'description': description,
      'notes': notes,
      'unit': unit,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'min_stock_level': minStockLevel,
      'image_url': imageUrl,
      'is_active': isActive,
      'branch_id': branchId,
    };
  }

  ProductModel copyWith({
    String? id,
    String? productCode,
    String? name,
    String? categoryId,
    String? description,
    String? notes,
    String? unit,
    double? purchasePrice,
    double? sellingPrice,
    int? minStockLevel,
    String? imageUrl,
    bool? isActive,
    String? branchId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      productCode: productCode ?? this.productCode,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      branchId: branchId ?? this.branchId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
