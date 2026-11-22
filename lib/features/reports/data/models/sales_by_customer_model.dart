// ============================================
// Row per customer
// ============================================
class SalesByCustomerRow {
  final String? customerId;
  final String? customerCode;
  final String customerName;
  final String? phone;
  final int invoiceCount;
  final double grossAmount;
  final double discountAmount;
  final double netAmount;

  const SalesByCustomerRow({
    this.customerId,
    this.customerCode,
    required this.customerName,
    this.phone,
    this.invoiceCount = 0,
    this.grossAmount = 0,
    this.discountAmount = 0,
    this.netAmount = 0,
  });

  double get averageInvoiceValue =>
      invoiceCount > 0 ? netAmount / invoiceCount : 0;

  bool get hasSales => netAmount.abs() > 0.001 || invoiceCount > 0;
}

// ============================================
// Sort options
// ============================================
enum SalesByCustomerSort {
  revenueDesc,
  invoicesDesc,
  nameAsc,
}

extension SalesByCustomerSortX on SalesByCustomerSort {
  String get labelKey {
    switch (this) {
      case SalesByCustomerSort.revenueDesc:
        return 'sort_by_revenue';
      case SalesByCustomerSort.invoicesDesc:
        return 'sort_by_invoices';
      case SalesByCustomerSort.nameAsc:
        return 'sort_by_name';
    }
  }
}

// ============================================
// Full report
// ============================================
class SalesByCustomerModel {
  final DateTime fromDate;
  final DateTime toDate;
  final List<SalesByCustomerRow> rows;

  final double totalGross;
  final double totalDiscount;
  final double totalNet;
  final int totalInvoices;

  const SalesByCustomerModel({
    required this.fromDate,
    required this.toDate,
    this.rows = const [],
    this.totalGross = 0,
    this.totalDiscount = 0,
    this.totalNet = 0,
    this.totalInvoices = 0,
  });

  int get customerCount => rows.length;

  double get averagePerCustomer =>
      customerCount > 0 ? totalNet / customerCount : 0;

  double get averageInvoiceValue =>
      totalInvoices > 0 ? totalNet / totalInvoices : 0;

  SalesByCustomerModel sortedBy(SalesByCustomerSort sort) {
    final copy = List<SalesByCustomerRow>.from(rows);
    switch (sort) {
      case SalesByCustomerSort.revenueDesc:
        copy.sort((a, b) => b.netAmount.compareTo(a.netAmount));
        break;
      case SalesByCustomerSort.invoicesDesc:
        copy.sort((a, b) => b.invoiceCount.compareTo(a.invoiceCount));
        break;
      case SalesByCustomerSort.nameAsc:
        copy.sort((a, b) => a.customerName.compareTo(b.customerName));
        break;
    }
    return SalesByCustomerModel(
      fromDate: fromDate,
      toDate: toDate,
      rows: copy,
      totalGross: totalGross,
      totalDiscount: totalDiscount,
      totalNet: totalNet,
      totalInvoices: totalInvoices,
    );
  }

  factory SalesByCustomerModel.fromRows(
    DateTime fromDate,
    DateTime toDate,
    List<SalesByCustomerRow> rows,
  ) {
    double totalGross = 0;
    double totalDiscount = 0;
    double totalNet = 0;
    int totalInvoices = 0;

    for (final r in rows) {
      totalGross += r.grossAmount;
      totalDiscount += r.discountAmount;
      totalNet += r.netAmount;
      totalInvoices += r.invoiceCount;
    }

    final sorted = List<SalesByCustomerRow>.from(rows)
      ..sort((a, b) => b.netAmount.compareTo(a.netAmount));

    return SalesByCustomerModel(
      fromDate: fromDate,
      toDate: toDate,
      rows: sorted,
      totalGross: totalGross,
      totalDiscount: totalDiscount,
      totalNet: totalNet,
      totalInvoices: totalInvoices,
    );
  }
}
