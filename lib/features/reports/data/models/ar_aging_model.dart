// ============================================
// Aging buckets
// ============================================
enum ArAgingBucket {
  current, // لم يستحق بعد (days < 0)
  days1To30, // 0-30 يوم متأخر
  days31To60, // 31-60
  days61To90, // 61-90
  over90, // +90
}

extension ArAgingBucketX on ArAgingBucket {
  String get labelKey {
    switch (this) {
      case ArAgingBucket.current:
        return 'aging_current';
      case ArAgingBucket.days1To30:
        return 'aging_1_30';
      case ArAgingBucket.days31To60:
        return 'aging_31_60';
      case ArAgingBucket.days61To90:
        return 'aging_61_90';
      case ArAgingBucket.over90:
        return 'aging_90_plus';
    }
  }
}

// ============================================
// Row per customer
// ============================================
class ArAgingCustomerRow {
  final String customerId;
  final String? customerCode;
  final String customerName;
  final String? phone;

  final double current;
  final double days1To30;
  final double days31To60;
  final double days61To90;
  final double over90;

  final int invoiceCount;
  final DateTime? oldestDueDate;

  const ArAgingCustomerRow({
    required this.customerId,
    this.customerCode,
    required this.customerName,
    this.phone,
    this.current = 0,
    this.days1To30 = 0,
    this.days31To60 = 0,
    this.days61To90 = 0,
    this.over90 = 0,
    this.invoiceCount = 0,
    this.oldestDueDate,
  });

  double get totalOutstanding =>
      current + days1To30 + days31To60 + days61To90 + over90;

  double get overdueOnly => days1To30 + days31To60 + days61To90 + over90;

  bool get hasOverdue => overdueOnly > 0.001;
}

// ============================================
// Full report
// ============================================
class ArAgingModel {
  final DateTime asOfDate;
  final List<ArAgingCustomerRow> rows;

  final double totalCurrent;
  final double total1To30;
  final double total31To60;
  final double total61To90;
  final double totalOver90;
  final double grandTotal;

  const ArAgingModel({
    required this.asOfDate,
    this.rows = const [],
    this.totalCurrent = 0,
    this.total1To30 = 0,
    this.total31To60 = 0,
    this.total61To90 = 0,
    this.totalOver90 = 0,
    this.grandTotal = 0,
  });

  int get customerCount => rows.length;
  int get totalInvoices => rows.fold(0, (s, r) => s + r.invoiceCount);

  double get totalOverdue =>
      total1To30 + total31To60 + total61To90 + totalOver90;

  double get overduePercent =>
      grandTotal <= 0 ? 0 : (totalOverdue / grandTotal) * 100;

  factory ArAgingModel.fromRows(
    DateTime asOfDate,
    List<ArAgingCustomerRow> rows,
  ) {
    double cur = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0;
    for (final r in rows) {
      cur += r.current;
      b1 += r.days1To30;
      b2 += r.days31To60;
      b3 += r.days61To90;
      b4 += r.over90;
    }
    return ArAgingModel(
      asOfDate: asOfDate,
      rows: rows,
      totalCurrent: cur,
      total1To30: b1,
      total31To60: b2,
      total61To90: b3,
      totalOver90: b4,
      grandTotal: cur + b1 + b2 + b3 + b4,
    );
  }
}
