class InvoiceItemModel {
  final String id;
  final String invoiceId;
  final String? productId;
  final String? warehouseId; // 👈 ضفنا دي
  final double quantity;
  final double unitPrice;
  final double discount;
  final double total;
  final DateTime createdAt;

  // حقول إضافية للعرض
  final String? productName;
  final String? warehouseName; // 👈 ضفنا دي للعرض

  const InvoiceItemModel({
    required this.id,
    required this.invoiceId,
    this.productId,
    this.warehouseId,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    required this.total,
    required this.createdAt,
    this.productName,
    this.warehouseName,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceItemModel(
      id: json['id'] as String,
      invoiceId: json['invoice_id'] as String,
      productId: json['product_id'] as String?,
      warehouseId: json['warehouse_id'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      productName: json['products'] != null
          ? (json['products'] as Map<String, dynamic>)['name'] as String?
          : null,
      warehouseName: json['warehouses'] != null
          ? (json['warehouses'] as Map<String, dynamic>)['name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_id': invoiceId,
      'product_id': productId,
      'warehouse_id': warehouseId, // 👈 مهم جداً للداتابيز
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount': discount,
      'total': total,
    };
  }

  InvoiceItemModel copyWith({
    String? id,
    String? invoiceId,
    String? productId,
    String? warehouseId,
    double? quantity,
    double? unitPrice,
    double? discount,
    double? total,
    DateTime? createdAt,
    String? productName,
    String? warehouseName,
  }) {
    return InvoiceItemModel(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      productId: productId ?? this.productId,
      warehouseId: warehouseId ?? this.warehouseId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      productName: productName ?? this.productName,
      warehouseName: warehouseName ?? this.warehouseName,
    );
  }
}
