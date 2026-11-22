import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_category_model.dart';
import 'product_provider.dart';

final productCategoriesListProvider =
    FutureProvider.autoDispose<List<ProductCategoryModel>>((ref) async {
  final service = ref.watch(productServiceProvider);
  return service.getCategories();
});
