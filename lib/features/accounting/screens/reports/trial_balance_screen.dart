import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/shared/app_bar_actions.dart';
import '../../../../widgets/shared/app_shell.dart';
import '../../data/models/account_model.dart';
import '../../data/models/trial_balance_model.dart';
import '../../providers/accounting_provider.dart';
import 'general_ledger_screen.dart';

class TrialBalanceScreen extends ConsumerWidget {
  const TrialBalanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tbAsync = ref.watch(trialBalanceProvider);
    final filter = ref.watch(reportFilterProvider);

    return AppShell(
      currentRoute: '/accounting/reports/trial-balance',
      child: Scaffold(
        appBar: AppBar(
          title: Text('trial_balance'.tr()),
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
              tooltip: 'refresh'.tr(),
              onPressed: () => ref.invalidate(trialBalanceProvider),
            ),
            const AppBarActions(),
          ],
        ),
        body: Column(
          children: [
            // ── Filter bar ──────────────────────────
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
                        '${'from'.tr()}: ${filter.fromDate != null ? _fmt(filter.fromDate!) : "-"}  |  ${'to'.tr()}: ${filter.toDate != null ? _fmt(filter.toDate!) : "-"}',
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
              child: tbAsync.when(
                data: (rows) => _TrialBalanceBody(rows: rows),
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

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

class _TrialBalanceBody extends StatelessWidget {
  final List<TrialBalanceRow> rows;
  const _TrialBalanceBody({required this.rows});

  double get _totalDebit => rows.fold(0, (s, r) => s + r.totalDebit);
  double get _totalCredit => rows.fold(0, (s, r) => s + r.totalCredit);
  double get _diff => _totalDebit - _totalCredit;
  bool get _isBalanced => _diff.abs() < 0.01;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(child: Text('no_accounts'.tr()));
    }

    final activeRows = rows.where((r) => r.hasActivity).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Balance indicator ─────────────────
              Card(
                color: _isBalanced
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.error.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _isBalanced ? Icons.check_circle : Icons.warning,
                        color:
                            _isBalanced ? AppColors.success : AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isBalanced
                              ? 'trial_balance_ok'.tr()
                              : 'trial_balance_not_ok'.tr(args: [
                                  _diff.toStringAsFixed(2),
                                ]),
                          style: TextStyle(
                            color: _isBalanced
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

              // ── Table ────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Header row
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              child: Text(
                                'code'.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'account'.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'debit'.tr(),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'credit'.tr(),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'balance'.tr(),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...activeRows.map(
                        (r) => InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GeneralLedgerScreen(
                                  account: AccountModel(
                                    id: r.accountId,
                                    code: r.accountCode,
                                    name: r.accountName,
                                    accountType: r.accountType,
                                    createdAt: DateTime.now(),
                                    updatedAt: DateTime.now(),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 60,
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
                                  flex: 3,
                                  child: Text(
                                    r.accountName,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    r.totalDebit > 0
                                        ? r.totalDebit.toStringAsFixed(2)
                                        : '-',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    r.totalCredit > 0
                                        ? r.totalCredit.toStringAsFixed(2)
                                        : '-',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    r.balance.toStringAsFixed(2),
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: r.balance >= 0
                                          ? AppColors.success
                                          : AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Divider(),
                      // Total row
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 8),
                        child: Row(
                          children: [
                            const SizedBox(width: 60),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'total'.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _totalDebit.toStringAsFixed(2),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _totalCredit.toStringAsFixed(2),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _diff.toStringAsFixed(2),
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _isBalanced
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            ),
                          ],
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
