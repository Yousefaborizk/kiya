import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ar_aging_model.dart';
import '../data/models/customer_statement_model.dart';
import '../data/models/invoice_register_model.dart';
import '../data/models/low_stock_model.dart';
import '../data/models/sales_by_customer_model.dart';
import '../data/models/sales_by_product_model.dart';
import '../data/models/stock_movement_model.dart';
import '../data/models/stock_valuation_model.dart';
import '../data/services/reports_service.dart';

// ============================================
// SERVICE PROVIDER
// ============================================
final reportsServiceProvider = Provider<ReportsService>((ref) {
  return ReportsService();
});

// ============================================
// CUSTOMER STATEMENT
// ============================================
class CustomerStatementFilter {
  final String? customerId;
  final DateTime fromDate;
  final DateTime toDate;

  const CustomerStatementFilter({
    this.customerId,
    required this.fromDate,
    required this.toDate,
  });

  CustomerStatementFilter copyWith({
    String? customerId,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearCustomer = false,
  }) {
    return CustomerStatementFilter(
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }
}

final customerStatementFilterProvider =
    StateProvider<CustomerStatementFilter>((ref) {
  final now = DateTime.now();
  return CustomerStatementFilter(
    fromDate: DateTime(now.year, 1, 1),
    toDate: now,
  );
});

final customerStatementProvider =
    FutureProvider.autoDispose<CustomerStatementModel?>((ref) async {
  final filter = ref.watch(customerStatementFilterProvider);
  if (filter.customerId == null) return null;

  final service = ref.watch(reportsServiceProvider);
  return service.getCustomerStatement(
    customerId: filter.customerId!,
    fromDate: filter.fromDate,
    toDate: filter.toDate,
  );
});

// ============================================
// AR AGING
// ============================================
class ArAgingFilter {
  final DateTime asOfDate;
  final String? customerId;

  const ArAgingFilter({
    required this.asOfDate,
    this.customerId,
  });

  ArAgingFilter copyWith({
    DateTime? asOfDate,
    String? customerId,
    bool clearCustomer = false,
  }) {
    return ArAgingFilter(
      asOfDate: asOfDate ?? this.asOfDate,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
    );
  }
}

final arAgingFilterProvider = StateProvider<ArAgingFilter>((ref) {
  return ArAgingFilter(asOfDate: DateTime.now());
});

final arAgingProvider = FutureProvider.autoDispose<ArAgingModel>((ref) async {
  final filter = ref.watch(arAgingFilterProvider);
  final service = ref.watch(reportsServiceProvider);
  return service.getArAging(
    asOfDate: filter.asOfDate,
    customerId: filter.customerId,
  );
});

// ============================================
// SALES BY PRODUCT
// ============================================
class SalesByProductFilter {
  final DateTime fromDate;
  final DateTime toDate;
  final String? categoryId;
  final SalesByProductSort sort;

  const SalesByProductFilter({
    required this.fromDate,
    required this.toDate,
    this.categoryId,
    this.sort = SalesByProductSort.revenueDesc,
  });

  SalesByProductFilter copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    String? categoryId,
    SalesByProductSort? sort,
    bool clearCategory = false,
  }) {
    return SalesByProductFilter(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      sort: sort ?? this.sort,
    );
  }
}

final salesByProductFilterProvider = StateProvider<SalesByProductFilter>((ref) {
  final now = DateTime.now();
  return SalesByProductFilter(
    fromDate: DateTime(now.year, now.month, 1),
    toDate: now,
  );
});

final salesByProductProvider =
    FutureProvider.autoDispose<SalesByProductModel>((ref) async {
  final filter = ref.watch(salesByProductFilterProvider);
  final service = ref.watch(reportsServiceProvider);
  final data = await service.getSalesByProduct(
    fromDate: filter.fromDate,
    toDate: filter.toDate,
    categoryId: filter.categoryId,
  );
  return data.sortedBy(filter.sort);
});

// ============================================
// SALES BY CUSTOMER
// ============================================
class SalesByCustomerFilter {
  final DateTime fromDate;
  final DateTime toDate;
  final SalesByCustomerSort sort;

  const SalesByCustomerFilter({
    required this.fromDate,
    required this.toDate,
    this.sort = SalesByCustomerSort.revenueDesc,
  });

  SalesByCustomerFilter copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    SalesByCustomerSort? sort,
  }) {
    return SalesByCustomerFilter(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      sort: sort ?? this.sort,
    );
  }
}

final salesByCustomerFilterProvider =
    StateProvider<SalesByCustomerFilter>((ref) {
  final now = DateTime.now();
  return SalesByCustomerFilter(
    fromDate: DateTime(now.year, now.month, 1),
    toDate: now,
  );
});

final salesByCustomerProvider =
    FutureProvider.autoDispose<SalesByCustomerModel>((ref) async {
  final filter = ref.watch(salesByCustomerFilterProvider);
  final service = ref.watch(reportsServiceProvider);
  final data = await service.getSalesByCustomer(
    fromDate: filter.fromDate,
    toDate: filter.toDate,
  );
  return data.sortedBy(filter.sort);
});

// ============================================
// LOW STOCK
// ============================================
class LowStockFilter {
  final String? categoryId;
  final LowStockSort sort;

  const LowStockFilter({
    this.categoryId,
    this.sort = LowStockSort.severityDesc,
  });

  LowStockFilter copyWith({
    String? categoryId,
    LowStockSort? sort,
    bool clearCategory = false,
  }) {
    return LowStockFilter(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      sort: sort ?? this.sort,
    );
  }
}

final lowStockFilterProvider =
    StateProvider<LowStockFilter>((ref) => const LowStockFilter());

final lowStockProvider = FutureProvider.autoDispose<LowStockModel>((ref) async {
  final filter = ref.watch(lowStockFilterProvider);
  final service = ref.watch(reportsServiceProvider);
  final data = await service.getLowStock(
    categoryId: filter.categoryId,
  );
  return data.sortedBy(filter.sort);
});

// ============================================
// STOCK VALUATION
// ============================================
class StockValuationFilter {
  final String? warehouseId;
  final String? categoryId;
  final StockValuationSort sort;
  final bool includeZeroStock;

  const StockValuationFilter({
    this.warehouseId,
    this.categoryId,
    this.sort = StockValuationSort.costValueDesc,
    this.includeZeroStock = false,
  });

  StockValuationFilter copyWith({
    String? warehouseId,
    String? categoryId,
    StockValuationSort? sort,
    bool? includeZeroStock,
    bool clearWarehouse = false,
    bool clearCategory = false,
  }) {
    return StockValuationFilter(
      warehouseId: clearWarehouse ? null : (warehouseId ?? this.warehouseId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      sort: sort ?? this.sort,
      includeZeroStock: includeZeroStock ?? this.includeZeroStock,
    );
  }
}

final stockValuationFilterProvider =
    StateProvider<StockValuationFilter>((ref) => const StockValuationFilter());

final stockValuationProvider =
    FutureProvider.autoDispose<StockValuationModel>((ref) async {
  final filter = ref.watch(stockValuationFilterProvider);
  final service = ref.watch(reportsServiceProvider);
  final data = await service.getStockValuation(
    warehouseId: filter.warehouseId,
    categoryId: filter.categoryId,
    includeZeroStock: filter.includeZeroStock,
  );
  return data.sortedBy(filter.sort);
});

// ============================================
// STOCK MOVEMENT
// ============================================
class StockMovementFilter {
  final DateTime fromDate;
  final DateTime toDate;
  final String? warehouseId;
  final StockMovementSort sort;

  const StockMovementFilter({
    required this.fromDate,
    required this.toDate,
    this.warehouseId,
    this.sort = StockMovementSort.dateDesc,
  });

  StockMovementFilter copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    String? warehouseId,
    StockMovementSort? sort,
    bool clearWarehouse = false,
  }) {
    return StockMovementFilter(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      warehouseId: clearWarehouse ? null : (warehouseId ?? this.warehouseId),
      sort: sort ?? this.sort,
    );
  }
}

final stockMovementFilterProvider = StateProvider<StockMovementFilter>((ref) {
  final now = DateTime.now();
  return StockMovementFilter(
    fromDate: DateTime(now.year, now.month, 1),
    toDate: now,
  );
});

final stockMovementProvider =
    FutureProvider.autoDispose<StockMovementModel>((ref) async {
  final filter = ref.watch(stockMovementFilterProvider);
  final service = ref.watch(reportsServiceProvider);
  final data = await service.getStockMovement(
    fromDate: filter.fromDate,
    toDate: filter.toDate,
    warehouseId: filter.warehouseId,
  );
  return data.sortedBy(filter.sort);
});

// ============================================
// INVOICE REGISTER
// ============================================
class InvoiceRegisterFilter {
  final DateTime fromDate;
  final DateTime toDate;
  final InvoiceRegisterStatus status;
  final InvoiceRegisterSort sort;

  const InvoiceRegisterFilter({
    required this.fromDate,
    required this.toDate,
    this.status = InvoiceRegisterStatus.all,
    this.sort = InvoiceRegisterSort.dateDesc,
  });

  InvoiceRegisterFilter copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    InvoiceRegisterStatus? status,
    InvoiceRegisterSort? sort,
  }) {
    return InvoiceRegisterFilter(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      status: status ?? this.status,
      sort: sort ?? this.sort,
    );
  }
}

final invoiceRegisterFilterProvider =
    StateProvider<InvoiceRegisterFilter>((ref) {
  final now = DateTime.now();
  return InvoiceRegisterFilter(
    fromDate: DateTime(now.year, now.month, 1),
    toDate: now,
  );
});

final invoiceRegisterProvider =
    FutureProvider.autoDispose<InvoiceRegisterModel>((ref) async {
  final filter = ref.watch(invoiceRegisterFilterProvider);
  final service = ref.watch(reportsServiceProvider);
  final data = await service.getInvoiceRegister(
    fromDate: filter.fromDate,
    toDate: filter.toDate,
    status: filter.status,
  );
  return data.sortedBy(filter.sort);
});
