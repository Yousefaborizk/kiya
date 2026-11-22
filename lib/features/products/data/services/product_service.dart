import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../models/product_category_model.dart';
import '../../models/product_image_model.dart';
import '../../models/product_model.dart';

class ProductService {
  final SupabaseClient _client = Supabase.instance.client;

  // ============================================
  // PRODUCT CATEGORIES
  // ============================================
  Future<List<ProductCategoryModel>> getCategories() async {
    final data = await _client
        .from(AppConstants.tableProductCategories)
        .select()
        .eq('is_active', true)
        .order('name');
    return (data as List)
        .map((e) => ProductCategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProductCategoryModel> createCategory(
    ProductCategoryModel category,
  ) async {
    await _client
        .from(AppConstants.tableProductCategories)
        .insert(category.toJson());
    return category;
  }

  Future<void> updateCategory(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _client
        .from(AppConstants.tableProductCategories)
        .update(updates)
        .eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    await _client
        .from(AppConstants.tableProductCategories)
        .update({'is_active': false}).eq('id', id);
  }

  // ============================================
  // PRODUCTS
  // ============================================
  Future<List<ProductModel>> getProducts({
    String? categoryId,
    String? search,
    bool? isActive,
  }) async {
    var query = _client.from(AppConstants.tableProducts).select();

    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (isActive != null) query = query.eq('is_active', isActive);
    if (search != null && search.isNotEmpty) {
      query = query.or('name.ilike.%$search%,product_code.ilike.%$search%');
    }

    final data = await query.order('created_at', ascending: false);
    debugPrint('GET PRODUCTS: ${data.length} rows');
    return (data as List)
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProductModel?> getProductById(String id) async {
    final data = await _client
        .from(AppConstants.tableProducts)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return ProductModel.fromJson(data);
  }

  Future<ProductModel> createProduct(ProductModel product) async {
    try {
      final payload = product.toJson();
      debugPrint('INSERT PRODUCT PAYLOAD: $payload');

      final data = await _client
          .from(AppConstants.tableProducts)
          .insert(payload)
          .select()
          .single();
      return ProductModel.fromJson(data);
    } catch (e) {
      debugPrint('CREATE PRODUCT ERROR: $e');
      rethrow;
    }
  }

  Future<ProductModel> updateProduct(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final data = await _client
        .from(AppConstants.tableProducts)
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return ProductModel.fromJson(data);
  }

  Future<void> deleteProduct(String id) async {
    await _client
        .from(AppConstants.tableProducts)
        .update({'is_active': false}).eq('id', id);
  }

  // ============================================
  // PRODUCT IMAGES
  // ============================================
  Future<List<ProductImageModel>> getProductImages(String productId) async {
    final data = await _client
        .from(AppConstants.tableProductImages)
        .select()
        .eq('product_id', productId)
        .order('sort_order');
    return (data as List)
        .map((e) => ProductImageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addProductImage(ProductImageModel image) async {
    await _client.from(AppConstants.tableProductImages).insert(image.toJson());
  }

  Future<void> deleteProductImage(String id) async {
    await _client.from(AppConstants.tableProductImages).delete().eq('id', id);
  }
}
