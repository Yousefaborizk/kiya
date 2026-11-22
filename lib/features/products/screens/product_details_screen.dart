import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/inventory/providers/inventory_provider.dart';
import '../../../features/inventory/providers/warehouse_provider.dart';
import '../../../utils/unit_translator.dart';
import '../providers/product_category_provider.dart';
import '../providers/product_provider.dart';

class ProductDetailsScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productByIdProvider(productId));
    final categoriesAsync = ref.watch(productCategoriesListProvider);

    final stockAsync = ref.watch(productStockProvider(productId));
    final warehousesAsync = ref.watch(warehousesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('product_details'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'edit'.tr(),
            onPressed: () => context.push('/products/$productId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'refresh'.tr(),
            onPressed: () {
              ref.invalidate(productByIdProvider(productId));
              ref.invalidate(productCategoriesListProvider);
              ref.invalidate(productStockProvider(productId));
              ref.invalidate(warehousesListProvider);
            },
          ),
        ],
      ),
      body: productAsync.when(
        data: (product) {
          if (product == null) {
            return Center(child: Text('product_not_found'.tr()));
          }

          final categoryName = product.categoryId != null
              ? (categoriesAsync.valueOrNull
                  ?.where((c) => c.id == product.categoryId)
                  .firstOrNull
                  ?.name)
              : null;

          final translatedUnit = UnitTranslator.translate(product.unit);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header (Image + Name + Code) ──────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            if (product.imageUrl != null &&
                                product.imageUrl!.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  product.imageUrl!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _imagePlaceholder(),
                                ),
                              )
                            else
                              _imagePlaceholder(),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    product.productCode ?? '-',
                                    style: const TextStyle(
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  if (categoryName != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      categoryName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Stock Info ───────────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'current_stock'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            stockAsync.when(
                              data: (stockList) {
                                if (stockList.isEmpty) {
                                  return Text(
                                    'no_stock'.tr(),
                                    style: const TextStyle(
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  );
                                }

                                final totalQuantity = stockList.fold(
                                    0.0, (sum, item) => sum + item.quantity);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${totalQuantity.toStringAsFixed(2)} $translatedUnit',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    ...stockList.map((stock) {
                                      final warehouseName = warehousesAsync
                                              .valueOrNull
                                              ?.where((w) =>
                                                  w.id == stock.warehouseId)
                                              .firstOrNull
                                              ?.name ??
                                          '-';
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(warehouseName,
                                                style: const TextStyle(
                                                    fontSize: 13)),
                                            Text(
                                              '${stock.quantity.toStringAsFixed(2)} $translatedUnit',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                );
                              },
                              loading: () => const Center(
                                child: LinearProgressIndicator(),
                              ),
                              error: (e, _) =>
                                  Text('error_label'.tr(args: [e.toString()])),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Pricing ──────────────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoRow(
                              label: 'selling_price'.tr(),
                              value:
                                  '${product.sellingPrice.toStringAsFixed(2)} EGP',
                            ),
                            _InfoRow(
                              label: 'purchase_price'.tr(),
                              value:
                                  '${product.purchasePrice.toStringAsFixed(2)} EGP',
                            ),
                            _InfoRow(
                              label: 'min_stock_level'.tr(),
                              value: product.minStockLevel.toString(),
                            ),
                            _InfoRow(
                              label: 'unit'.tr(),
                              value: translatedUnit,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Description & Notes ──────────────────
                    if ((product.description != null &&
                            product.description!.isNotEmpty) ||
                        (product.notes != null &&
                            product.notes!.isNotEmpty)) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.description != null &&
                                  product.description!.isNotEmpty) ...[
                                Text(
                                  'description'.tr(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(product.description!),
                                const SizedBox(height: 12),
                              ],
                              if (product.notes != null &&
                                  product.notes!.isNotEmpty) ...[
                                Text(
                                  'notes'.tr(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(product.notes!),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Actions ──────────────────────────────
                    ElevatedButton.icon(
                      onPressed: () =>
                          context.push('/products/$productId/edit'),
                      icon: const Icon(Icons.edit),
                      label: Text('edit_product'.tr()),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('error_label'.tr(args: [e.toString()]))),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.inventory_2_outlined,
          color: AppColors.primary, size: 48),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
