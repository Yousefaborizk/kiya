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
import '../../data/models/stock_movement_model.dart';
import '../../providers/reports_provider.dart';
import '../../utils/stock_movement_pdf.dart';

class StockMovementReportScreen extends ConsumerStatefulWidget {
  const StockMovementReportScreen({super.key});

  @override
  ConsumerState<StockMovementReportScreen> createState() =>
      _StockMovementReportScreenState();
}

class _StockMovementReportScreenState
    extends ConsumerState<StockMovementReportScreen> {
  bool _isExporting = false;
  StockMovementType? _filterType;

  Future<void> _pickDateRange() async {
    final f = ref.read(stockMovementFilterProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: f.fromDate, end: f.toDate),
    );
    if (picked == null || !mounted) return;
    ref.read(stockMovementFilterProvider.notifier).state =
        f.copyWith(fromDate: picked.start, toDate: picked.end);
  }

  Future<void> _pickSort() async {
    final f = ref.read(stockMovementFilterProvider);
    final selected = await showDialog<StockMovementSort>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('sort_by'.tr()),
        children: StockMovementSort.values
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, s),
                  child: Row(children: [
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
                  ]),
                ))
            .toList(),
      ),
    );
    if (selected == null || !mounted) return;
    ref.read(stockMovementFilterProvider.notifier).state =
        f.copyWith(sort: selected);
  }

  Future<void> _pickWarehouse() async {
    final warehouses = await ref.read(warehousesListProvider.future);
    if (!mounted) return;
    final selected = await showDialog<WarehouseModel?>(
      context: context,
      builder: (context) => _WarehousePicker(
        warehouses: warehouses,
        currentId: ref.read(stockMovementFilterProvider).warehouseId,
      ),
    );
    if (!mounted) return;
    final f = ref.read(stockMovementFilterProvider);
    if (selected == null) {
      ref.read(stockMovementFilterProvider.notifier).state =
          f.copyWith(clearWarehouse: true);
    } else {
      ref.read(stockMovementFilterProvider.notifier).state =
          f.copyWith(warehouseId: selected.id);
    }
  }

  Future<void> _exportPdf(StockMovementModel data,
      {required bool share}) async {
    setState(() => _isExporting = true);
    try {
      final lang = context.locale.languageCode;
      if (share) {
        await StockMovementPdf.share(data, langCode: lang);
      } else {
        await StockMovementPdf.print(data, langCode: lang);
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
    final filter = ref.watch(stockMovementFilterProvider);
    final dataAsync = ref.watch(stockMovementProvider);
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
          title: Text('stock_movement'.tr()),
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
              onPressed: () => ref.invalidate(stockMovementProvider),
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
                        avatar: const Icon(Icons.date_range, size: 16),
                        label: Text(
                            '${_fmt(filter.fromDate)} → ${_fmt(filter.toDate)}'),
                        onPressed: _pickDateRange,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.sort, size: 16),
                        label: Text(filter.sort.labelKey.tr()),
                        onPressed: _pickSort,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.warehouse, size: 16),
                        label: Text(selectedWarehouse?.name ?? 'all'.tr()),
                        onPressed: _pickWarehouse,
                      ),
                      _TypeChip(
                        label: 'all'.tr(),
                        selected: _filterType == null,
                        color: AppColors.primary,
                        onTap: () => setState(() => _filterType = null),
                      ),
                      _TypeChip(
                        label: 'in'.tr(),
                        selected: _filterType == StockMovementType.in_,
                        color: AppColors.success,
                        onTap: () =>
                            setState(() => _filterType = StockMovementType.in_),
                      ),
                      _TypeChip(
                        label: 'out'.tr(),
                        selected: _filterType == StockMovementType.out,
                        color: AppColors.error,
                        onTap: () =>
                            setState(() => _filterType = StockMovementType.out),
                      ),
                      _TypeChip(
                        label: 'adjustment'.tr(),
                        selected: _filterType == StockMovementType.adjustment,
                        color: AppColors.warning,
                        onTap: () => setState(
                            () => _filterType = StockMovementType.adjustment),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: dataAsync.when(
                data: (data) {
                  if (data.rows.isEmpty) return _EmptyState();
                  final visible = _filterType == null
                      ? data.rows
                      : data.rows.where((r) => r.type == _filterType).toList();
                  return _Body(
                    data: data,
                    visibleRows: visible,
                    isExporting: _isExporting,
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

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.borderLight),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? color : AppColors.textPrimaryLight,
            )),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final StockMovementModel data;
  final List<StockMovementRow> visibleRows;
  final bool isExporting;
  final VoidCallback onShare;
  final VoidCallback onPrint;

  const _Body({
    required this.data,
    required this.visibleRows,
    required this.isExporting,
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
                          label: 'total_in'.tr(),
                          value:
                              '${data.totalIn.toStringAsFixed(2)} (${data.inCount})',
                          color: AppColors.success),
                      _SummaryCard(
                          label: 'total_out'.tr(),
                          value:
                              '${data.totalOut.toStringAsFixed(2)} (${data.outCount})',
                          color: AppColors.error),
                      _SummaryCard(
                          label: 'total_adjustment'.tr(),
                          value:
                              '${data.totalAdjustment.toStringAsFixed(2)} (${data.adjustmentCount})',
                          color: AppColors.warning),
                      _SummaryCard(
                          label: 'total_movements'.tr(),
                          value: '${data.totalMovements}',
                          color: AppColors.primary,
                          bold: true),
                    ],
                  );
                },
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
                                strokeWidth: 2, color: Colors.white))
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
                    constraints: const BoxConstraints(minWidth: 1000),
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(
                          AppColors.primary.withValues(alpha: 0.08)),
                      columns: [
                        const DataColumn(label: Text('#')),
                        DataColumn(label: Text('date'.tr())),
                        DataColumn(label: Text('product'.tr())),
                        DataColumn(label: Text('warehouse'.tr())),
                        DataColumn(label: Text('type'.tr())),
                        DataColumn(label: Text('quantity'.tr()), numeric: true),
                        DataColumn(
                            label: Text('unit_price'.tr()), numeric: true),
                        DataColumn(
                            label: Text('total_value'.tr()), numeric: true),
                      ],
                      rows: [
                        for (var i = 0; i < visibleRows.length; i++)
                          _buildRow(context, i, visibleRows[i]),
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

  DataRow _buildRow(BuildContext context, int index, StockMovementRow r) {
    return DataRow(cells: [
      DataCell(Text('${index + 1}')),
      DataCell(Text(_fmtDate(r.date))),
      DataCell(InkWell(
        onTap: () => context.push('/products/${r.productId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(r.productName,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline)),
            Text(r.productCode,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondaryLight)),
          ],
        ),
      )),
      DataCell(Text(r.warehouseName)),
      DataCell(_TypeBadge(type: r.type)),
      DataCell(Text(
        '${r.quantity.toStringAsFixed(2)} ${UnitTranslator.translate(r.unit)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      )),
      DataCell(Text(r.unitPrice.toStringAsFixed(2))),
      DataCell(Text(r.totalValue.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.bold))),
    ]);
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _TypeBadge extends StatelessWidget {
  final StockMovementType type;
  const _TypeBadge({required this.type});

  Color get _color {
    switch (type) {
      case StockMovementType.in_:
        return AppColors.success;
      case StockMovementType.out:
        return AppColors.error;
      case StockMovementType.adjustment:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(type.labelKey.tr(),
          style: TextStyle(
              color: _color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
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
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondaryLight),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(value,
                style: TextStyle(
                    fontSize: bold ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
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
            Icon(Icons.swap_horiz,
                size: 72,
                color: AppColors.textSecondaryLight.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('no_movements_in_period'.tr(),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('no_movements_in_period_subtitle'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondaryLight)),
          ],
        ),
      ),
    );
  }
}

class _WarehousePicker extends StatelessWidget {
  final List<WarehouseModel> warehouses;
  final String? currentId;
  const _WarehousePicker({required this.warehouses, this.currentId});

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
                child: Text('select_warehouse'.tr(),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold))),
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
