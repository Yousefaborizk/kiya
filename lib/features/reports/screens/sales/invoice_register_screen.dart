import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/shared/app_bar_actions.dart';
import '../../../../widgets/shared/app_shell.dart';
import '../../data/models/invoice_register_model.dart';
import '../../providers/reports_provider.dart';
import '../../utils/invoice_register_pdf.dart';

class InvoiceRegisterScreen extends ConsumerStatefulWidget {
  const InvoiceRegisterScreen({super.key});

  @override
  ConsumerState<InvoiceRegisterScreen> createState() =>
      _InvoiceRegisterScreenState();
}

class _InvoiceRegisterScreenState extends ConsumerState<InvoiceRegisterScreen> {
  bool _isExporting = false;

  Future<void> _pickDateRange() async {
    final f = ref.read(invoiceRegisterFilterProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: f.fromDate, end: f.toDate),
    );
    if (picked == null || !mounted) return;
    ref.read(invoiceRegisterFilterProvider.notifier).state =
        f.copyWith(fromDate: picked.start, toDate: picked.end);
  }

  Future<void> _pickStatus() async {
    final f = ref.read(invoiceRegisterFilterProvider);
    final selected = await showDialog<InvoiceRegisterStatus>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('status'.tr()),
        children: InvoiceRegisterStatus.values
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, s),
                  child: Row(children: [
                    Icon(
                      s == f.status
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 18,
                      color: s == f.status
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
    ref.read(invoiceRegisterFilterProvider.notifier).state =
        f.copyWith(status: selected);
  }

  Future<void> _pickSort() async {
    final f = ref.read(invoiceRegisterFilterProvider);
    final selected = await showDialog<InvoiceRegisterSort>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('sort_by'.tr()),
        children: InvoiceRegisterSort.values
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
    ref.read(invoiceRegisterFilterProvider.notifier).state =
        f.copyWith(sort: selected);
  }

  Future<void> _exportPdf(InvoiceRegisterModel data,
      {required bool share}) async {
    setState(() => _isExporting = true);
    try {
      final lang = context.locale.languageCode;
      if (share) {
        await InvoiceRegisterPdf.share(data, langCode: lang);
      } else {
        await InvoiceRegisterPdf.print(data, langCode: lang);
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
    final filter = ref.watch(invoiceRegisterFilterProvider);
    final dataAsync = ref.watch(invoiceRegisterProvider);

    return AppShell(
      currentRoute: '/reports',
      child: Scaffold(
        appBar: AppBar(
          title: Text('invoice_register'.tr()),
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
              onPressed: () => ref.invalidate(invoiceRegisterProvider),
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
                        avatar: const Icon(Icons.filter_alt, size: 16),
                        label: Text(filter.status.labelKey.tr()),
                        onPressed: _pickStatus,
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
            Expanded(
              child: dataAsync.when(
                data: (data) {
                  if (data.rows.isEmpty) return _EmptyState();
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

class _Body extends StatelessWidget {
  final InvoiceRegisterModel data;
  final bool isExporting;
  final VoidCallback onShare;
  final VoidCallback onPrint;

  const _Body(
      {required this.data,
      required this.isExporting,
      required this.onShare,
      required this.onPrint});

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
                        label: 'invoices_count'.tr(),
                        value: '${data.invoiceCount}',
                        color: AppColors.primary,
                        subtitle:
                            '${data.paidCount} ${'paid'.tr()} · ${data.unpaidCount} ${'unpaid'.tr()}',
                      ),
                      _SummaryCard(
                        label: 'total_amount'.tr(),
                        value: data.totalAmount.toStringAsFixed(2),
                        color: AppColors.info,
                      ),
                      _SummaryCard(
                        label: 'total_paid'.tr(),
                        value: data.totalPaid.toStringAsFixed(2),
                        color: AppColors.success,
                      ),
                      _SummaryCard(
                        label: 'total_remaining'.tr(),
                        value: data.totalRemaining.toStringAsFixed(2),
                        color: AppColors.error,
                        subtitle: data.overdueCount > 0
                            ? '${data.overdueCount} ${'overdue'.tr()}'
                            : null,
                      ),
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
                    constraints: const BoxConstraints(minWidth: 1200),
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(
                          AppColors.primary.withValues(alpha: 0.08)),
                      columns: [
                        const DataColumn(label: Text('#')),
                        DataColumn(label: Text('invoice_number'.tr())),
                        DataColumn(label: Text('date'.tr())),
                        DataColumn(label: Text('customer'.tr())),
                        DataColumn(label: Text('status'.tr())),
                        DataColumn(label: Text('subtotal'.tr()), numeric: true),
                        DataColumn(label: Text('discount'.tr()), numeric: true),
                        DataColumn(label: Text('tax'.tr()), numeric: true),
                        DataColumn(label: Text('total'.tr()), numeric: true),
                        DataColumn(label: Text('paid'.tr()), numeric: true),
                        DataColumn(
                            label: Text('remaining'.tr()), numeric: true),
                      ],
                      rows: [
                        for (var i = 0; i < data.rows.length; i++)
                          _buildRow(context, i, data.rows[i]),
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

  DataRow _buildRow(BuildContext context, int index, InvoiceRegisterRow r) {
    return DataRow(cells: [
      DataCell(Text('${index + 1}')),
      DataCell(InkWell(
        onTap: () => context.push('/sales/${r.id}'),
        child: Text(r.invoiceNumber,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline)),
      )),
      DataCell(Text(_fmt(r.invoiceDate))),
      DataCell(r.customerId != null
          ? InkWell(
              onTap: () => context.push('/sales/customers/${r.customerId}'),
              child: Text(r.customerName ?? '-',
                  style: const TextStyle(decoration: TextDecoration.underline)),
            )
          : Text(r.customerName ?? '-')),
      DataCell(_StatusBadge(row: r)),
      DataCell(Text(r.subtotal.toStringAsFixed(2))),
      DataCell(Text(r.discount > 0.001 ? r.discount.toStringAsFixed(2) : '-',
          style:
              TextStyle(color: r.discount > 0.001 ? AppColors.warning : null))),
      DataCell(Text(r.tax > 0.001 ? r.tax.toStringAsFixed(2) : '-')),
      DataCell(Text(r.total.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Text(r.paidAmount.toStringAsFixed(2),
          style: const TextStyle(color: AppColors.success))),
      DataCell(Text(r.remaining.toStringAsFixed(2),
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color:
                  r.remaining > 0.01 ? AppColors.error : AppColors.success))),
    ]);
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _StatusBadge extends StatelessWidget {
  final InvoiceRegisterRow row;
  const _StatusBadge({required this.row});

  Color get _color {
    if (row.isCancelled) return AppColors.textSecondaryLight;
    if (row.isPaid) return AppColors.success;
    if (row.isOverdue) return AppColors.error;
    return AppColors.warning;
  }

  String get _label {
    if (row.isCancelled) return 'status_cancelled';
    if (row.isPaid) return 'status_paid';
    if (row.isOverdue) return 'overdue';
    return 'status_${row.status}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(_label.tr(),
          style: TextStyle(
              color: _color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? subtitle;
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.color,
      this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondaryLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondaryLight)),
              ],
            ),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
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
            Icon(Icons.receipt_long_outlined,
                size: 72,
                color: AppColors.textSecondaryLight.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('no_invoices_in_period'.tr(),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('no_invoices_in_period_subtitle'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondaryLight)),
          ],
        ),
      ),
    );
  }
}
