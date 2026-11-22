import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/shared/app_bar_actions.dart';
import '../../../../widgets/shared/app_shell.dart';
import '../../data/models/financial_statement_model.dart';
import '../../providers/accounting_provider.dart';

class BalanceSheetScreen extends ConsumerWidget {
  const BalanceSheetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(balanceSheetProvider);
    final filter = ref.watch(reportFilterProvider);

    return AppShell(
      currentRoute: '/accounting/reports/balance-sheet',
      child: Scaffold(
        appBar: AppBar(
          title: Text('balance_sheet'.tr()),
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
              tooltip: 'as_of_date'.tr(),
              onPressed: () => _pickAsOfDate(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(balanceSheetProvider),
            ),
            const AppBarActions(),
          ],
        ),
        body: Column(
          children: [
            if (filter.toDate != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: AppColors.primary.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${'as_of_date'.tr()}: ${_fmt(filter.toDate)}',
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

  Future<void> _pickAsOfDate(BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: ref.read(reportFilterProvider).toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      ref.read(reportFilterProvider.notifier).state =
          ReportFilter(toDate: picked);
    }
  }
}

class _Body extends StatelessWidget {
  final BalanceSheetModel data;
  const _Body({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Balance indicator ──────────────────
              Card(
                color: data.isBalanced
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.error.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        data.isBalanced ? Icons.check_circle : Icons.warning,
                        color: data.isBalanced
                            ? AppColors.success
                            : AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data.isBalanced
                              ? 'balance_sheet_ok'.tr()
                              : 'balance_sheet_not_ok'.tr(
                                  args: [data.difference.toStringAsFixed(2)],
                                ),
                          style: TextStyle(
                            color: data.isBalanced
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Assets ─────────────────────────────
              _SectionCard(
                title: 'assets'.tr(),
                color: AppColors.info,
                icon: Icons.business_center_outlined,
                rows: data.assetRows.where((r) => r.hasActivity).toList(),
                total: data.totalAssets,
              ),
              const SizedBox(height: 16),

              // ── Liabilities & Equity ───────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_outlined,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'liabilities_and_equity'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      // Liabilities subsection
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.trending_up,
                                  size: 16,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'liabilities'.tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (data.liabilityRows
                                .where((r) => r.hasActivity)
                                .isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'no_data'.tr(),
                                  style: const TextStyle(
                                    color: AppColors.textSecondaryLight,
                                    fontSize: 11,
                                  ),
                                ),
                              )
                            else
                              ...data.liabilityRows
                                  .where((r) => r.hasActivity)
                                  .map((r) => _Row(r: r)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${'total'.tr()} ${'liabilities'.tr()}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  data.totalLiabilities.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      // Equity subsection
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'equity'.tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...data.equityRows
                                .where((r) => r.hasActivity)
                                .map((r) => _Row(r: r)),
                            // Net profit line
                            if (data.netProfit.abs() > 0.001)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 55),
                                    Expanded(
                                      child: Text(
                                        'net_profit'.tr(),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      data.netProfit.toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${'total'.tr()} ${'equity'.tr()}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  data.totalEquity.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'total_liabilities_and_equity'.tr(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                          Text(
                            data.totalLiabilitiesAndEquity.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
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
              ...rows.map((r) => _Row(r: r)),
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

class _Row extends StatelessWidget {
  final StatementRow r;
  const _Row({required this.r});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}
