import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/shared/app_bar_actions.dart';
import '../../../widgets/shared/app_shell.dart';
import '../providers/product_category_provider.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/product_filter_bar.dart';

class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('are_you_sure_delete_product'.tr(args: [name])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(productServiceProvider).deleteProduct(id);
      ref.invalidate(productsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('product_deleted'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_label'.tr(args: [e.toString()]))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);
    final categoriesAsync = ref.watch(productCategoriesListProvider);
    final langCode = context.locale.languageCode;

    return AppShell(
      currentRoute: '/products',
      child: Scaffold(
        appBar: AppBar(
          title: _showSearch
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'search_product_hint'.tr(),
                    hintStyle: const TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    ref.read(productFilterProvider.notifier).state =
                        ref.read(productFilterProvider).copyWith(search: value);
                  },
                )
              : Text('products'.tr()),
          automaticallyImplyLeading: false,
          leading: MediaQuery.of(context).size.width < 900
              ? Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                )
              : null,
          actions: [
            IconButton(
              icon: Icon(_showSearch ? Icons.close : Icons.search),
              tooltip: 'search'.tr(),
              onPressed: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchController.clear();
                    ref.read(productFilterProvider.notifier).state =
                        ref.read(productFilterProvider).copyWith(search: '');
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'refresh'.tr(),
              onPressed: () => ref.invalidate(productsListProvider),
            ),
            const AppBarActions(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/products/new'),
          icon: const Icon(Icons.add),
          label: Text('add_product'.tr()),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(productsListProvider);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ProductFilterBar(),
                const SizedBox(height: 16),
                Expanded(
                  child: productsAsync.when(
                    data: (products) {
                      if (products.isEmpty) {
                        return EmptyStateWidget(
                          icon: Icons.inventory_2_outlined,
                          title: 'no_products'.tr(),
                          subtitle: 'no_products_subtitle'.tr(),
                          actionLabel: 'add_product'.tr(),
                          onAction: () => context.push('/products/new'),
                        );
                      }

                      final categoriesMap = {
                        for (final c in (categoriesAsync.valueOrNull ?? []))
                          c.id: c.getLocalizedName(langCode),
                      };

                      return ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return ProductCard(
                            product: product,
                            categoryName: product.categoryId != null
                                ? categoriesMap[product.categoryId]
                                : null,
                            onTap: () =>
                                context.push('/products/${product.id}'),
                            onEdit: () =>
                                context.push('/products/${product.id}/edit'),
                            onDelete: () =>
                                _confirmDelete(product.id, product.name),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 12),
                          Text('error_label'.tr(args: [error.toString()])),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () =>
                                ref.invalidate(productsListProvider),
                            child: Text('retry'.tr()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
