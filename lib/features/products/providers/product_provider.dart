import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/product_service.dart';
import '../models/product_model.dart';

final productServiceProvider = Provider<ProductService>((ref) {
  return ProductService();
});

class ProductFilter {
  final String? categoryId;
  final String? search;
  final bool? isActive;

  const ProductFilter({
    this.categoryId,
    this.search,
    this.isActive,
  });

  ProductFilter copyWith({
    String? categoryId,
    String? search,
    bool? isActive,
    bool clearCategory = false,
    bool clearSearch = false,
    bool clearActive = false,
  }) {
    return ProductFilter(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      search: clearSearch ? null : (search ?? this.search),
      isActive: clearActive ? null : (isActive ?? this.isActive),
    );
  }
}

final productFilterProvider =
    StateProvider<ProductFilter>((ref) => const ProductFilter());

final productsListProvider =
    FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final filter = ref.watch(productFilterProvider);
  final service = ref.watch(productServiceProvider);

  return service.getProducts(
    categoryId: filter.categoryId,
    search: (filter.search != null && filter.search!.isNotEmpty)
        ? filter.search
        : null,
    isActive: filter.isActive,
  );
});

final productByIdProvider =
    FutureProvider.autoDispose.family<ProductModel?, String>((ref, id) async {
  final service = ref.watch(productServiceProvider);
  return service.getProductById(id);
});
