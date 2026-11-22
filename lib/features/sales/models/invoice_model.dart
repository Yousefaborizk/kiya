import 'invoice_item_model.dart';

class InvoiceModel {
  final String id;
  final String? invoiceNumber;
  final String? customerId;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double paidAmount;
  final String status; // draft, issued, paid, partially_paid, cancelled
  final String? paymentMethod;
  final String? notes;
  final String? branchId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // حقول إضافية للعرض
  final String? customerName;
  final List<InvoiceItemModel>? items;

  const InvoiceModel({
    required this.id,
    this.invoiceNumber,
    this.customerId,
    required this.invoiceDate,
    this.dueDate,
    this.subtotal = 0,
    this.discount = 0,
    this.tax = 0,
    this.total = 0,
    this.paidAmount = 0,
    this.status = 'draft',
    this.paymentMethod,
    this.notes,
    this.branchId,
    required this.createdAt,
    required this.updatedAt,
    this.customerName,
    this.items,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as String,
      invoiceNumber: json['invoice_number'] as String?,
      customerId: json['customer_id'] as String?,
      invoiceDate: DateTime.parse(json['invoice_date'] as String),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'draft',
      paymentMethod: json['payment_method'] as String?,
      notes: json['notes'] as String?,
      branchId: json['branch_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // لو جبنا بيانات العميل مع join
      customerName: json['customers'] != null
          ? (json['customers'] as Map<String, dynamic>)['name'] as String?
          : null,
      // لو جبنا البنود مع join
      items: json['invoice_items'] != null
          ? (json['invoice_items'] as List)
              .map((e) => InvoiceItemModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'invoice_date': invoiceDate.toIso8601String().split('T').first,
      'due_date': dueDate?.toIso8601String().split('T').first,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'paid_amount': paidAmount,
      'status': status,
      'payment_method': paymentMethod,
      'notes': notes,
      'branch_id': branchId,
    };
  }

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'issued':
        return 'Issued';
      case 'partially_paid':
        return 'Partially Paid';
      case 'paid':
        return 'Paid';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
