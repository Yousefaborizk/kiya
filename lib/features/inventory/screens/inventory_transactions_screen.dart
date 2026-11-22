import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/products/providers/product_provider.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/shared/app_bar_actions.dart';
import '../../../widgets/shared/app_shell.dart';
import '../providers/inventory_provider.dart';
import '../providers/warehouse_provider.dart';
import '../widgets/transaction_card.dart';

class InventoryTransactionsScreen extends ConsumerWidget {
  const InventoryTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(inventoryTransactionsListProvider);
    final warehousesAsync = ref.watch(warehousesListProvider);
    final productsAsync = ref.watch(productsListProvider);
    final filter = ref.watch(transactionFilterProvider);

    return AppShell(
      currentRoute: '/inventory/transactions',
      child: Scaffold(
        appBar: AppBar(
          title: Text('transactions'.tr()),
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
              icon: const Icon(Icons.refresh),
              tooltip: 'refresh'.tr(),
              onPressed: () =>
                  ref.invalidate(inventoryTransactionsListProvider),
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
            ref.invalidate(inventoryTransactionsListProvider);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    warehousesAsync.when(
                      data: (warehouses) => _TypeFilter(
                        value: filter.transactionType,
                        onChanged: (value) {
                          ref.read(transactionFilterProvider.notifier).state =
                              value == null
                                  ? filter.copyWith(clearType: true)
                                  : filter.copyWith(transactionType: value);
                        },
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: transactionsAsync.when(
                    data: (transactions) {
                      if (transactions.isEmpty) {
                        return EmptyStateWidget(
                          icon: Icons.swap_horiz,
                          title: 'no_transactions'.tr(),
                          subtitle: 'no_transactions_subtitle'.tr(),
                          actionLabel: 'add_transaction'.tr(),
                          onAction: () =>
                              context.push('/inventory/transactions/new'),
                        );
                      }

                      final productsMap = {
                        for (final p in (productsAsync.valueOrNull ?? []))
                          p.id: p,
                      };
                      final warehousesMap = {
                        for (final w in (warehousesAsync.valueOrNull ?? []))
                          w.id: w.name, // هنا بنستخدم name
                      };

                      return ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          final product = productsMap[tx.productId];
                          if (product == null) return const SizedBox.shrink();

                          return TransactionCard(
                            productName: product.name, // هنا بنستخدم name
                            productCode: product.productCode,
                            warehouseName: warehousesMap[tx.warehouseId] ?? '-',
                            transactionType: tx.transactionType,
                            quantity: tx.quantity,
                            unit: product.unit,
                            createdAt: tx.createdAt,
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text('error_label'.tr(args: [error.toString()])),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => ref
                                .invalidate(inventoryTransactionsListProvider),
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

class _TypeFilter extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _TypeFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = <MapEntry<String, String?>>[
      MapEntry('all'.tr(), null),
      MapEntry('in'.tr(), 'in'),
      MapEntry('out'.tr(), 'out'),
      MapEntry('adjustment'.tr(), 'adjustment'),
    ];

    final currentLabel = options
        .firstWhere((e) => e.value == value, orElse: () => options.first)
        .key;

    return PopupMenuButton<String?>(
      tooltip: 'transaction_type'.tr(),
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value != null
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value != null ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${'transaction_type'.tr()}:',
              style: TextStyle(
                color: value != null
                    ? AppColors.primary
                    : AppColors.textPrimaryLight,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              currentLabel,
              style: TextStyle(
                color: value != null
                    ? AppColors.primary
                    : AppColors.textPrimaryLight,
                fontSize: 13,
                fontWeight: value != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
      itemBuilder: (context) => options
          .map(
            (e) => PopupMenuItem<String?>(
              value: e.value,
              child: Row(
                children: [
                  if (e.value == value)
                    const Icon(Icons.check, size: 18, color: AppColors.primary)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(e.key),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
