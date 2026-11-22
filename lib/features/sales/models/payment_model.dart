class PaymentModel {
  final String id;
  final String invoiceId;
  final double amount;
  final DateTime paymentDate;
  final String? paymentMethod;
  final String? reference;
  final String? notes;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.paymentDate,
    this.paymentMethod,
    this.reference,
    this.notes,
    required this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String,
      invoiceId: json['invoice_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(json['payment_date'] as String),
      paymentMethod: json['payment_method'] as String?,
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_id': invoiceId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String().split('T').first,
      'payment_method': paymentMethod,
      'reference': reference,
      'notes': notes,
    };
  }
}
