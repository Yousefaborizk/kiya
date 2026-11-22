import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/products/providers/product_provider.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/shared/app_bar_actions.dart';
import '../../../widgets/shared/app_shell.dart';
import '../models/warehouse_model.dart';
import '../providers/inventory_provider.dart';
import '../providers/warehouse_provider.dart';
import '../widgets/stock_card.dart';

class InventoryStockScreen extends ConsumerStatefulWidget {
  const InventoryStockScreen({super.key});

  @override
  ConsumerState<InventoryStockScreen> createState() =>
      _InventoryStockScreenState();
}

class _InventoryStockScreenState extends ConsumerState<InventoryStockScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;
    final stockAsync = ref.watch(inventoryStockListProvider);
    final warehousesAsync = ref.watch(warehousesListProvider);
    final productsAsync = ref.watch(productsListProvider);
    final filter = ref.watch(stockFilterProvider);

    return AppShell(
      currentRoute: '/inventory',
      child: Scaffold(
        appBar: AppBar(
          title: _showSearch
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'search_stock_hint'.tr(),
                    hintStyle: const TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    ref.read(stockFilterProvider.notifier).state =
                        ref.read(stockFilterProvider).copyWith(search: value);
                  },
                )
              : Text('inventory'.tr()),
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
                    ref.read(stockFilterProvider.notifier).state =
                        ref.read(stockFilterProvider).copyWith(search: '');
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'refresh'.tr(),
              onPressed: () => ref.invalidate(inventoryStockListProvider),
            ),
            const AppBarActions(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/inventory/transactions/new'),
          icon: const Icon(Icons.add),
          label: Text('add_transaction'.tr()),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(inventoryStockListProvider);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Warehouse Filter ────────────────────
                warehousesAsync.when(
                  data: (warehouses) => _WarehouseFilter(
                    warehouses: warehouses,
                    currentWarehouseId: filter.warehouseId,
                    onChanged: (value) {
                      ref.read(stockFilterProvider.notifier).state =
                          value == null
                              ? filter.copyWith(clearWarehouse: true)
                              : filter.copyWith(warehouseId: value);
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: stockAsync.when(
                    data: (stock) {
                      if (stock.isEmpty) {
                        return EmptyStateWidget(
                          icon: Icons.inventory_2_outlined,
                          title: 'no_stock'.tr(),
                          subtitle: 'no_stock_subtitle'.tr(),
                        );
                      }

                      final productsMap = {
                        for (final p in (productsAsync.valueOrNull ?? []))
                          p.id: p,
                      };
                      final warehousesMap = {
                        for (final w in (warehousesAsync.valueOrNull ?? []))
                          w.id: w.name,
                      };

                      return ListView.builder(
                        itemCount: stock.length,
                        itemBuilder: (context, index) {
                          final item = stock[index];
                          final product = productsMap[item.productId];

                          if (product == null) {
                            return const SizedBox.shrink();
                          }

                          return StockCard(
                            productName: product.getLocalizedName(langCode),
                            productCode: product.productCode,
                            warehouseName:
                                warehousesMap[item.warehouseId] ?? '-',
                            quantity: item.quantity,
                            unit: product.unit,
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
                                ref.invalidate(inventoryStockListProvider),
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

class _WarehouseFilter extends StatelessWidget {
  final List<WarehouseModel> warehouses;
  final String? currentWarehouseId;
  final ValueChanged<String?> onChanged;

  const _WarehouseFilter({
    required this.warehouses,
    required this.currentWarehouseId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      tooltip: 'warehouse'.tr(),
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: currentWarehouseId != null
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: currentWarehouseId != null
                ? AppColors.primary
                : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${'warehouse'.tr()}:',
              style: TextStyle(
                color: currentWarehouseId != null
                    ? AppColors.primary
                    : AppColors.textPrimaryLight,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              currentWarehouseId == null
                  ? 'all'.tr()
                  : warehouses
                      .firstWhere(
                        (w) => w.id == currentWarehouseId,
                        orElse: () => warehouses.first,
                      )
                      .name, // 👈 شلنا ?? 'all'.tr() من هنا
              style: TextStyle(
                color: currentWarehouseId != null
                    ? AppColors.primary
                    : AppColors.textPrimaryLight,
                fontSize: 13,
                fontWeight: currentWarehouseId != null
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: null,
          child: Row(
            children: [
              if (currentWarehouseId == null)
                const Icon(Icons.check, size: 18, color: AppColors.primary)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 8),
              Text('all'.tr()),
            ],
          ),
        ),
        ...warehouses.map(
          (w) => PopupMenuItem(
            value: w.id,
            child: Row(
              children: [
                if (currentWarehouseId == w.id)
                  const Icon(Icons.check, size: 18, color: AppColors.primary)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(w.name),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
