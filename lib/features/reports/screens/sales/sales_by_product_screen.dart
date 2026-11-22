import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/shared/app_bar_actions.dart';
import '../../../../widgets/shared/app_shell.dart';
import '../../data/models/sales_by_product_model.dart';
import '../../providers/reports_provider.dart';
import '../../utils/sales_by_product_pdf.dart';

class SalesByProductScreen extends ConsumerStatefulWidget {
  const SalesByProductScreen({super.key});

  @override
  ConsumerState<SalesByProductScreen> createState() =>
      _SalesByProductScreenState();
}

class _SalesByProductScreenState extends ConsumerState<SalesByProductScreen> {
  bool _isExporting = false;

  // ============================================
  // Actions
  // ============================================
  Future<void> _pickDateRange() async {
    final f = ref.read(salesByProductFilterProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: f.fromDate, end: f.toDate),
    );
    if (picked == null || !mounted) return;
    ref.read(salesByProductFilterProvider.notifier).state =
        f.copyWith(fromDate: picked.start, toDate: picked.end);
  }

  Future<void> _pickSort() async {
    final f = ref.read(salesByProductFilterProvider);
    final selected = await showDialog<SalesByProductSort>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('sort_by'.tr()),
        children: SalesByProductSort.values
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
    ref.read(salesByProductFilterProvider.notifier).state =
        f.copyWith(sort: selected);
  }

  Future<void> _exportPdf(SalesByProductModel data,
      {required bool share}) async {
    setState(() => _isExporting = true);
    try {
      final lang = context.locale.languageCode;
      if (share) {
        await SalesByProductPdf.share(data, langCode: lang);
      } else {
        await SalesByProductPdf.print(data, langCode: lang);
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

  // ============================================
  // Build
  // ============================================
  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(salesByProductFilterProvider);
    final dataAsync = ref.watch(salesByProductProvider);

    return AppShell(
      currentRoute: '/reports',
      child: Scaffold(
        appBar: AppBar(
          title: Text('sales_by_product'.tr()),
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
              onPressed: () => ref.invalidate(salesByProductProvider),
            ),
            const AppBarActions(),
          ],
        ),
        body: Column(
          children: [
            // ── Filter bar ──────────────────────────
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
                          '${_fmt(filter.fromDate)} → ${_fmt(filter.toDate)}',
                        ),
                        onPressed: _pickDateRange,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.sort, size: 16),
                        label: Text(filter.sort.labelKey.tr()),
                        onPressed: _pickSort,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ── Body ────────────────────────────────
            Expanded(
              child: dataAsync.when(
                data: (data) {
                  if (data.rows.isEmpty) {
                    return _EmptyState();
                  }
                  return _Body(
                    data: data,
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

// ============================================
// Body
// ============================================
class _Body extends StatelessWidget {
  final SalesByProductModel data;
  final bool isExporting;
  final VoidCallback onShare;
  final VoidCallback onPrint;

  const _Body({
    required this.data,
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
              // ── Summary cards ────────────────────
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
                        label: 'total_quantity'.tr(),
                        value: data.totalQuantity.toStringAsFixed(2),
                        color: AppColors.info,
                      ),
                      _SummaryCard(
                        label: 'gross_sales'.tr(),
                        value: data.totalGross.toStringAsFixed(2),
                        color: AppColors.primary,
                      ),
                      _SummaryCard(
                        label: 'discount_amount'.tr(),
                        value: data.totalDiscount.toStringAsFixed(2),
                        color: AppColors.warning,
                      ),
                      _SummaryCard(
                        label: 'net_sales'.tr(),
                        value: data.totalNet.toStringAsFixed(2),
                        color: AppColors.success,
                        bold: true,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // ── Meta info ────────────────────────
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
                        '${'products_count'.tr()}: ${data.productCount}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${'invoices_count'.tr()}: ${data.totalInvoices}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Export buttons ───────────────────
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

              // ── Table ────────────────────────────
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
                          label: Text('quantity'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('gross_sales'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('discount'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('net_sales'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('avg_price'.tr()),
                          numeric: true,
                        ),
                        DataColumn(label: Text('invoices'.tr())),
                      ],
                      rows: [
                        for (var i = 0; i < data.rows.length; i++)
                          _buildRow(i, data.rows[i]),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Totals row ────────────────────────
              const SizedBox(height: 8),
              Card(
                color: AppColors.primary.withValues(alpha: 0.06),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 100,
                        child: Text(
                          'total',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${'products_count'.tr()}: ${data.productCount}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: _tot(
                          data.totalQuantity.toStringAsFixed(2),
                        ),
                      ),
                      Expanded(
                        child: _tot(
                          data.totalGross.toStringAsFixed(2),
                        ),
                      ),
                      Expanded(
                        child: _tot(
                          data.totalDiscount.toStringAsFixed(2),
                          color: AppColors.warning,
                        ),
                      ),
                      Expanded(
                        child: _tot(
                          data.totalNet.toStringAsFixed(2),
                          color: AppColors.success,
                          bold: true,
                        ),
                      ),
                      const Spacer(),
                      Expanded(
                        child: Text(
                          '${data.totalInvoices}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tot(String v, {Color? color, bool bold = false}) => Text(
        v,
        textAlign: TextAlign.end,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? (bold ? AppColors.primary : null),
          fontSize: 13,
        ),
      );

  DataRow _buildRow(int index, SalesByProductRow r) {
    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                r.productName,
                style: const TextStyle(fontWeight: FontWeight.w600),
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
        DataCell(Text(r.unit)),
        DataCell(Text(
          r.quantitySold.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        )),
        DataCell(Text(r.grossAmount.toStringAsFixed(2))),
        DataCell(Text(
          r.discountAmount > 0.001 ? r.discountAmount.toStringAsFixed(2) : '-',
          style: TextStyle(
            color: r.discountAmount > 0.001 ? AppColors.warning : null,
          ),
        )),
        DataCell(Text(
          r.netAmount.toStringAsFixed(2),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.success,
          ),
        )),
        DataCell(Text(r.averagePrice.toStringAsFixed(2))),
        DataCell(Text('${r.invoiceCount}')),
      ],
    );
  }
}

// ============================================
// Summary card
// ============================================
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
                fontSize: bold ? 22 : 20,
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

// ============================================
// Empty state
// ============================================
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
              Icons.trending_up,
              size: 72,
              color: AppColors.textSecondaryLight.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'no_sales_in_period'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'no_sales_in_period_subtitle'.tr(),
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
