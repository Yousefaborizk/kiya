class ProductImageModel {
  final String id;
  final String productId;
  final String imageUrl;
  final int sortOrder;
  final DateTime createdAt;

  const ProductImageModel({
    required this.id,
    required this.productId,
    required this.imageUrl,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory ProductImageModel.fromJson(Map<String, dynamic> json) {
    return ProductImageModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      imageUrl: json['image_url'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'image_url': imageUrl,
      'sort_order': sortOrder,
    };
  }
}
