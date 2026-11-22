// ============================================
// Row per product × warehouse
// ============================================
class StockValuationRow {
  final String productId;
  final String productCode;
  final String productName;
  final String unit;
  final String warehouseId;
  final String warehouseName;
  final double quantity;
  final double purchasePrice;
  final double sellingPrice;

  const StockValuationRow({
    required this.productId,
    required this.productCode,
    required this.productName,
    this.unit = 'قطعة',
    required this.warehouseId,
    required this.warehouseName,
    this.quantity = 0,
    this.purchasePrice = 0,
    this.sellingPrice = 0,
  });

  double get costValue => quantity * purchasePrice;
  double get salesValue => quantity * sellingPrice;
  double get expectedProfit => salesValue - costValue;

  double get profitMargin =>
      salesValue > 0.001 ? (expectedProfit / salesValue) * 100 : 0;

  bool get hasStock => quantity > 0.001;
}

// ============================================
// Aggregated product (across warehouses)
// ============================================
class StockValuationProduct {
  final String productId;
  final String productCode;
  final String productName;
  final String unit;
  final double totalQuantity;
  final double purchasePrice;
  final double sellingPrice;
  final List<StockValuationRow> warehouses;

  const StockValuationProduct({
    required this.productId,
    required this.productCode,
    required this.productName,
    this.unit = 'قطعة',
    this.totalQuantity = 0,
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.warehouses = const [],
  });

  double get costValue => totalQuantity * purchasePrice;
  double get salesValue => totalQuantity * sellingPrice;
  double get expectedProfit => salesValue - costValue;

  double get profitMargin =>
      salesValue > 0.001 ? (expectedProfit / salesValue) * 100 : 0;
}

// ============================================
// Sort options
// ============================================
enum StockValuationSort {
  costValueDesc,
  quantityDesc,
  profitDesc,
  nameAsc,
}

extension StockValuationSortX on StockValuationSort {
  String get labelKey {
    switch (this) {
      case StockValuationSort.costValueDesc:
        return 'sort_by_cost_value';
      case StockValuationSort.quantityDesc:
        return 'sort_by_quantity';
      case StockValuationSort.profitDesc:
        return 'sort_by_profit';
      case StockValuationSort.nameAsc:
        return 'sort_by_name';
    }
  }
}

// ============================================
// Group by
// ============================================
enum StockValuationGroupBy {
  product,
  warehouse,
}

// ============================================
// Full report
// ============================================
class StockValuationModel {
  final DateTime asOfDate;
  final List<StockValuationRow> rows; // flat (per warehouse)
  final List<StockValuationProduct> products; // aggregated

  final double totalQuantity;
  final double totalCostValue;
  final double totalSalesValue;
  final double totalExpectedProfit;

  const StockValuationModel({
    required this.asOfDate,
    this.rows = const [],
    this.products = const [],
    this.totalQuantity = 0,
    this.totalCostValue = 0,
    this.totalSalesValue = 0,
    this.totalExpectedProfit = 0,
  });

  int get productCount => products.length;

  int get warehouseCount => rows.map((r) => r.warehouseId).toSet().length;

  double get overallProfitMargin => totalSalesValue > 0.001
      ? (totalExpectedProfit / totalSalesValue) * 100
      : 0;

  StockValuationModel sortedBy(StockValuationSort sort) {
    final copy = List<StockValuationProduct>.from(products);
    switch (sort) {
      case StockValuationSort.costValueDesc:
        copy.sort((a, b) => b.costValue.compareTo(a.costValue));
        break;
      case StockValuationSort.quantityDesc:
        copy.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
        break;
      case StockValuationSort.profitDesc:
        copy.sort((a, b) => b.expectedProfit.compareTo(a.expectedProfit));
        break;
      case StockValuationSort.nameAsc:
        copy.sort((a, b) => a.productName.compareTo(b.productName));
        break;
    }
    return StockValuationModel(
      asOfDate: asOfDate,
      rows: rows,
      products: copy,
      totalQuantity: totalQuantity,
      totalCostValue: totalCostValue,
      totalSalesValue: totalSalesValue,
      totalExpectedProfit: totalExpectedProfit,
    );
  }

  factory StockValuationModel.fromRows(
    DateTime asOfDate,
    List<StockValuationRow> rows,
  ) {
    // تجميع حسب المنتج
    final Map<String, _ProductAcc> acc = {};
    for (final r in rows) {
      final entry = acc.putIfAbsent(
        r.productId,
        () => _ProductAcc(
          productId: r.productId,
          productCode: r.productCode,
          productName: r.productName,
          unit: r.unit,
          purchasePrice: r.purchasePrice,
          sellingPrice: r.sellingPrice,
        ),
      );
      entry.addWarehouse(r);
    }

    final products = acc.values.map((e) => e.build()).toList()
      ..sort((a, b) => b.costValue.compareTo(a.costValue));

    double totalQty = 0;
    double totalCost = 0;
    double totalSales = 0;
    double totalProfit = 0;

    for (final r in rows) {
      totalQty += r.quantity;
      totalCost += r.costValue;
      totalSales += r.salesValue;
      totalProfit += r.expectedProfit;
    }

    return StockValuationModel(
      asOfDate: asOfDate,
      rows: rows,
      products: products,
      totalQuantity: totalQty,
      totalCostValue: totalCost,
      totalSalesValue: totalSales,
      totalExpectedProfit: totalProfit,
    );
  }
}

// ============================================
// Internal accumulator
// ============================================
class _ProductAcc {
  final String productId;
  final String productCode;
  final String productName;
  final String unit;
  final double purchasePrice;
  final double sellingPrice;

  double totalQuantity = 0;
  final List<StockValuationRow> warehouses = [];

  _ProductAcc({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
  });

  void addWarehouse(StockValuationRow row) {
    totalQuantity += row.quantity;
    warehouses.add(row);
  }

  StockValuationProduct build() => StockValuationProduct(
        productId: productId,
        productCode: productCode,
        productName: productName,
        unit: unit,
        totalQuantity: totalQuantity,
        purchasePrice: purchasePrice,
        sellingPrice: sellingPrice,
        warehouses: warehouses,
      );
}
