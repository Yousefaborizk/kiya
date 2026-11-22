import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/inventory_service.dart';
import '../models/warehouse_model.dart';

// Service provider (مشترك بين المخزون والمستودعات)
final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService();
});

// Warehouses list provider
final warehousesListProvider =
    FutureProvider.autoDispose<List<WarehouseModel>>((ref) async {
  final service = ref.watch(inventoryServiceProvider);
  return service.getWarehouses();
});
