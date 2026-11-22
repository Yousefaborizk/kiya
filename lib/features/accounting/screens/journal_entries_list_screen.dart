import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/shared/app_bar_actions.dart';
import '../../../widgets/shared/app_shell.dart';
import '../data/models/journal_entry_model.dart';
import '../providers/accounting_provider.dart';

class JournalEntriesListScreen extends ConsumerWidget {
  const JournalEntriesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(journalEntriesListProvider);
    final filter = ref.watch(journalFilterProvider);

    return AppShell(
      currentRoute: '/accounting/journal',
      child: Scaffold(
        appBar: AppBar(
          title: Text('journal_entries'.tr()),
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
              onPressed: () => ref.invalidate(journalEntriesListProvider),
            ),
            const AppBarActions(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/accounting/journal/new'),
          icon: const Icon(Icons.add),
          label: Text('add_journal_entry'.tr()),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Filter by status ───────────────────
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'status'.tr(),
                    value: filter.status,
                    options: [
                      MapEntry('all'.tr(), null),
                      MapEntry('draft'.tr(), 'draft'),
                      MapEntry('posted'.tr(), 'posted'),
                      MapEntry('voided'.tr(), 'voided'),
                    ],
                    onChanged: (v) {
                      ref.read(journalFilterProvider.notifier).state = v == null
                          ? filter.copyWith(clearStatus: true)
                          : filter.copyWith(status: v);
                    },
                  ),
                  if (filter.status != null)
                    TextButton.icon(
                      onPressed: () {
                        ref.read(journalFilterProvider.notifier).state =
                            const JournalFilter();
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: Text('clear_filters'.tr()),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: entriesAsync.when(
                  data: (entries) {
                    if (entries.isEmpty) {
                      return EmptyStateWidget(
                        icon: Icons.receipt_long_outlined,
                        title: 'no_journal_entries'.tr(),
                        subtitle: 'no_journal_entries_subtitle'.tr(),
                        actionLabel: 'add_journal_entry'.tr(),
                        onAction: () => context.push('/accounting/journal/new'),
                      );
                    }
                    return ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, i) =>
                          _JournalEntryCard(entry: entries[i]),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                      child: Text('error_label'.tr(args: [e.toString()]))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  final JournalEntryModel entry;
  const _JournalEntryCard({required this.entry});

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/accounting/journal/${entry.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.receipt_long, color: _statusColor()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.entryNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor().withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            entry.status.tr(),
                            style: TextStyle(
                              color: _statusColor(),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 11, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 4),
                        Text(
                          entry.entryDate.toIso8601String().split('T').first,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.attach_money,
                            size: 11, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 2),
                        Text(
                          entry.lines != null
                              ? entry.totalDebit.toStringAsFixed(2)
                              : '-',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textSecondaryLight),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? value;
  final List<MapEntry<String, String?>> options;
  final ValueChanged<String?> onChanged;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentLabel = options
        .firstWhere((e) => e.value == value, orElse: () => options.first)
        .key;

    return PopupMenuButton<String?>(
      tooltip: label,
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value != null
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value != null ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: $currentLabel', style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
      itemBuilder: (context) => options
          .map((e) => PopupMenuItem<String?>(
                value: e.value,
                child: Row(
                  children: [
                    if (e.value == value)
                      const Icon(Icons.check,
                          size: 18, color: AppColors.primary)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(e.key),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
