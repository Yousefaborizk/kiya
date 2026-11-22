// ============================================
// Movement type
// ============================================
enum StockMovementType { in_, out, adjustment }

extension StockMovementTypeX on StockMovementType {
  String get dbValue {
    switch (this) {
      case StockMovementType.in_:
        return 'in';
      case StockMovementType.out:
        return 'out';
      case StockMovementType.adjustment:
        return 'adjustment';
    }
  }

  String get labelKey {
    switch (this) {
      case StockMovementType.in_:
        return 'in';
      case StockMovementType.out:
        return 'out';
      case StockMovementType.adjustment:
        return 'adjustment';
    }
  }

  static StockMovementType fromDb(String v) {
    switch (v) {
      case 'in':
        return StockMovementType.in_;
      case 'out':
        return StockMovementType.out;
      default:
        return StockMovementType.adjustment;
    }
  }
}

// ============================================
// Row
// ============================================
class StockMovementRow {
  final String id;
  final DateTime date;
  final String productId;
  final String productCode;
  final String productName;
  final String unit;
  final String warehouseId;
  final String warehouseName;
  final StockMovementType type;
  final double quantity;
  final double unitPrice;
  final double totalValue;
  final String? referenceType;
  final String? notes;

  const StockMovementRow({
    required this.id,
    required this.date,
    required this.productId,
    required this.productCode,
    required this.productName,
    this.unit = 'قطعة',
    required this.warehouseId,
    required this.warehouseName,
    required this.type,
    this.quantity = 0,
    this.unitPrice = 0,
    this.totalValue = 0,
    this.referenceType,
    this.notes,
  });

  double get signedQuantity =>
      type == StockMovementType.out ? -quantity : quantity;
}

// ============================================
// Sort
// ============================================
enum StockMovementSort { dateDesc, dateAsc, quantityDesc }

extension StockMovementSortX on StockMovementSort {
  String get labelKey {
    switch (this) {
      case StockMovementSort.dateDesc:
        return 'sort_newest_first';
      case StockMovementSort.dateAsc:
        return 'sort_oldest_first';
      case StockMovementSort.quantityDesc:
        return 'sort_quantity_desc';
    }
  }
}

// ============================================
// Full report
// ============================================
class StockMovementModel {
  final DateTime fromDate;
  final DateTime toDate;
  final List<StockMovementRow> rows;

  final double totalIn;
  final double totalOut;
  final double totalAdjustment;
  final int inCount;
  final int outCount;
  final int adjustmentCount;
  final double totalInValue;
  final double totalOutValue;

  const StockMovementModel({
    required this.fromDate,
    required this.toDate,
    this.rows = const [],
    this.totalIn = 0,
    this.totalOut = 0,
    this.totalAdjustment = 0,
    this.inCount = 0,
    this.outCount = 0,
    this.adjustmentCount = 0,
    this.totalInValue = 0,
    this.totalOutValue = 0,
  });

  int get totalMovements => rows.length;
  int get productCount => rows.map((r) => r.productId).toSet().length;
  int get warehouseCount => rows.map((r) => r.warehouseId).toSet().length;

  StockMovementModel sortedBy(StockMovementSort sort) {
    final copy = List<StockMovementRow>.from(rows);
    switch (sort) {
      case StockMovementSort.dateDesc:
        copy.sort((a, b) => b.date.compareTo(a.date));
        break;
      case StockMovementSort.dateAsc:
        copy.sort((a, b) => a.date.compareTo(b.date));
        break;
      case StockMovementSort.quantityDesc:
        copy.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
    }
    return StockMovementModel(
      fromDate: fromDate,
      toDate: toDate,
      rows: copy,
      totalIn: totalIn,
      totalOut: totalOut,
      totalAdjustment: totalAdjustment,
      inCount: inCount,
      outCount: outCount,
      adjustmentCount: adjustmentCount,
      totalInValue: totalInValue,
      totalOutValue: totalOutValue,
    );
  }

  factory StockMovementModel.fromRows(
    DateTime fromDate,
    DateTime toDate,
    List<StockMovementRow> rows,
  ) {
    double totalIn = 0, totalOut = 0, totalAdj = 0;
    double totalInValue = 0, totalOutValue = 0;
    int inCount = 0, outCount = 0, adjCount = 0;

    for (final r in rows) {
      switch (r.type) {
        case StockMovementType.in_:
          totalIn += r.quantity;
          totalInValue += r.totalValue;
          inCount++;
          break;
        case StockMovementType.out:
          totalOut += r.quantity;
          totalOutValue += r.totalValue;
          outCount++;
          break;
        case StockMovementType.adjustment:
          totalAdj += r.quantity;
          adjCount++;
          break;
      }
    }

    final sorted = List<StockMovementRow>.from(rows)
      ..sort((a, b) => b.date.compareTo(a.date));

    return StockMovementModel(
      fromDate: fromDate,
      toDate: toDate,
      rows: sorted,
      totalIn: totalIn,
      totalOut: totalOut,
      totalAdjustment: totalAdj,
      inCount: inCount,
      outCount: outCount,
      adjustmentCount: adjCount,
      totalInValue: totalInValue,
      totalOutValue: totalOutValue,
    );
  }
}
