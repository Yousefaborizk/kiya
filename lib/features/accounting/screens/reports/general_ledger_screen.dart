import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/account_model.dart';
import '../../data/models/trial_balance_model.dart';
import '../../providers/accounting_provider.dart';

class GeneralLedgerScreen extends ConsumerWidget {
  final AccountModel account;
  const GeneralLedgerScreen({super.key, required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(ledgerRowsProvider(account.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('${'general_ledger'.tr()} - ${account.code}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(ledgerRowsProvider(account.id)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Account header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${account.code} - ${account.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  account.accountType.tr(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ledgerAsync.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return Center(child: Text('no_transactions'.tr()));
                }
                return _LedgerBody(rows: rows);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('error_label'.tr(args: [e.toString()]))),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerBody extends StatelessWidget {
  final List<LedgerRow> rows;
  const _LedgerBody({required this.rows});

  @override
  Widget build(BuildContext context) {
    final totalDebit = rows.fold<double>(0, (s, r) => s + r.debit);
    final totalCredit = rows.fold<double>(0, (s, r) => s + r.credit);
    final finalBalance = rows.isNotEmpty ? rows.last.runningBalance : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Header row
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text('date'.tr(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('entry_number'.tr(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('description'.tr(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('debit'.tr(),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('credit'.tr(),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('balance'.tr(),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...rows.map((r) => Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 90,
                              child: Text(
                                r.entryDate.toIso8601String().split('T').first,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                r.entryNumber,
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.description ?? '-',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (r.lineDescription != null &&
                                      r.lineDescription!.isNotEmpty)
                                    Text(
                                      r.lineDescription!,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                r.debit > 0 ? r.debit.toStringAsFixed(2) : '-',
                                textAlign: TextAlign.end,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                r.credit > 0
                                    ? r.credit.toStringAsFixed(2)
                                    : '-',
                                textAlign: TextAlign.end,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                r.runningBalance.toStringAsFixed(2),
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: r.runningBalance >= 0
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const Divider(),
                  // Totals row
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 90),
                        Expanded(
                          flex: 5,
                          child: Text('total'.tr(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            totalDebit.toStringAsFixed(2),
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            totalCredit.toStringAsFixed(2),
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            finalBalance.toStringAsFixed(2),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: finalBalance >= 0
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
        ),
      ),
    );
  }
}
