import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/inventory_stock_model.dart';
import '../models/inventory_transaction_model.dart';
import 'warehouse_provider.dart';

// ============================================
// STOCK FILTER & PROVIDER
// ============================================
class StockFilter {
  final String? warehouseId;
  final String? search;

  const StockFilter({this.warehouseId, this.search});

  StockFilter copyWith({
    String? warehouseId,
    String? search,
    bool clearWarehouse = false,
    bool clearSearch = false,
  }) {
    return StockFilter(
      warehouseId: clearWarehouse ? null : (warehouseId ?? this.warehouseId),
      search: clearSearch ? null : (search ?? this.search),
    );
  }
}

final stockFilterProvider =
    StateProvider<StockFilter>((ref) => const StockFilter());

// كل رصيد المخزون
final inventoryStockListProvider =
    FutureProvider.autoDispose<List<InventoryStockModel>>((ref) async {
  final filter = ref.watch(stockFilterProvider);
  final service = ref.watch(inventoryServiceProvider);

  return service.getStock(
    warehouseId: filter.warehouseId,
    search: (filter.search != null && filter.search!.isNotEmpty)
        ? filter.search
        : null,
  );
});

// رصيد منتج معين في كل المستودعات
final productStockProvider = FutureProvider.autoDispose
    .family<List<InventoryStockModel>, String>((ref, productId) async {
  final service = ref.watch(inventoryServiceProvider);
  return service.getStock(productId: productId);
});

// ============================================
// TRANSACTIONS FILTER & PROVIDER
// ============================================
class TransactionFilter {
  final String? warehouseId;
  final String? productId;
  final String? transactionType;

  const TransactionFilter({
    this.warehouseId,
    this.productId,
    this.transactionType,
  });

  TransactionFilter copyWith({
    String? warehouseId,
    String? productId,
    String? transactionType,
    bool clearWarehouse = false,
    bool clearProduct = false,
    bool clearType = false,
  }) {
    return TransactionFilter(
      warehouseId: clearWarehouse ? null : (warehouseId ?? this.warehouseId),
      productId: clearProduct ? null : (productId ?? this.productId),
      transactionType:
          clearType ? null : (transactionType ?? this.transactionType),
    );
  }
}

final transactionFilterProvider =
    StateProvider<TransactionFilter>((ref) => const TransactionFilter());

// كل الحركات
final inventoryTransactionsListProvider =
    FutureProvider.autoDispose<List<InventoryTransactionModel>>((ref) async {
  final filter = ref.watch(transactionFilterProvider);
  final service = ref.watch(inventoryServiceProvider);

  return service.getTransactions(
    warehouseId: filter.warehouseId,
    productId: filter.productId,
    transactionType: filter.transactionType,
  );
});
