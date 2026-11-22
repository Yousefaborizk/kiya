// ============================================
// Row per product
// ============================================
class SalesByProductRow {
  final String? productId;
  final String productCode;
  final String productName;
  final String unit;
  final double quantitySold;
  final double grossAmount;
  final double discountAmount;
  final double netAmount;
  final int invoiceCount;

  const SalesByProductRow({
    this.productId,
    required this.productCode,
    required this.productName,
    this.unit = 'قطعة',
    this.quantitySold = 0,
    this.grossAmount = 0,
    this.discountAmount = 0,
    this.netAmount = 0,
    this.invoiceCount = 0,
  });

  double get averagePrice =>
      quantitySold > 0.001 ? netAmount / quantitySold : 0;

  bool get hasSales => netAmount.abs() > 0.001 || quantitySold.abs() > 0.001;
}

// ============================================
// Sort options
// ============================================
enum SalesByProductSort {
  revenueDesc,
  quantityDesc,
  invoicesDesc,
  nameAsc,
}

extension SalesByProductSortX on SalesByProductSort {
  String get labelKey {
    switch (this) {
      case SalesByProductSort.revenueDesc:
        return 'sort_by_revenue';
      case SalesByProductSort.quantityDesc:
        return 'sort_by_quantity';
      case SalesByProductSort.invoicesDesc:
        return 'sort_by_invoices';
      case SalesByProductSort.nameAsc:
        return 'sort_by_name';
    }
  }
}

// ============================================
// Full report
// ============================================
class SalesByProductModel {
  final DateTime fromDate;
  final DateTime toDate;
  final List<SalesByProductRow> rows;

  final double totalQuantity;
  final double totalGross;
  final double totalDiscount;
  final double totalNet;
  final int totalInvoices;

  const SalesByProductModel({
    required this.fromDate,
    required this.toDate,
    this.rows = const [],
    this.totalQuantity = 0,
    this.totalGross = 0,
    this.totalDiscount = 0,
    this.totalNet = 0,
    this.totalInvoices = 0,
  });

  int get productCount => rows.length;

  double get averagePerProduct =>
      productCount > 0 ? totalNet / productCount : 0;

  SalesByProductModel sortedBy(SalesByProductSort sort) {
    final copy = List<SalesByProductRow>.from(rows);
    switch (sort) {
      case SalesByProductSort.revenueDesc:
        copy.sort((a, b) => b.netAmount.compareTo(a.netAmount));
        break;
      case SalesByProductSort.quantityDesc:
        copy.sort((a, b) => b.quantitySold.compareTo(a.quantitySold));
        break;
      case SalesByProductSort.invoicesDesc:
        copy.sort((a, b) => b.invoiceCount.compareTo(a.invoiceCount));
        break;
      case SalesByProductSort.nameAsc:
        copy.sort((a, b) => a.productName.compareTo(b.productName));
        break;
    }
    return SalesByProductModel(
      fromDate: fromDate,
      toDate: toDate,
      rows: copy,
      totalQuantity: totalQuantity,
      totalGross: totalGross,
      totalDiscount: totalDiscount,
      totalNet: totalNet,
      totalInvoices: totalInvoices,
    );
  }

  factory SalesByProductModel.fromRows(
    DateTime fromDate,
    DateTime toDate,
    List<SalesByProductRow> rows,
  ) {
    double totalQty = 0;
    double totalGross = 0;
    double totalDiscount = 0;
    double totalNet = 0;
    int totalInvoices = 0;

    for (final r in rows) {
      totalQty += r.quantitySold;
      totalGross += r.grossAmount;
      totalDiscount += r.discountAmount;
      totalNet += r.netAmount;
      totalInvoices += r.invoiceCount;
    }

    // ترتيب افتراضي حسب الإيراد
    final sorted = List<SalesByProductRow>.from(rows)
      ..sort((a, b) => b.netAmount.compareTo(a.netAmount));

    return SalesByProductModel(
      fromDate: fromDate,
      toDate: toDate,
      rows: sorted,
      totalQuantity: totalQty,
      totalGross: totalGross,
      totalDiscount: totalDiscount,
      totalNet: totalNet,
      totalInvoices: totalInvoices,
    );
  }
}
