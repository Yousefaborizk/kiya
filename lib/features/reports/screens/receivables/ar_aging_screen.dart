import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../sales/models/customer_model.dart';
import '../../../../features/sales/providers/sales_provider.dart';
import '../../../../widgets/shared/app_bar_actions.dart';
import '../../../../widgets/shared/app_shell.dart';
import '../../data/models/ar_aging_model.dart';
import '../../providers/reports_provider.dart';
import '../../utils/ar_aging_pdf.dart';

class ArAgingScreen extends ConsumerStatefulWidget {
  const ArAgingScreen({super.key});

  @override
  ConsumerState<ArAgingScreen> createState() => _ArAgingScreenState();
}

class _ArAgingScreenState extends ConsumerState<ArAgingScreen> {
  bool _isExporting = false;
  bool _showOverdueOnly = false;

  // ============================================
  // Actions
  // ============================================
  Future<void> _pickAsOfDate() async {
    final filter = ref.read(arAgingFilterProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: filter.asOfDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    ref.read(arAgingFilterProvider.notifier).state =
        filter.copyWith(asOfDate: picked);
  }

  Future<void> _pickCustomer() async {
    final customers = await ref.read(customersListProvider.future);
    if (!mounted) return;

    final selected = await showDialog<_CustomerOrAll>(
      context: context,
      builder: (context) => _CustomerPickerDialog(
        customers: customers,
        currentId: ref.read(arAgingFilterProvider).customerId,
      ),
    );
    if (selected == null || !mounted) return;

    final filter = ref.read(arAgingFilterProvider);
    if (selected.customer == null) {
      ref.read(arAgingFilterProvider.notifier).state =
          filter.copyWith(clearCustomer: true);
    } else {
      ref.read(arAgingFilterProvider.notifier).state =
          filter.copyWith(customerId: selected.customer!.id);
    }
  }

  Future<void> _exportPdf(ArAgingModel data, {required bool share}) async {
    setState(() => _isExporting = true);
    try {
      final lang = context.locale.languageCode;
      if (share) {
        await ArAgingPdf.share(data, langCode: lang);
      } else {
        await ArAgingPdf.print(data, langCode: lang);
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
    final filter = ref.watch(arAgingFilterProvider);
    final dataAsync = ref.watch(arAgingProvider);
    final customersAsync = ref.watch(customersListProvider);

    final selectedCustomer = filter.customerId == null
        ? null
        : customersAsync.valueOrNull
            ?.where((c) => c.id == filter.customerId)
            .firstOrNull;

    return AppShell(
      currentRoute: '/reports',
      child: Scaffold(
        appBar: AppBar(
          title: Text('ar_aging'.tr()),
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
              onPressed: () => ref.invalidate(arAgingProvider),
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
                        avatar: const Icon(Icons.event, size: 16),
                        label: Text(
                          '${'as_of_date'.tr()}: ${_fmt(filter.asOfDate)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _pickAsOfDate,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.person_outline, size: 16),
                        label: Text(
                          selectedCustomer == null
                              ? 'all_customers'.tr()
                              : selectedCustomer.name,
                          style: TextStyle(
                            fontWeight: selectedCustomer != null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onPressed: _pickCustomer,
                      ),
                      FilterChip(
                        selected: _showOverdueOnly,
                        label: Text('show_overdue_only'.tr()),
                        avatar: const Icon(Icons.warning_amber, size: 16),
                        onSelected: (v) => setState(() => _showOverdueOnly = v),
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
                    return _EmptyState(asOfDate: data.asOfDate);
                  }
                  final visible = _showOverdueOnly
                      ? data.rows.where((r) => r.hasOverdue).toList()
                      : data.rows;
                  return _AgingBody(
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

// ============================================
// Body
// ============================================
class _AgingBody extends StatelessWidget {
  final ArAgingModel data;
  final List<ArAgingCustomerRow> visibleRows;
  final bool isExporting;
  final VoidCallback onShare;
  final VoidCallback onPrint;

  const _AgingBody({
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
              // ── Summary cards ─────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final cross = constraints.maxWidth > 1200
                      ? 6
                      : constraints.maxWidth > 800
                          ? 3
                          : constraints.maxWidth > 500
                              ? 2
                              : 1;
                  return GridView.count(
                    crossAxisCount: cross,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children: [
                      _BucketCard(
                        label: 'aging_current'.tr(),
                        value: data.totalCurrent,
                        color: AppColors.info,
                      ),
                      _BucketCard(
                        label: 'aging_1_30'.tr(),
                        value: data.total1To30,
                        color: AppColors.warning,
                      ),
                      _BucketCard(
                        label: 'aging_31_60'.tr(),
                        value: data.total31To60,
                        color: AppColors.warning,
                      ),
                      _BucketCard(
                        label: 'aging_61_90'.tr(),
                        value: data.total61To90,
                        color: AppColors.error,
                      ),
                      _BucketCard(
                        label: 'aging_90_plus'.tr(),
                        value: data.totalOver90,
                        color: AppColors.error,
                      ),
                      _BucketCard(
                        label: 'grand_total'.tr(),
                        value: data.grandTotal,
                        color: AppColors.primary,
                        bold: true,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // ── Overdue indicator ─────────────────
              if (data.grandTotal > 0)
                Card(
                  color: data.totalOverdue > 0
                      ? AppColors.error.withValues(alpha: 0.06)
                      : AppColors.success.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          data.totalOverdue > 0
                              ? Icons.warning_amber
                              : Icons.check_circle,
                          color: data.totalOverdue > 0
                              ? AppColors.error
                              : AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${'overdue_amount'.tr()}: '
                            '${data.totalOverdue.toStringAsFixed(2)} '
                            '(${data.overduePercent.toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: data.totalOverdue > 0
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                          ),
                        ),
                        Text(
                          '${data.customerCount} ${'customers_count'.tr()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // ── Export actions ────────────────────
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

              // ── Table ─────────────────────────────
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
                        const DataColumn(label: Text('#')),
                        DataColumn(label: Text('customer'.tr())),
                        DataColumn(label: Text('phone'.tr())),
                        DataColumn(
                          label: Text('aging_current'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('aging_1_30'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('aging_31_60'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('aging_61_90'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('aging_90_plus'.tr()),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('total'.tr()),
                          numeric: true,
                        ),
                        DataColumn(label: Text('invoices_count'.tr())),
                      ],
                      rows: [
                        for (var i = 0; i < visibleRows.length; i++)
                          _buildRow(i, visibleRows[i]),
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
                        child: _TotalsRow(
                          data: data,
                          visibleRows: visibleRows,
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

  DataRow _buildRow(int index, ArAgingCustomerRow r) {
    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                r.customerName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (r.customerCode != null)
                Text(
                  r.customerCode!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
            ],
          ),
        ),
        DataCell(Text(r.phone ?? '-')),
        DataCell(_amt(r.current)),
        DataCell(_amt(r.days1To30, color: AppColors.warning)),
        DataCell(_amt(r.days31To60, color: AppColors.warning)),
        DataCell(_amt(r.days61To90, color: AppColors.error)),
        DataCell(_amt(r.over90, color: AppColors.error)),
        DataCell(
          Text(
            r.totalOutstanding.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataCell(Text('${r.invoiceCount}')),
      ],
    );
  }

  Widget _amt(double v, {Color? color}) {
    if (v <= 0.001) return const Text('-');
    return Text(
      v.toStringAsFixed(2),
      style: TextStyle(fontWeight: FontWeight.bold, color: color),
    );
  }
}

// ============================================
// Totals row (non-DataTable, manual)
// ============================================
class _TotalsRow extends StatelessWidget {
  final ArAgingModel data;
  final List<ArAgingCustomerRow> visibleRows;

  const _TotalsRow({required this.data, required this.visibleRows});

  @override
  Widget build(BuildContext context) {
    double cur = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, tot = 0;
    for (final r in visibleRows) {
      cur += r.current;
      b1 += r.days1To30;
      b2 += r.days31To60;
      b3 += r.days61To90;
      b4 += r.over90;
      tot += r.totalOutstanding;
    }
    return Row(
      children: [
        Expanded(child: _cell(cur)),
        Expanded(child: _cell(b1)),
        Expanded(child: _cell(b2)),
        Expanded(child: _cell(b3)),
        Expanded(child: _cell(b4)),
        Expanded(child: _cell(tot, bold: true)),
        const SizedBox(width: 100),
      ],
    );
  }

  Widget _cell(double v, {bool bold = false}) => Text(
        v.toStringAsFixed(2),
        textAlign: TextAlign.end,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: bold ? AppColors.primary : null,
          fontSize: 13,
        ),
      );
}

// ============================================
// Bucket card
// ============================================
class _BucketCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool bold;

  const _BucketCard({
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
              value.toStringAsFixed(2),
              style: TextStyle(
                fontSize: bold ? 22 : 18,
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
  final DateTime asOfDate;
  const _EmptyState({required this.asOfDate});

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
              'no_outstanding_balances'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${'as_of_date'.tr()}: ${asOfDate.year}-'
              '${asOfDate.month.toString().padLeft(2, '0')}-'
              '${asOfDate.day.toString().padLeft(2, '0')}',
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

// ============================================
// Customer picker dialog
// ============================================
class _CustomerOrAll {
  final CustomerModel? customer;
  const _CustomerOrAll(this.customer);
}

class _CustomerPickerDialog extends StatefulWidget {
  final List<CustomerModel> customers;
  final String? currentId;

  const _CustomerPickerDialog({
    required this.customers,
    this.currentId,
  });

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers.where((c) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          (c.customerCode?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'search_customer_hint'.tr(),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.select_all),
              title: Text('all_customers'.tr()),
              selected: widget.currentId == null,
              onTap: () => Navigator.pop(context, const _CustomerOrAll(null)),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text('no_customers'.tr()))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                            ),
                          ),
                          title: Text(c.name),
                          subtitle: c.customerCode != null
                              ? Text(c.customerCode!)
                              : null,
                          selected: widget.currentId == c.id,
                          onTap: () => Navigator.pop(
                            context,
                            _CustomerOrAll(c),
                          ),
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
