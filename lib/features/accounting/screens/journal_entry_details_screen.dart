import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/models/journal_entry_model.dart';
import '../providers/accounting_provider.dart';

class JournalEntryDetailsScreen extends ConsumerWidget {
  final String entryId;
  const JournalEntryDetailsScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(journalEntryByIdProvider(entryId));

    return Scaffold(
      appBar: AppBar(
        title: Text('journal_entry_details'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(journalEntryByIdProvider(entryId)),
          ),
        ],
      ),
      body: entryAsync.when(
        data: (entry) {
          if (entry == null) {
            return Center(child: Text('journal_entry_not_found'.tr()));
          }
          return _DetailsBody(entry: entry);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('error_label'.tr(args: [e.toString()]))),
      ),
    );
  }
}

class _DetailsBody extends ConsumerWidget {
  final JournalEntryModel entry;
  const _DetailsBody({required this.entry});

  Color _statusColor() {
    switch (entry.status) {
      case 'posted':
        return AppColors.success;
      case 'voided':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Future<void> _post(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_post'.tr()),
        content:
            Text('post_journal_entry_confirm'.tr(args: [entry.entryNumber])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel_btn'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('post'.tr()),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ref.read(accountingServiceProvider).postJournalEntry(entry.id);
      ref.invalidate(journalEntryByIdProvider(entry.id));
      ref.invalidate(journalEntriesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('journal_entry_posted'.tr()),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _void(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_void'.tr()),
        content:
            Text('void_journal_entry_confirm'.tr(args: [entry.entryNumber])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel_btn'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('void'.tr()),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ref.read(accountingServiceProvider).voidJournalEntry(entry.id);
      ref.invalidate(journalEntryByIdProvider(entry.id));
      ref.invalidate(journalEntriesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('journal_entry_voided'.tr())),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content:
            Text('delete_journal_entry_confirm'.tr(args: [entry.entryNumber])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel_btn'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('delete_btn'.tr()),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ref
          .read(accountingServiceProvider)
          .deleteDraftJournalEntry(entry.id);
      ref.invalidate(journalEntriesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('journal_entry_deleted'.tr())),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header card ───────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.entryNumber,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _statusColor().withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              entry.status.tr(),
                              style: TextStyle(
                                color: _statusColor(),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _InfoRow(
                        label: 'entry_date'.tr(),
                        value:
                            entry.entryDate.toIso8601String().split('T').first,
                      ),
                      _InfoRow(
                        label: 'description'.tr(),
                        value: entry.description,
                      ),
                      if (entry.notes != null && entry.notes!.isNotEmpty)
                        _InfoRow(label: 'notes'.tr(), value: entry.notes!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Lines table ───────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'entry_lines'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 24),
                      // header row
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'account'.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
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
                              flex: 1,
                              child: Text(
                                'credit'.tr(),
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
                      const Divider(),
                      ...(entry.lines ?? []).map((line) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        line.accountCode != null
                                            ? '${line.accountCode} - ${line.accountName ?? ''}'
                                            : '-',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      if (line.description != null &&
                                          line.description!.isNotEmpty)
                                        Text(
                                          line.description!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondaryLight,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    line.debit > 0
                                        ? line.debit.toStringAsFixed(2)
                                        : '-',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    line.credit > 0
                                        ? line.credit.toStringAsFixed(2)
                                        : '-',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const Divider(),
                      // totals
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'total'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              entry.totalDebit.toStringAsFixed(2),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              entry.totalCredit.toStringAsFixed(2),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Actions ───────────────────────────
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (entry.canPost)
                    ElevatedButton.icon(
                      onPressed: () => _post(context, ref),
                      icon: const Icon(Icons.check_circle),
                      label: Text('post'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                    ),
                  if (entry.canVoid && entry.status != 'voided')
                    OutlinedButton.icon(
                      onPressed: () => _void(context, ref),
                      icon: const Icon(Icons.cancel, color: AppColors.error),
                      label: Text('void'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                  if (entry.status == 'draft')
                    OutlinedButton.icon(
                      onPressed: () => _delete(context, ref),
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.error),
                      label: Text('delete_btn'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  const _InfoRow({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(value!, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
