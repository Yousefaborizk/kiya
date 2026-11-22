import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/shared/app_bar_actions.dart';
import '../../../../widgets/shared/app_shell.dart';
import '../../data/models/financial_statement_model.dart';
import '../../providers/accounting_provider.dart';

class IncomeStatementScreen extends ConsumerWidget {
  const IncomeStatementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(incomeStatementProvider);
    final filter = ref.watch(reportFilterProvider);

    return AppShell(
      currentRoute: '/accounting/reports/income-statement',
      child: Scaffold(
        appBar: AppBar(
          title: Text('income_statement'.tr()),
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
              tooltip: 'filter_by_date'.tr(),
              onPressed: () => _pickDateRange(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(incomeStatementProvider),
            ),
            const AppBarActions(),
          ],
        ),
        body: Column(
          children: [
            if (filter.fromDate != null || filter.toDate != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: AppColors.primary.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    const Icon(Icons.date_range,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${'from'.tr()}: ${_fmt(filter.fromDate)}  |  ${'to'.tr()}: ${_fmt(filter.toDate)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        ref.read(reportFilterProvider.notifier).state =
                            const ReportFilter();
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: Text('clear_filters'.tr()),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: dataAsync.when(
                data: (data) => _Body(data: data),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('error_label'.tr(args: [e.toString()])),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime? d) => d == null
      ? '-'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDateRange(BuildContext context, WidgetRef ref) async {
    final filter = ref.read(reportFilterProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: filter.fromDate != null && filter.toDate != null
          ? DateTimeRange(start: filter.fromDate!, end: filter.toDate!)
          : null,
    );
    if (picked != null) {
      ref.read(reportFilterProvider.notifier).state = ReportFilter(
        fromDate: picked.start,
        toDate: picked.end,
      );
    }
  }
}

class _Body extends StatelessWidget {
  final IncomeStatementModel data;
  const _Body({required this.data});

  @override
  Widget build(BuildContext context) {
    final revenueRows = data.revenueRows.where((r) => r.hasActivity).toList();
    final expenseRows = data.expenseRows.where((r) => r.hasActivity).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ─────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'income_statement'.tr(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${'net_profit'.tr()} = ${'revenue'.tr()} - ${'expenses'.tr()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Revenue section ────────────────────
              _SectionCard(
                title: 'revenue'.tr(),
                color: AppColors.success,
                icon: Icons.trending_up,
                rows: revenueRows,
                total: data.totalRevenue,
              ),
              const SizedBox(height: 12),

              // ── Expenses section ───────────────────
              _SectionCard(
                title: 'expenses'.tr(),
                color: AppColors.error,
                icon: Icons.trending_down,
                rows: expenseRows,
                total: data.totalExpenses,
              ),
              const SizedBox(height: 16),

              // ── Net Profit ─────────────────────────
              Card(
                color: data.netProfit >= 0
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.error.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (data.netProfit >= 0
                                  ? AppColors.success
                                  : AppColors.error)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          data.netProfit >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: data.netProfit >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.netProfit >= 0
                                  ? 'net_profit'.tr()
                                  : 'net_loss'.tr(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: data.netProfit >= 0
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                            Text(
                              '${'total_revenue'.tr()} - ${'total_expenses'.tr()}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        data.netProfit.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: data.netProfit >= 0
                              ? AppColors.success
                              : AppColors.error,
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
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<StatementRow> rows;
  final double total;

  const _SectionCard({
    required this.title,
    required this.color,
    required this.icon,
    required this.rows,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'no_data'.tr(),
                  style: const TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 12,
                  ),
                ),
              )
            else
              ...rows.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 55,
                          child: Text(
                            r.accountCode,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            r.accountName,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          r.amount.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${'total'.tr()} $title',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  total.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
