enum InvoiceRegisterStatus {
  all,
  draft,
  issued,
  partiallyPaid,
  paid,
  cancelled
}

extension InvoiceRegisterStatusX on InvoiceRegisterStatus {
  String get dbValue {
    switch (this) {
      case InvoiceRegisterStatus.draft:
        return 'draft';
      case InvoiceRegisterStatus.issued:
        return 'issued';
      case InvoiceRegisterStatus.partiallyPaid:
        return 'partially_paid';
      case InvoiceRegisterStatus.paid:
        return 'paid';
      case InvoiceRegisterStatus.cancelled:
        return 'cancelled';
      case InvoiceRegisterStatus.all:
        return '';
    }
  }

  String get labelKey {
    switch (this) {
      case InvoiceRegisterStatus.draft:
        return 'status_draft';
      case InvoiceRegisterStatus.issued:
        return 'status_issued';
      case InvoiceRegisterStatus.partiallyPaid:
        return 'status_partially_paid';
      case InvoiceRegisterStatus.paid:
        return 'status_paid';
      case InvoiceRegisterStatus.cancelled:
        return 'status_cancelled';
      case InvoiceRegisterStatus.all:
        return 'all';
    }
  }
}

class InvoiceRegisterRow {
  final String id;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final String? customerId;
  final String? customerCode;
  final String? customerName;
  final String status;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double paidAmount;

  const InvoiceRegisterRow({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.dueDate,
    this.customerId,
    this.customerCode,
    this.customerName,
    required this.status,
    this.subtotal = 0,
    this.discount = 0,
    this.tax = 0,
    this.total = 0,
    this.paidAmount = 0,
  });

  double get remaining => (total - paidAmount).clamp(0.0, double.infinity);
  bool get isPaid => remaining.abs() < 0.01;
  bool get isCancelled => status == 'cancelled';

  bool get isOverdue {
    if (dueDate == null || isPaid || isCancelled) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  int? get daysOverdue {
    if (!isOverdue) return null;
    return DateTime.now().difference(dueDate!).inDays;
  }
}

enum InvoiceRegisterSort { dateDesc, dateAsc, totalDesc, remainingDesc }

extension InvoiceRegisterSortX on InvoiceRegisterSort {
  String get labelKey {
    switch (this) {
      case InvoiceRegisterSort.dateDesc:
        return 'sort_newest_first';
      case InvoiceRegisterSort.dateAsc:
        return 'sort_oldest_first';
      case InvoiceRegisterSort.totalDesc:
        return 'sort_total_desc';
      case InvoiceRegisterSort.remainingDesc:
        return 'sort_remaining_desc';
    }
  }
}

class InvoiceRegisterModel {
  final DateTime fromDate;
  final DateTime toDate;
  final List<InvoiceRegisterRow> rows;

  final double totalAmount;
  final double totalPaid;
  final double totalRemaining;
  final double totalDiscount;
  final double totalTax;
  final int invoiceCount;
  final int paidCount;
  final int unpaidCount;
  final int overdueCount;

  const InvoiceRegisterModel({
    required this.fromDate,
    required this.toDate,
    this.rows = const [],
    this.totalAmount = 0,
    this.totalPaid = 0,
    this.totalRemaining = 0,
    this.totalDiscount = 0,
    this.totalTax = 0,
    this.invoiceCount = 0,
    this.paidCount = 0,
    this.unpaidCount = 0,
    this.overdueCount = 0,
  });

  InvoiceRegisterModel sortedBy(InvoiceRegisterSort sort) {
    final copy = List<InvoiceRegisterRow>.from(rows);
    switch (sort) {
      case InvoiceRegisterSort.dateDesc:
        copy.sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
        break;
      case InvoiceRegisterSort.dateAsc:
        copy.sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));
        break;
      case InvoiceRegisterSort.totalDesc:
        copy.sort((a, b) => b.total.compareTo(a.total));
        break;
      case InvoiceRegisterSort.remainingDesc:
        copy.sort((a, b) => b.remaining.compareTo(a.remaining));
        break;
    }
    return InvoiceRegisterModel(
      fromDate: fromDate,
      toDate: toDate,
      rows: copy,
      totalAmount: totalAmount,
      totalPaid: totalPaid,
      totalRemaining: totalRemaining,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      invoiceCount: invoiceCount,
      paidCount: paidCount,
      unpaidCount: unpaidCount,
      overdueCount: overdueCount,
    );
  }

  factory InvoiceRegisterModel.fromRows(
    DateTime fromDate,
    DateTime toDate,
    List<InvoiceRegisterRow> rows,
  ) {
    double totalAmount = 0, totalPaid = 0, totalDiscount = 0, totalTax = 0;
    int paidCount = 0, unpaidCount = 0, overdueCount = 0;

    for (final r in rows) {
      if (r.isCancelled) continue;
      totalAmount += r.total;
      totalPaid += r.paidAmount;
      totalDiscount += r.discount;
      totalTax += r.tax;
      if (r.isPaid) {
        paidCount++;
      } else {
        unpaidCount++;
        if (r.isOverdue) overdueCount++;
      }
    }

    final sorted = List<InvoiceRegisterRow>.from(rows)
      ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));

    return InvoiceRegisterModel(
      fromDate: fromDate,
      toDate: toDate,
      rows: sorted,
      totalAmount: totalAmount,
      totalPaid: totalPaid,
      totalRemaining: totalAmount - totalPaid,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      invoiceCount: rows.length,
      paidCount: paidCount,
      unpaidCount: unpaidCount,
      overdueCount: overdueCount,
    );
  }
}
