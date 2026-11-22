class InventoryStockModel {
  final String id;
  final String productId;
  final String warehouseId;
  final double quantity;
  final DateTime lastUpdatedAt;

  const InventoryStockModel({
    required this.id,
    required this.productId,
    required this.warehouseId,
    required this.quantity,
    required this.lastUpdatedAt,
  });

  factory InventoryStockModel.fromJson(Map<String, dynamic> json) {
    return InventoryStockModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      warehouseId: json['warehouse_id'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      lastUpdatedAt: DateTime.parse(json['last_updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'warehouse_id': warehouseId,
      'quantity': quantity,
    };
  }
}
