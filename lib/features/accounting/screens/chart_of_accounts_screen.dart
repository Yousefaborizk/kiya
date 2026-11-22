import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/employee_form_fields.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/shared/app_bar_actions.dart';
import '../../../widgets/shared/app_shell.dart';
import '../data/models/account_model.dart';
import '../providers/accounting_provider.dart';

class ChartOfAccountsScreen extends ConsumerWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsListProvider);
    final langCode = context.locale.languageCode;

    return AppShell(
      currentRoute: '/accounting',
      child: Scaffold(
        appBar: AppBar(
          title: Text('chart_of_accounts'.tr()),
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
              icon: const Icon(Icons.receipt_long),
              tooltip: 'journal_entries'.tr(),
              onPressed: () => context.push('/accounting/journal'),
            ),
            IconButton(
              icon: const Icon(Icons.table_chart),
              tooltip: 'trial_balance'.tr(),
              onPressed: () =>
                  context.push('/accounting/reports/trial-balance'),
            ),
            IconButton(
              icon: const Icon(Icons.trending_up),
              tooltip: 'income_statement'.tr(),
              onPressed: () =>
                  context.push('/accounting/reports/income-statement'),
            ),
            IconButton(
              icon: const Icon(Icons.account_balance),
              tooltip: 'balance_sheet'.tr(),
              onPressed: () =>
                  context.push('/accounting/reports/balance-sheet'),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'refresh'.tr(),
              onPressed: () => ref.invalidate(accountsListProvider),
            ),
            const AppBarActions(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAccountForm(context, ref),
          icon: const Icon(Icons.add),
          label: Text('add_account'.tr()),
        ),
        body: accountsAsync.when(
          data: (accounts) {
            if (accounts.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.account_balance_wallet_outlined,
                title: 'no_accounts'.tr(),
                subtitle: 'no_accounts_subtitle'.tr(),
                actionLabel: 'add_account'.tr(),
                onAction: () => _showAccountForm(context, ref),
              );
            }
            final roots = accounts.where((a) => a.parentId == null).toList();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: roots
                  .map((r) => _AccountTreeNode(
                        account: r,
                        allAccounts: accounts,
                        langCode: langCode,
                        onEdit: (acc) =>
                            _showAccountForm(context, ref, existing: acc),
                        onDelete: (acc) => _confirmDelete(context, ref, acc),
                      ))
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('error_label'.tr(args: [e.toString()]))),
        ),
      ),
    );
  }

  Future<void> _showAccountForm(
    BuildContext context,
    WidgetRef ref, {
    AccountModel? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final nameEnCtrl = TextEditingController(text: existing?.nameEn ?? '');
    final nameZhCtrl = TextEditingController(text: existing?.nameZh ?? '');
    final openingCtrl =
        TextEditingController(text: existing?.openingBalance.toString() ?? '0');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    String accountType = existing?.accountType ?? 'asset';
    String? parentId = existing?.parentId;

    final allAccounts = await ref.read(accountsListProvider.future);
    final possibleParents =
        allAccounts.where((a) => a.id != existing?.id).toList();

    if (!context.mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null ? 'add_account'.tr() : 'edit_account'.tr(),
        ),
        content: SizedBox(
          width: 600,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: 'account_code'.tr(),
                          child: TextFormField(
                            controller: codeCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(hintText: '1100'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'required'.tr();
                              }
                              if (v.trim().length < 2) {
                                return 'كود الحساب قصير جداً';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: LabeledField(
                          label: 'account_type'.tr(),
                          child: DropdownButtonFormField<String>(
                            initialValue: accountType,
                            decoration: const InputDecoration(),
                            items: [
                              DropdownMenuItem(
                                value: 'asset',
                                child: Text('account_type_asset'.tr()),
                              ),
                              DropdownMenuItem(
                                value: 'liability',
                                child: Text('account_type_liability'.tr()),
                              ),
                              DropdownMenuItem(
                                value: 'equity',
                                child: Text('account_type_equity'.tr()),
                              ),
                              DropdownMenuItem(
                                value: 'revenue',
                                child: Text('account_type_revenue'.tr()),
                              ),
                              DropdownMenuItem(
                                value: 'expense',
                                child: Text('account_type_expense'.tr()),
                              ),
                            ],
                            onChanged: (v) => accountType = v ?? 'asset',
                          ),
                        ),
                      ),
                    ],
                  ),
                  LabeledField(
                    label: 'account_name_ar'.tr(),
                    child: TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'required'.tr()
                          : null,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: 'account_name_en'.tr(),
                          child: TextFormField(
                            controller: nameEnCtrl,
                            decoration: const InputDecoration(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledField(
                          label: 'account_name_zh'.tr(),
                          child: TextFormField(
                            controller: nameZhCtrl,
                            decoration: const InputDecoration(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  LabeledField(
                    label: 'parent_account'.tr(),
                    child: DropdownButtonFormField<String?>(
                      initialValue: parentId,
                      decoration: const InputDecoration(),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text('no_parent'.tr()),
                        ),
                        ...possibleParents.map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.code} - ${a.name}'),
                          ),
                        ),
                      ],
                      onChanged: (v) => parentId = v,
                    ),
                  ),
                  LabeledField(
                    label: 'opening_balance'.tr(),
                    child: TextFormField(
                      controller: openingCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: '0'),
                    ),
                  ),
                  LabeledField(
                    label: 'notes'.tr(),
                    child: TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel_btn'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: Text('save_btn'.tr()),
          ),
        ],
      ),
    );

    if (saved == true) {
      try {
        final service = ref.read(accountingServiceProvider);
        if (existing == null) {
          final newAccount = AccountModel(
            id: '',
            code: codeCtrl.text.trim(),
            name: nameCtrl.text.trim(),
            nameEn:
                nameEnCtrl.text.trim().isEmpty ? null : nameEnCtrl.text.trim(),
            nameZh:
                nameZhCtrl.text.trim().isEmpty ? null : nameZhCtrl.text.trim(),
            accountType: accountType,
            parentId: parentId,
            openingBalance: double.tryParse(openingCtrl.text) ?? 0,
            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await service.createAccount(newAccount);
        } else {
          await service.updateAccount(existing.id, {
            'code': codeCtrl.text.trim(),
            'name': nameCtrl.text.trim(),
            'name_en':
                nameEnCtrl.text.trim().isEmpty ? null : nameEnCtrl.text.trim(),
            'name_zh':
                nameZhCtrl.text.trim().isEmpty ? null : nameZhCtrl.text.trim(),
            'account_type': accountType,
            'parent_id': parentId,
            'opening_balance': double.tryParse(openingCtrl.text) ?? 0,
            'notes':
                notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
          });
        }
        ref.invalidate(accountsListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(existing == null
                  ? 'account_added'.tr()
                  : 'account_updated'.tr()),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('error_label'.tr(args: [e.toString()])),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AccountModel account,
  ) async {
    if (account.isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن حذف حساب نظامي (System Account)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text(
          'delete_account_confirm'
              .tr(args: ['${account.code} - ${account.name}']),
        ),
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

    if (confirmed != true) return;

    try {
      await ref.read(accountingServiceProvider).deleteAccount(account.id);
      ref.invalidate(accountsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('account_deleted'.tr())),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_label'.tr(args: [e.toString()]))),
        );
      }
    }
  }
}

// ============================================
// Recursive Tree Node
// ============================================
class _AccountTreeNode extends StatelessWidget {
  final AccountModel account;
  final List<AccountModel> allAccounts;
  final String langCode;
  final void Function(AccountModel) onEdit;
  final void Function(AccountModel) onDelete;

  const _AccountTreeNode({
    required this.account,
    required this.allAccounts,
    required this.langCode,
    required this.onEdit,
    required this.onDelete,
  });

  Color _typeColor(String type) {
    switch (type) {
      case 'asset':
        return AppColors.info;
      case 'liability':
        return AppColors.warning;
      case 'equity':
        return AppColors.primary;
      case 'revenue':
        return AppColors.success;
      case 'expense':
        return AppColors.error;
      default:
        return AppColors.textSecondaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = allAccounts.where((a) => a.parentId == account.id).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final hasChildren = children.isNotEmpty;
    final color = _typeColor(account.accountType);

    final titleWidget = Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            account.code,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            account.getLocalizedName(langCode),
            style: TextStyle(
              fontWeight: hasChildren ? FontWeight.bold : FontWeight.normal,
              color: account.isActive ? null : AppColors.textSecondaryLight,
            ),
          ),
        ),
        if (account.isSystem)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(
              Icons.lock_outline,
              size: 12,
              color: AppColors.textSecondaryLight,
            ),
          ),
      ],
    );

    final trailing = PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (v) {
        if (v == 'edit') onEdit(account);
        if (v == 'delete') onDelete(account);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            const Icon(Icons.edit_outlined, size: 18),
            const SizedBox(width: 8),
            Text('edit_btn'.tr()),
          ]),
        ),
        if (!account.isSystem)
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'delete_btn'.tr(),
                style: const TextStyle(color: AppColors.error),
              ),
            ]),
          ),
      ],
    );

    if (!hasChildren) {
      return Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.only(left: 16, right: 8, top: 2, bottom: 2),
          title: titleWidget,
          trailing: trailing,
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.only(left: 16, right: 8, top: 2, bottom: 2),
          childrenPadding: const EdgeInsets.only(left: 16, bottom: 6),
          title: titleWidget,
          trailing: trailing,
          children: children
              .map((c) => _AccountTreeNode(
                    account: c,
                    allAccounts: allAccounts,
                    langCode: langCode,
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
