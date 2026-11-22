import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../models/inventory_stock_model.dart';
import '../../models/inventory_transaction_model.dart';
import '../../models/warehouse_model.dart';

class InventoryService {
  final SupabaseClient _client = Supabase.instance.client;

  // ============================================
  // WAREHOUSES
  // ============================================
  Future<List<WarehouseModel>> getWarehouses() async {
    try {
      final data = await _client
          .from(AppConstants.tableWarehouses)
          .select()
          .eq('is_active', true)
          .order('name');

      debugPrint('GET WAREHOUSES: ${data.length} rows');
      return (data as List)
          .map((e) => WarehouseModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('GET WAREHOUSES ERROR: $e');
      rethrow;
    }
  }

  Future<WarehouseModel> createWarehouse(WarehouseModel warehouse) async {
    try {
      final payload = warehouse.toJson();
      debugPrint('INSERT WAREHOUSE PAYLOAD: $payload');
      await _client.from(AppConstants.tableWarehouses).insert(payload);
      return warehouse;
    } catch (e) {
      debugPrint('CREATE WAREHOUSE ERROR: $e');
      rethrow;
    }
  }

  Future<void> updateWarehouse(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _client
        .from(AppConstants.tableWarehouses)
        .update(updates)
        .eq('id', id);
  }

  Future<void> deleteWarehouse(String id) async {
    await _client
        .from(AppConstants.tableWarehouses)
        .update({'is_active': false}).eq('id', id);
  }

  // ============================================
  // INVENTORY STOCK
  // ============================================
  Future<List<InventoryStockModel>> getStock({
    String? warehouseId,
    String? productId,
    String? search,
  }) async {
    try {
      var query = _client
          .from(AppConstants.tableInventoryStock)
          .select('*, products(name, product_code)');

      if (warehouseId != null) query = query.eq('warehouse_id', warehouseId);
      if (productId != null) query = query.eq('product_id', productId);

      final data = await query.order('last_updated_at', ascending: false);
      debugPrint('GET STOCK: ${data.length} rows');

      return (data as List)
          .map((e) => InventoryStockModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('GET STOCK ERROR: $e');
      rethrow;
    }
  }

  Future<InventoryStockModel?> getStockByProductAndWarehouse(
    String productId,
    String warehouseId,
  ) async {
    final data = await _client
        .from(AppConstants.tableInventoryStock)
        .select()
        .eq('product_id', productId)
        .eq('warehouse_id', warehouseId)
        .maybeSingle();
    if (data == null) return null;
    return InventoryStockModel.fromJson(data);
  }

  // ============================================
  // INVENTORY TRANSACTIONS
  // ============================================
  Future<List<InventoryTransactionModel>> getTransactions({
    String? warehouseId,
    String? productId,
    String? transactionType,
  }) async {
    try {
      var query =
          _client.from(AppConstants.tableInventoryTransactions).select();

      if (warehouseId != null) query = query.eq('warehouse_id', warehouseId);
      if (productId != null) query = query.eq('product_id', productId);
      if (transactionType != null) {
        query = query.eq('transaction_type', transactionType);
      }

      final data = await query.order('created_at', ascending: false);
      debugPrint('GET TRANSACTIONS: ${data.length} rows');

      return (data as List)
          .map((e) =>
              InventoryTransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('GET TRANSACTIONS ERROR: $e');
      rethrow;
    }
  }

  Future<void> createTransaction(
    InventoryTransactionModel transaction,
  ) async {
    try {
      final payload = transaction.toJson();
      payload['created_by'] = _client.auth.currentUser?.id;
      debugPrint('CREATE TRANSACTION PAYLOAD: $payload');
      await _client
          .from(AppConstants.tableInventoryTransactions)
          .insert(payload);
      debugPrint('TRANSACTION CREATED SUCCESSFULLY');
    } catch (e) {
      debugPrint('CREATE TRANSACTION ERROR: $e');
      rethrow;
    }
  }
}
