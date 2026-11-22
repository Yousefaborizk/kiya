import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/inventory/models/warehouse_model.dart';
import '../../../../features/inventory/providers/warehouse_provider.dart';
import '../../../../utils/unit_translator.dart';
import '../../../../widgets/shared/app_bar_actions.dart';
import '../../../../widgets/shared/app_shell.dart';
import '../../data/models/stock_valuation_model.dart';
import '../../providers/reports_provider.dart';
import '../../utils/stock_valuation_pdf.dart';

class StockValuationScreen extends ConsumerStatefulWidget {
  const StockValuationScreen({super.key});

  @override
  ConsumerState<StockValuationScreen> createState() =>
      _StockValuationScreenState();
}

class _StockValuationScreenState extends ConsumerState<StockValuationScreen> {
  bool _isExporting = false;
  final Set<String> _expandedProducts = {};

  Future<void> _pickSort() async {
    final f = ref.read(stockValuationFilterProvider);
    final selected = await showDialog<StockValuationSort>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('sort_by'.tr()),
        children: StockValuationSort.values
            .map(
              (s) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, s),
                child: Row(
                  children: [
                    Icon(
                      s == f.sort
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 18,
                      color: s == f.sort
                          ? AppColors.primary
                          : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 8),
                    Text(s.labelKey.tr()),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null || !mounted) return;
    ref.read(stockValuationFilterProvider.notifier).state =
        f.copyWith(sort: selected);
  }

  Future<void> _pickWarehouse() async {
    final warehouses = await ref.read(warehousesListProvider.future);
    if (!mounted) return;

    final selected = await showDialog<WarehouseModel?>(
      context: context,
      builder: (context) => _WarehousePicker(
        warehouses: warehouses,
        currentId: ref.read(stockValuationFilterProvider).warehouseId,
      ),
    );
    if (!mounted) return;

    final f = ref.read(stockValuationFilterProvider);
    if (selected == null) {
      ref.read(stockValuationFilterProvider.notifier).state =
          f.copyWith(clearWarehouse: true);
    } else {
      ref.read(stockValuationFilterProvider.notifier).state =
          f.copyWith(warehouseId: selected.id);
    }
  }

  Future<void> _exportPdf(StockValuationModel data,
      {required bool share}) async {
    setState(() => _isExporting = true);
    try {
      final lang = context.locale.languageCode;
      if (share) {
        await StockValuationPdf.share(data, langCode: lang);
      } else {
        await StockValuationPdf.print(data, langCode: lang);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_label'.tr(args: ['$e']))),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(stockValuationFilterProvider);
    final dataAsync = ref.watch(stockValuationProvider);
    final warehousesAsync = ref.watch(warehousesListProvider);

    final selectedWarehouse = filter.warehouseId == null
        ? null
        : warehousesAsync.valueOrNull
            ?.where((w) => w.id == filter.warehouseId)
            .firstOrNull;

    return AppShell(
      currentRoute: '/reports',
      child: Scaffold(
        appBar: AppBar(
          title: Text('stock_valuation'.tr()),
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
              icon: const Icon(Icons.sort),
              tooltip: 'sort_by'.tr(),
              onPressed: _pickSort,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'refresh'.tr(),
              onPressed: () => ref.invalidate(stockValuationProvider),
            ),
            const AppBarActions(),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.primary.withValues(alpha: 0.04),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.sort, size: 16),
                        label: Text(filter.sort.labelKey.tr()),
                        onPressed: _pickSort,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.warehouse, size: 16),
                        label: Text(
                          selectedWarehouse?.name ?? 'all'.tr(),
                          style: TextStyle(
                            fontWeight: selectedWarehouse != null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onPressed: _pickWarehouse,
                      ),
                      FilterChip(
                        selected: filter.includeZeroStock,
                        label: Text('include_zero_stock'.tr()),
                        avatar:
                            const Icon(Icons.inventory_2_outlined, size: 16),
                        onSelected: (v) {
                          ref
                              .read(stockValuationFilterProvider.notifier)
                              .state = filter.copyWith(includeZeroStock: v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: dataAsync.when(
                data: (data) {
                  if (data.products.isEmpty) {
                    return _EmptyState();
                  }
                  return _Body(
                    data: data,
                    isExporting: _isExporting,
                    expandedProducts: _expandedProducts,
                    onToggleExpand: (id) {
                      setState(() {
                        if (_expandedProducts.contains(id)) {
                          _expandedProducts.remove(id);
                        } else {
                          _expandedProducts.add(id);
                        }
                      });
                    },
                    onShare: () => _exportPdf(data, share: true),
                    onPrint: () => _exportPdf(data, share: false),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('error_label'.tr(args: ['$e'])),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final StockValuationModel data;
  final bool isExporting;
  final Set<String> expandedProducts;
  final void Function(String id) onToggleExpand;
  final VoidCallback onShare;
  final VoidCallback onPrint;

  const _Body({
    required this.data,
    required this.isExporting,
    required this.expandedProducts,
    required this.onToggleExpand,
    required this.onShare,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final cross = constraints.maxWidth > 900 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: cross,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.4,
                    children: [
                      _SummaryCard(
                        label: 'products_count'.tr(),
                        value: '${data.productCount}',
                        color: AppColors.info,
                      ),
                      _SummaryCard(
                        label: 'total_cost_value'.tr(),
                        value: data.totalCostValue.toStringAsFixed(2),
                        color: AppColors.primary,
                      ),
                      _SummaryCard(
                        label: 'total_sales_value'.tr(),
                        value: data.totalSalesValue.toStringAsFixed(2),
                        color: AppColors.success,
                      ),
                      _SummaryCard(
                        label: 'expected_profit'.tr(),
                        value: '${data.totalExpectedProfit.toStringAsFixed(2)} '
                            '(${data.overallProfitMargin.toStringAsFixed(1)}%)',
                        color: AppColors.success,
                        bold: true,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${'total_quantity'.tr()}: '
                        '${data.totalQuantity.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${'warehouses_count'.tr()}: ${data.warehouseCount}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: isExporting ? null : onShare,
                    icon: isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text('export_pdf'.tr()),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: isExporting ? null : onPrint,
                    icon: const Icon(Icons.print),
                    label: Text('print_report'.tr()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 1100),
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(
                        AppColors.primary.withValues(alpha: 0.08),
                      ),
                      columns: [
                        const DataColumn(label: Text('')),
                        const DataColumn(label: Text('#')),
                        DataColumn(label: Text('product'.tr())),
                        DataColumn(label: Text('unit'.tr())),
                        DataColumn(
                          label: Text('quantity'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('purchase_price'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('selling_price'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('cost_value'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('sales_value'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('expected_profit'.tr()),
                          numeric: true,
                        ),
                        DataColumn(label: Text('margin'.tr())),
                      ],
                      rows: [
                        for (var i = 0; i < data.products.length; i++)
                          ..._buildRows(context, i, data.products[i]),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DataRow> _buildRows(
    BuildContext context,
    int index,
    StockValuationProduct p,
  ) {
    final isExpanded = expandedProducts.contains(p.productId);
    final hasMultipleWarehouses = p.warehouses.length > 1;

    final mainRow = DataRow(
      cells: [
        DataCell(
          hasMultipleWarehouses
              ? IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  onPressed: () => onToggleExpand(p.productId),
                  tooltip: 'show_warehouses'.tr(),
                )
              : const SizedBox(width: 40),
        ),
        DataCell(Text('${index + 1}')),
        DataCell(
          InkWell(
            onTap: () => context.push('/products/${p.productId}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
                Text(
                  p.productCode,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(Text(UnitTranslator.translate(p.unit))),
        DataCell(Text(
          p.totalQuantity.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        )),
        DataCell(Text(p.purchasePrice.toStringAsFixed(2))),
        DataCell(Text(p.sellingPrice.toStringAsFixed(2))),
        DataCell(Text(
          p.costValue.toStringAsFixed(2),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        )),
        DataCell(Text(
          p.salesValue.toStringAsFixed(2),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.success,
          ),
        )),
        DataCell(Text(
          p.expectedProfit.toStringAsFixed(2),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: p.expectedProfit >= 0 ? AppColors.success : AppColors.error,
          ),
        )),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: (p.profitMargin >= 0 ? AppColors.success : AppColors.error)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${p.profitMargin.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: p.profitMargin >= 0 ? AppColors.success : AppColors.error,
            ),
          ),
        )),
      ],
    );

    if (!isExpanded || !hasMultipleWarehouses) {
      return [mainRow];
    }

    final subRows = p.warehouses.map((w) {
      return DataRow(
        color: WidgetStatePropertyAll(
          AppColors.backgroundLight.withValues(alpha: 0.5),
        ),
        cells: [
          const DataCell(SizedBox(width: 40)),
          const DataCell(Text('')),
          DataCell(Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Row(
              children: [
                const Icon(
                  Icons.warehouse_outlined,
                  size: 14,
                  color: AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 6),
                Text(
                  w.warehouseName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          )),
          DataCell(Text(UnitTranslator.translate(w.unit))),
          DataCell(Text(
            w.quantity.toStringAsFixed(2),
            style: const TextStyle(fontSize: 12),
          )),
          DataCell(Text(w.purchasePrice.toStringAsFixed(2),
              style: const TextStyle(fontSize: 12))),
          DataCell(Text(w.sellingPrice.toStringAsFixed(2),
              style: const TextStyle(fontSize: 12))),
          DataCell(Text(w.costValue.toStringAsFixed(2),
              style: const TextStyle(fontSize: 12))),
          DataCell(Text(w.salesValue.toStringAsFixed(2),
              style: const TextStyle(fontSize: 12))),
          DataCell(Text(w.expectedProfit.toStringAsFixed(2),
              style: const TextStyle(fontSize: 12))),
          DataCell(Text(
            '${w.profitMargin.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 11),
          )),
        ],
      );
    }).toList();

    return [mainRow, ...subRows];
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: bold ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 72,
              color: AppColors.textSecondaryLight.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'no_stock_to_value'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'no_stock_to_value_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehousePicker extends StatelessWidget {
  final List<WarehouseModel> warehouses;
  final String? currentId;

  const _WarehousePicker({
    required this.warehouses,
    this.currentId,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'select_warehouse'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.select_all),
              title: Text('all_warehouses'.tr()),
              selected: currentId == null,
              onTap: () => Navigator.pop(context, null),
            ),
            const Divider(height: 1),
            Expanded(
              child: warehouses.isEmpty
                  ? Center(child: Text('no_warehouses'.tr()))
                  : ListView.builder(
                      itemCount: warehouses.length,
                      itemBuilder: (context, i) {
                        final w = warehouses[i];
                        return ListTile(
                          leading: const Icon(Icons.warehouse_outlined),
                          title: Text(w.name),
                          selected: currentId == w.id,
                          onTap: () => Navigator.pop(context, w),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
