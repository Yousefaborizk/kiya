// ============================================
// Severity levels
// ============================================
enum LowStockSeverity {
  outOfStock, // current = 0
  critical, // current < min * 0.5
  low, // current < min
}

extension LowStockSeverityX on LowStockSeverity {
  String get labelKey {
    switch (this) {
      case LowStockSeverity.outOfStock:
        return 'severity_out_of_stock';
      case LowStockSeverity.critical:
        return 'severity_critical';
      case LowStockSeverity.low:
        return 'severity_low';
    }
  }
}

// ============================================
// Row per product
// ============================================
class LowStockRow {
  final String productId;
  final String productCode;
  final String productName;
  final String unit;
  final double currentStock;
  final int minStockLevel;
  final double shortfall;
  final LowStockSeverity severity;
  final DateTime? lastUpdatedAt;

  const LowStockRow({
    required this.productId,
    required this.productCode,
    required this.productName,
    this.unit = 'قطعة',
    this.currentStock = 0,
    this.minStockLevel = 0,
    this.shortfall = 0,
    this.severity = LowStockSeverity.low,
    this.lastUpdatedAt,
  });

  double get fillPercentage =>
      minStockLevel > 0 ? (currentStock / minStockLevel).clamp(0.0, 1.0) : 1.0;

  bool get isOutOfStock => currentStock.abs() < 0.001;
}

// ============================================
// Sort options
// ============================================
enum LowStockSort {
  severityDesc, // out → critical → low
  shortfallDesc,
  nameAsc,
}

extension LowStockSortX on LowStockSort {
  String get labelKey {
    switch (this) {
      case LowStockSort.severityDesc:
        return 'sort_by_severity';
      case LowStockSort.shortfallDesc:
        return 'sort_by_shortfall';
      case LowStockSort.nameAsc:
        return 'sort_by_name';
    }
  }
}

// ============================================
// Full report
// ============================================
class LowStockModel {
  final DateTime asOfDate;
  final List<LowStockRow> rows;

  const LowStockModel({
    required this.asOfDate,
    this.rows = const [],
  });

  int get totalCount => rows.length;

  int get outOfStockCount =>
      rows.where((r) => r.severity == LowStockSeverity.outOfStock).length;

  int get criticalCount =>
      rows.where((r) => r.severity == LowStockSeverity.critical).length;

  int get lowCount =>
      rows.where((r) => r.severity == LowStockSeverity.low).length;

  double get totalShortfall => rows.fold(0.0, (s, r) => s + r.shortfall);

  LowStockModel sortedBy(LowStockSort sort) {
    final copy = List<LowStockRow>.from(rows);
    switch (sort) {
      case LowStockSort.severityDesc:
        copy.sort((a, b) {
          final s = a.severity.index.compareTo(b.severity.index);
          if (s != 0) return s;
          return b.shortfall.compareTo(a.shortfall);
        });
        break;
      case LowStockSort.shortfallDesc:
        copy.sort((a, b) => b.shortfall.compareTo(a.shortfall));
        break;
      case LowStockSort.nameAsc:
        copy.sort((a, b) => a.productName.compareTo(b.productName));
        break;
    }
    return LowStockModel(asOfDate: asOfDate, rows: copy);
  }

  factory LowStockModel.fromRows(
    DateTime asOfDate,
    List<LowStockRow> rows,
  ) {
    final sorted = List<LowStockRow>.from(rows)
      ..sort((a, b) {
        final s = a.severity.index.compareTo(b.severity.index);
        if (s != 0) return s;
        return b.shortfall.compareTo(a.shortfall);
      });
    return LowStockModel(asOfDate: asOfDate, rows: sorted);
  }
}
