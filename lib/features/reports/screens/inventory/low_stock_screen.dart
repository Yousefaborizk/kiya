import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../utils/unit_translator.dart';
import '../../../../widgets/shared/app_bar_actions.dart';
import '../../../../widgets/shared/app_shell.dart';
import '../../data/models/low_stock_model.dart';
import '../../providers/reports_provider.dart';
import '../../utils/low_stock_pdf.dart';

class LowStockScreen extends ConsumerStatefulWidget {
  const LowStockScreen({super.key});

  @override
  ConsumerState<LowStockScreen> createState() => _LowStockScreenState();
}

class _LowStockScreenState extends ConsumerState<LowStockScreen> {
  bool _isExporting = false;
  LowStockSeverity? _filterSeverity;

  Future<void> _pickSort() async {
    final f = ref.read(lowStockFilterProvider);
    final selected = await showDialog<LowStockSort>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('sort_by'.tr()),
        children: LowStockSort.values
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
    ref.read(lowStockFilterProvider.notifier).state =
        f.copyWith(sort: selected);
  }

  Future<void> _exportPdf(LowStockModel data, {required bool share}) async {
    setState(() => _isExporting = true);
    try {
      final lang = context.locale.languageCode;
      if (share) {
        await LowStockPdf.share(data, langCode: lang);
      } else {
        await LowStockPdf.print(data, langCode: lang);
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
    final filter = ref.watch(lowStockFilterProvider);
    final dataAsync = ref.watch(lowStockProvider);

    return AppShell(
      currentRoute: '/reports',
      child: Scaffold(
        appBar: AppBar(
          title: Text('low_stock'.tr()),
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
              onPressed: () => ref.invalidate(lowStockProvider),
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
                      _SeverityChip(
                        label: 'all'.tr(),
                        selected: _filterSeverity == null,
                        color: AppColors.primary,
                        onTap: () => setState(() => _filterSeverity = null),
                      ),
                      _SeverityChip(
                        label: 'severity_out_of_stock'.tr(),
                        selected:
                            _filterSeverity == LowStockSeverity.outOfStock,
                        color: AppColors.error,
                        onTap: () => setState(
                          () => _filterSeverity = LowStockSeverity.outOfStock,
                        ),
                      ),
                      _SeverityChip(
                        label: 'severity_critical'.tr(),
                        selected: _filterSeverity == LowStockSeverity.critical,
                        color: AppColors.error,
                        onTap: () => setState(
                          () => _filterSeverity = LowStockSeverity.critical,
                        ),
                      ),
                      _SeverityChip(
                        label: 'severity_low'.tr(),
                        selected: _filterSeverity == LowStockSeverity.low,
                        color: AppColors.warning,
                        onTap: () => setState(
                          () => _filterSeverity = LowStockSeverity.low,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: dataAsync.when(
                data: (data) {
                  if (data.rows.isEmpty) {
                    return _EmptyState();
                  }
                  final visible = _filterSeverity == null
                      ? data.rows
                      : data.rows
                          .where((r) => r.severity == _filterSeverity)
                          .toList();
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
}

class _SeverityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SeverityChip({
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
          border: Border.all(
            color: selected ? color : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? color : AppColors.textPrimaryLight,
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final LowStockModel data;
  final List<LowStockRow> visibleRows;
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
                    childAspectRatio: 2.5,
                    children: [
                      _SummaryCard(
                        label: 'severity_out_of_stock'.tr(),
                        value: '${data.outOfStockCount}',
                        color: AppColors.error,
                      ),
                      _SummaryCard(
                        label: 'severity_critical'.tr(),
                        value: '${data.criticalCount}',
                        color: AppColors.error,
                      ),
                      _SummaryCard(
                        label: 'severity_low'.tr(),
                        value: '${data.lowCount}',
                        color: AppColors.warning,
                      ),
                      _SummaryCard(
                        label: 'total'.tr(),
                        value: '${data.totalCount}',
                        color: AppColors.primary,
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
                        '${'total_shortfall'.tr()}: '
                        '${data.totalShortfall.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${'products_count'.tr()}: ${data.totalCount}',
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
                    constraints: const BoxConstraints(minWidth: 1000),
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(
                        AppColors.primary.withValues(alpha: 0.08),
                      ),
                      columns: [
                        const DataColumn(label: Text('#')),
                        DataColumn(label: Text('product'.tr())),
                        DataColumn(label: Text('unit'.tr())),
                        DataColumn(
                          label: Text('current_stock'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('min_level'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('shortfall'.tr()),
                          numeric: true,
                        ),
                        DataColumn(label: Text('severity'.tr())),
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

  DataRow _buildRow(BuildContext context, int index, LowStockRow r) {
    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(
          InkWell(
            onTap: () => context.push('/products/${r.productId}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  r.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
                Text(
                  r.productCode,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(Text(UnitTranslator.translate(r.unit))),
        DataCell(Text(
          r.currentStock.toStringAsFixed(2),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: r.isOutOfStock ? AppColors.error : null,
          ),
        )),
        DataCell(Text(
          '${r.minStockLevel}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        )),
        DataCell(Text(
          r.shortfall.toStringAsFixed(2),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.error,
          ),
        )),
        DataCell(_SeverityBadge(severity: r.severity)),
      ],
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final LowStockSeverity severity;
  const _SeverityBadge({required this.severity});

  Color get _color {
    switch (severity) {
      case LowStockSeverity.outOfStock:
        return AppColors.error;
      case LowStockSeverity.critical:
        return AppColors.error;
      case LowStockSeverity.low:
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
      child: Text(
        severity.labelKey.tr(),
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
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
                fontSize: bold ? 26 : 24,
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
              Icons.check_circle_outline,
              size: 72,
              color: AppColors.success.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'all_stock_sufficient'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'all_stock_sufficient_subtitle'.tr(),
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
