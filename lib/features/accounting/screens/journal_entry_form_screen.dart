import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/employee_form_fields.dart';
import '../data/models/account_model.dart';
import '../data/models/journal_entry_model.dart';
import '../providers/accounting_provider.dart';

class _LineController {
  final String key;
  String? accountId;
  final debitCtrl = TextEditingController(text: '');
  final creditCtrl = TextEditingController(text: '');
  final descCtrl = TextEditingController(text: '');

  _LineController({required this.key});

  void dispose() {
    debitCtrl.dispose();
    creditCtrl.dispose();
    descCtrl.dispose();
  }

  double get debit => double.tryParse(debitCtrl.text) ?? 0;
  double get credit => double.tryParse(creditCtrl.text) ?? 0;
}

class JournalEntryFormScreen extends ConsumerStatefulWidget {
  const JournalEntryFormScreen({super.key});

  @override
  ConsumerState<JournalEntryFormScreen> createState() =>
      _JournalEntryFormScreenState();
}

class _JournalEntryFormScreenState
    extends ConsumerState<JournalEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _entryDate = DateTime.now();
  final List<_LineController> _lines = [];
  bool _isSaving = false;
  int _keyCounter = 0;

  @override
  void initState() {
    super.initState();
    _addLine();
    _addLine();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _notesCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    setState(() {
      _lines.add(_LineController(key: 'line_${_keyCounter++}'));
    });
  }

  void _removeLine(int i) {
    if (_lines.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('min_two_lines'.tr())),
      );
      return;
    }
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
  }

  double get _totalDebit => _lines.fold(0, (s, l) => s + l.debit);
  double get _totalCredit => _lines.fold(0, (s, l) => s + l.credit);
  double get _diff => _totalDebit - _totalCredit;
  bool get _isBalanced =>
      _diff.abs() < 0.01 && _totalDebit > 0 && _totalCredit > 0;

  String _generateEntryNumber() {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return 'JE-$y$m$d-$h$min$s';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('description_required'.tr())),
      );
      return;
    }

    if (!_isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('entry_not_balanced'.tr(args: [
            _totalDebit.toStringAsFixed(2),
            _totalCredit.toStringAsFixed(2),
          ])),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // validation لكل بند
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (l.accountId == null || l.accountId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('select_account_line'.tr(args: ['${i + 1}'])),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if ((l.debit > 0 && l.credit > 0) || (l.debit == 0 && l.credit == 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('invalid_line_amount'.tr(args: ['${i + 1}'])),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final lines = <JournalEntryLineModel>[];
      for (var i = 0; i < _lines.length; i++) {
        final l = _lines[i];
        lines.add(JournalEntryLineModel(
          id: '',
          entryId: '',
          accountId: l.accountId!,
          description:
              l.descCtrl.text.trim().isEmpty ? null : l.descCtrl.text.trim(),
          debit: l.debit,
          credit: l.credit,
          lineOrder: i,
          createdAt: DateTime.now(),
        ));
      }

      final header = JournalEntryModel(
        id: '',
        entryNumber: _generateEntryNumber(),
        entryDate: _entryDate,
        description: _descCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        status: 'draft',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref
          .read(accountingServiceProvider)
          .createJournalEntry(header, lines);

      ref.invalidate(journalEntriesListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('journal_entry_added'.tr()),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('add_journal_entry'.tr()),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save, color: Colors.white),
            label: Text(
              'save'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header info ────────────────────
                  FormSection(
                    title: 'entry_info'.tr(),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: LabeledField(
                              label: 'entry_date'.tr(),
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _entryDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setState(() => _entryDate = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    suffixIcon:
                                        Icon(Icons.calendar_today, size: 18),
                                  ),
                                  child: Text(
                                    '${_entryDate.year}-${_entryDate.month.toString().padLeft(2, '0')}-${_entryDate.day.toString().padLeft(2, '0')}',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: LabeledField(
                              label: 'description'.tr(),
                              child: TextFormField(
                                controller: _descCtrl,
                                decoration: InputDecoration(
                                  hintText: 'entry_description_hint'.tr(),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'required'.tr()
                                        : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      LabeledField(
                        label: 'notes'.tr(),
                        child: TextFormField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'notes_hint'.tr(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // ── Lines ──────────────────────────
                  FormSection(
                    title: 'entry_lines'.tr(),
                    children: [
                      accountsAsync.when(
                        data: (accounts) => Column(
                          children: _lines.asMap().entries.map((e) {
                            final i = e.key;
                            final line = e.value;
                            return _LineRow(
                              key: ValueKey(line.key),
                              index: i,
                              line: line,
                              accounts: accounts,
                              onRemove: () => _removeLine(i),
                              onChanged: () => setState(() {}),
                            );
                          }).toList(),
                        ),
                        loading: () =>
                            const Center(child: LinearProgressIndicator()),
                        error: (e, _) => Text('error_label'.tr(args: ['$e'])),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _addLine,
                        icon: const Icon(Icons.add),
                        label: Text('add_line'.tr()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Totals + Balance indicator ─────
                  Card(
                    color: _isBalanced
                        ? AppColors.success.withValues(alpha: 0.05)
                        : AppColors.error.withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _TotalRow(
                            label: 'total_debit'.tr(),
                            value: _totalDebit.toStringAsFixed(2),
                          ),
                          _TotalRow(
                            label: 'total_credit'.tr(),
                            value: _totalCredit.toStringAsFixed(2),
                          ),
                          const Divider(),
                          _TotalRow(
                            label: 'difference'.tr(),
                            value: _diff.toStringAsFixed(2),
                            isBold: true,
                            valueColor: _isBalanced
                                ? AppColors.success
                                : AppColors.error,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isBalanced
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isBalanced
                                      ? Icons.check_circle
                                      : Icons.warning,
                                  color: _isBalanced
                                      ? AppColors.success
                                      : AppColors.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _isBalanced
                                        ? 'entry_balanced'.tr()
                                        : 'entry_not_balanced'.tr(args: [
                                            _totalDebit.toStringAsFixed(2),
                                            _totalCredit.toStringAsFixed(2),
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: (_isSaving || !_isBalanced) ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text('save_journal_entry'.tr()),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

// ============================================
// Line Row
// ============================================
class _LineRow extends StatelessWidget {
  final int index;
  final _LineController line;
  final List<AccountModel> accounts;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _LineRow({
    super.key,
    required this.index,
    required this.line,
    required this.accounts,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account dropdown
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String?>(
              initialValue: line.accountId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: '${'account'.tr()} ${index + 1}',
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text('select_account'.tr()),
                ),
                ...accounts.map(
                  (a) => DropdownMenuItem(
                    value: a.id,
                    child: Text(
                      '${a.code} - ${a.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) {
                line.accountId = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          // Debit
          Expanded(
            flex: 1,
            child: TextField(
              controller: line.debitCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'debit'.tr(),
                hintText: '0',
              ),
              onChanged: (_) {
                if ((double.tryParse(line.debitCtrl.text) ?? 0) > 0) {
                  line.creditCtrl.clear();
                }
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          // Credit
          Expanded(
            flex: 1,
            child: TextField(
              controller: line.creditCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'credit'.tr(),
                hintText: '0',
              ),
              onChanged: (_) {
                if ((double.tryParse(line.creditCtrl.text) ?? 0) > 0) {
                  line.debitCtrl.clear();
                }
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          // Description
          Expanded(
            flex: 2,
            child: TextField(
              controller: line.descCtrl,
              decoration: InputDecoration(
                labelText: 'notes'.tr(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: onRemove,
            tooltip: 'delete_btn'.tr(),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _TotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? (isBold ? AppColors.primary : null),
            ),
          ),
        ],
      ),
    );
  }
}
