import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../sales/models/customer_model.dart';
import '../../../../features/sales/providers/sales_provider.dart';
import '../../../../widgets/shared/app_bar_actions.dart';
import '../../../../widgets/shared/app_shell.dart';
import '../../data/models/customer_statement_model.dart';
import '../../providers/reports_provider.dart';
import '../../utils/customer_statement_pdf.dart';

// ============================================
// Date presets
// ============================================
enum _DatePreset {
  today,
  thisWeek,
  thisMonth,
  thisQuarter,
  thisYear,
  lastYear,
  custom,
}

extension _PresetExt on _DatePreset {
  String get labelKey {
    switch (this) {
      case _DatePreset.today:
        return 'preset_today';
      case _DatePreset.thisWeek:
        return 'preset_this_week';
      case _DatePreset.thisMonth:
        return 'preset_this_month';
      case _DatePreset.thisQuarter:
        return 'preset_this_quarter';
      case _DatePreset.thisYear:
        return 'preset_this_year';
      case _DatePreset.lastYear:
        return 'preset_last_year';
      case _DatePreset.custom:
        return 'preset_custom';
    }
  }

  ({DateTime from, DateTime to}) get range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case _DatePreset.today:
        return (from: today, to: today);
      case _DatePreset.thisWeek:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return (from: monday, to: today);
      case _DatePreset.thisMonth:
        return (from: DateTime(now.year, now.month, 1), to: today);
      case _DatePreset.thisQuarter:
        final qStart = ((now.month - 1) ~/ 3) * 3 + 1;
        return (from: DateTime(now.year, qStart, 1), to: today);
      case _DatePreset.thisYear:
        return (from: DateTime(now.year, 1, 1), to: today);
      case _DatePreset.lastYear:
        return (
          from: DateTime(now.year - 1, 1, 1),
          to: DateTime(now.year - 1, 12, 31),
        );
      case _DatePreset.custom:
        return (from: DateTime(now.year, 1, 1), to: today);
    }
  }
}

// ============================================
// Screen
// ============================================
class CustomerStatementScreen extends ConsumerStatefulWidget {
  const CustomerStatementScreen({super.key});

  @override
  ConsumerState<CustomerStatementScreen> createState() =>
      _CustomerStatementScreenState();
}

class _CustomerStatementScreenState
    extends ConsumerState<CustomerStatementScreen> {
  bool _isExporting = false;

  // ============================================
  // Actions
  // ============================================
  Future<void> _pickCustomer() async {
    final customers = await ref.read(customersListProvider.future);
    if (!mounted) return;

    final selected = await showDialog<CustomerModel>(
      context: context,
      builder: (context) => _CustomerPickerDialog(customers: customers),
    );

    if (selected != null && mounted) {
      final f = ref.read(customerStatementFilterProvider);
      ref.read(customerStatementFilterProvider.notifier).state =
          f.copyWith(customerId: selected.id);
    }
  }

  Future<void> _pickPreset() async {
    final preset = await showDialog<_DatePreset>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('date_preset'.tr()),
        children: _DatePreset.values
            .map((p) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(p.labelKey.tr()),
                  ),
                ))
            .toList(),
      ),
    );
    if (preset == null || !mounted) return;

    if (preset == _DatePreset.custom) {
      await _pickCustomRange();
      return;
    }
    final r = preset.range;
    final f = ref.read(customerStatementFilterProvider);
    ref.read(customerStatementFilterProvider.notifier).state =
        f.copyWith(fromDate: r.from, toDate: r.to);
  }

  Future<void> _pickCustomRange() async {
    final f = ref.read(customerStatementFilterProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: f.fromDate, end: f.toDate),
    );
    if (picked == null || !mounted) return;
    ref.read(customerStatementFilterProvider.notifier).state =
        f.copyWith(fromDate: picked.start, toDate: picked.end);
  }

  Future<void> _exportPdf(CustomerStatementModel data,
      {required bool share}) async {
    setState(() => _isExporting = true);
    try {
      final lang = context.locale.languageCode;
      if (share) {
        await CustomerStatementPdf.share(data, langCode: lang);
      } else {
        await CustomerStatementPdf.print(data, langCode: lang);
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
    final filter = ref.watch(customerStatementFilterProvider);
    final dataAsync = ref.watch(customerStatementProvider);
    final customersAsync = ref.watch(customersListProvider);

    return AppShell(
      currentRoute: '/reports',
      child: Scaffold(
        appBar: AppBar(
          title: Text('customer_statement'.tr()),
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
              icon: const Icon(Icons.date_range),
              tooltip: 'report_period'.tr(),
              onPressed: _pickPreset,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'refresh'.tr(),
              onPressed: () => ref.invalidate(customerStatementProvider),
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
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Customer selector
                      _CustomerChip(
                        customer: _selectedCustomerFrom(customersAsync, filter),
                        onTap: _pickCustomer,
                      ),
                      // Date range
                      ActionChip(
                        avatar: const Icon(Icons.event, size: 16),
                        label: Text(
                          '${_fmt(filter.fromDate)} → ${_fmt(filter.toDate)}',
                        ),
                        onPressed: _pickCustomRange,
                      ),
                      // Totals for quick view
                      if (dataAsync.valueOrNull != null)
                        Text(
                          '${'closing_balance'.tr()}: '
                          '${dataAsync.valueOrNull!.closingBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: dataAsync.valueOrNull!.closingBalance >= 0
                                ? AppColors.error
                                : AppColors.success,
                          ),
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
                  if (data == null) {
                    return _EmptySelection(onPick: _pickCustomer);
                  }
                  return _StatementBody(
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

  CustomerModel? _selectedCustomerFrom(
    AsyncValue<List<CustomerModel>> async,
    CustomerStatementFilter filter,
  ) {
    if (filter.customerId == null) return null;
    return async.valueOrNull
        ?.where((c) => c.id == filter.customerId)
        .firstOrNull;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ============================================
// Customer chip
// ============================================
class _CustomerChip extends StatelessWidget {
  final CustomerModel? customer;
  final VoidCallback onTap;

  const _CustomerChip({this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.person_outline, size: 16),
      label: Text(
        customer == null
            ? 'select_customer'.tr()
            : (customer!.customerCode != null
                ? '${customer!.customerCode} - ${customer!.name}'
                : customer!.name),
        style: TextStyle(
          fontWeight: customer != null ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onPressed: onTap,
    );
  }
}

// ============================================
// Customer picker dialog
// ============================================
class _CustomerPickerDialog extends StatefulWidget {
  final List<CustomerModel> customers;
  const _CustomerPickerDialog({required this.customers});

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
          (c.customerCode?.toLowerCase().contains(q) ?? false) ||
          (c.phone?.contains(q) ?? false);
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
                          onTap: () => Navigator.pop(context, c),
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

// ============================================
// Empty selection
// ============================================
class _EmptySelection extends StatelessWidget {
  final VoidCallback onPick;
  const _EmptySelection({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search,
              size: 72,
              color: AppColors.textSecondaryLight.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'select_customer_to_show_statement'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.person_search),
              label: Text('select_customer'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// Body
// ============================================
class _StatementBody extends StatelessWidget {
  final CustomerStatementModel data;
  final bool isExporting;
  final VoidCallback onShare;
  final VoidCallback onPrint;

  const _StatementBody({
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
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Customer header ──────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            child: Text(
                              data.customer.name.isNotEmpty
                                  ? data.customer.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.customer.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (data.customer.customerCode != null)
                                  Text(
                                    data.customer.customerCode!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (data.customer.phone != null)
                            _InfoChip(
                              icon: Icons.phone,
                              text: data.customer.phone!,
                            ),
                          if (data.customer.email != null)
                            _InfoChip(
                              icon: Icons.email,
                              text: data.customer.email!,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Summary cards ────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final cross = constraints.maxWidth > 800 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: cross,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children: [
                      _SummaryCard(
                        label: 'opening_balance'.tr(),
                        value: data.openingBalance.toStringAsFixed(2),
                        color: AppColors.info,
                      ),
                      _SummaryCard(
                        label: 'total_debit'.tr(),
                        value: data.totalDebits.toStringAsFixed(2),
                        color: AppColors.warning,
                      ),
                      _SummaryCard(
                        label: 'total_credit'.tr(),
                        value: data.totalCredits.toStringAsFixed(2),
                        color: AppColors.success,
                      ),
                      _SummaryCard(
                        label: 'closing_balance'.tr(),
                        value: data.closingBalance.toStringAsFixed(2),
                        color: data.closingBalance >= 0
                            ? AppColors.error
                            : AppColors.success,
                        bold: true,
                      ),
                    ],
                  );
                },
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
              if (data.lines.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'no_transactions_in_period'.tr(),
                        style: const TextStyle(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 800),
                      child: DataTable(
                        headingRowColor: WidgetStatePropertyAll(
                          AppColors.primary.withValues(alpha: 0.08),
                        ),
                        columns: [
                          const DataColumn(label: Text('#')),
                          DataColumn(label: Text('date'.tr())),
                          DataColumn(label: Text('document_type'.tr())),
                          DataColumn(label: Text('description'.tr())),
                          DataColumn(
                            label: Text('debit'.tr()),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text('credit'.tr()),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text('running_balance'.tr()),
                            numeric: true,
                          ),
                        ],
                        rows: [
                          for (var i = 0; i < data.lines.length; i++)
                            _buildRow(i, data.lines[i]),
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

  DataRow _buildRow(int index, CustomerStatementLine l) {
    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(_fmt(l.date))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (l.type == StatementLineType.invoice
                      ? AppColors.warning
                      : AppColors.success)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              l.type == StatementLineType.invoice
                  ? 'invoice'.tr()
                  : 'payment'.tr(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: l.type == StatementLineType.invoice
                    ? AppColors.warning
                    : AppColors.success,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            l.description == 'paid_at_creation'
                ? 'paid_at_creation'.tr()
                : (l.description ?? l.documentNumber),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(Text(
          l.debit > 0.001 ? l.debit.toStringAsFixed(2) : '-',
          style: const TextStyle(fontWeight: FontWeight.bold),
        )),
        DataCell(Text(
          l.credit > 0.001 ? l.credit.toStringAsFixed(2) : '-',
          style: const TextStyle(fontWeight: FontWeight.bold),
        )),
        DataCell(Text(
          l.runningBalance.toStringAsFixed(2),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: l.runningBalance >= 0 ? AppColors.error : AppColors.success,
          ),
        )),
      ],
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondaryLight),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
