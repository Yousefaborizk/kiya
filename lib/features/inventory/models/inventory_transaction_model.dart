class InventoryTransactionModel {
  final String id;
  final String productId;
  final String warehouseId;
  final String transactionType; // in, out, adjustment
  final double quantity;
  final double unitPrice;
  final String? referenceType;
  final String? referenceId;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;

  const InventoryTransactionModel({
    required this.id,
    required this.productId,
    required this.warehouseId,
    required this.transactionType,
    required this.quantity,
    this.unitPrice = 0,
    this.referenceType,
    this.referenceId,
    this.notes,
    this.createdBy,
    required this.createdAt,
  });

  factory InventoryTransactionModel.fromJson(Map<String, dynamic> json) {
    return InventoryTransactionModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      warehouseId: json['warehouse_id'] as String,
      transactionType: json['transaction_type'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'warehouse_id': warehouseId,
      'transaction_type': transactionType,
      'quantity': quantity,
      'unit_price': unitPrice,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'notes': notes,
    };
  }
}
