import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/employee_salary_model.dart';
import '../../providers/employee_provider.dart';
import '../../providers/job_title_provider.dart';
import '../../providers/salary_provider.dart';
import '../../providers/service_providers.dart';

class EmployeeProfileScreen extends ConsumerWidget {
  final String employeeId;

  const EmployeeProfileScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeAsync = ref.watch(employeeByIdProvider(employeeId));
    final currentSalaryAsync = ref.watch(currentSalaryProvider(employeeId));
    final jobTitlesAsync = ref.watch(jobTitlesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('employee_profile'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'edit'.tr(),
            onPressed: () => context.push('/employees/$employeeId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'refresh'.tr(),
            onPressed: () {
              ref.invalidate(employeeByIdProvider(employeeId));
              ref.invalidate(currentSalaryProvider(employeeId));
            },
          ),
        ],
      ),
      body: employeeAsync.when(
        data: (employee) {
          if (employee == null) {
            return Center(child: Text('employee_not_found'.tr()));
          }

          final jobTitleName = employee.jobTitleId != null
              ? jobTitlesAsync.valueOrNull
                  ?.where((t) => t.id == employee.jobTitleId)
                  .firstOrNull
                  ?.name
              : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header card ─────────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.1),
                              child: Text(
                                employee.fullName.isNotEmpty
                                    ? employee.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    employee.fullName,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    employee.employeeCode,
                                    style: const TextStyle(
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  if (jobTitleName != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      jobTitleName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            _StatusBadge(status: employee.status),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Current salary ──────────────────────
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
                                  'current_salary'.tr(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _showSalaryHistory(
                                      context, ref, employeeId),
                                  icon: const Icon(Icons.history, size: 18),
                                  label: Text('salary_history'.tr()),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            currentSalaryAsync.when(
                              data: (salary) => salary == null
                                  ? Text(
                                      'no_salary'.tr(),
                                      style: const TextStyle(
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    )
                                  : _SalarySummary(salary: salary),
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => Text('error'.tr(args: ['$e'])),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Details ─────────────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'details'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(height: 24),
                            _InfoRow(
                                label: 'national_id'.tr(),
                                value: employee.nationalId),
                            _InfoRow(
                                label: 'phone'.tr(), value: employee.phone),
                            _InfoRow(
                                label: 'email'.tr(), value: employee.email),
                            _InfoRow(
                                label: 'address'.tr(), value: employee.address),
                            _InfoRow(
                              label: 'birth_date'.tr(),
                              value: employee.birthDate != null
                                  ? _formatDate(employee.birthDate!)
                                  : null,
                            ),
                            _InfoRow(
                              label: 'gender'.tr(),
                              value: employee.gender == 'male'
                                  ? 'male'.tr()
                                  : employee.gender == 'female'
                                      ? 'female'.tr()
                                      : null,
                            ),
                            _InfoRow(
                              label: 'marital_status'.tr(),
                              value: _maritalLabel(employee.maritalStatus),
                            ),
                            _InfoRow(
                              label: 'hire_date'.tr(),
                              value: employee.hireDate != null
                                  ? _formatDate(employee.hireDate!)
                                  : null,
                            ),
                            _InfoRow(
                              label: 'contract_type'.tr(),
                              value: _contractLabel(employee.contractType),
                            ),
                            _InfoRow(
                                label: 'notes'.tr(), value: employee.notes),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Documents (placeholder) ─────────────
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
                                  'documents'.tr(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('documents_coming_soon'.tr()),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.upload, size: 18),
                                  label: Text('upload_document'.tr()),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'no_documents'.tr(),
                              style: const TextStyle(
                                color: AppColors.textSecondaryLight,
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
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('error'.tr(args: ['$e']))),
      ),
    );
  }

  Future<void> _showSalaryHistory(
    BuildContext context,
    WidgetRef ref,
    String employeeId,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'salary_history'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final salariesAsync =
                          ref.watch(salaryHistoryProvider(employeeId));
                      return salariesAsync.when(
                        data: (salaries) {
                          if (salaries.isEmpty) {
                            return Center(
                                child: Text('no_salary_history'.tr()));
                          }
                          return ListView.separated(
                            itemCount: salaries.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final s = salaries[index];
                              return ListTile(
                                leading: Icon(
                                  s.isCurrent
                                      ? Icons.check_circle
                                      : Icons.history,
                                  color: s.isCurrent
                                      ? AppColors.success
                                      : AppColors.textSecondaryLight,
                                ),
                                title: Text(
                                  '${s.basicSalary.toStringAsFixed(2)} ${s.currency}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  s.effectiveTo != null
                                      ? '${'salary_from_to'.tr(args: [
                                              _formatDate(s.effectiveFrom),
                                              _formatDate(s.effectiveTo!),
                                            ])}'
                                          '${s.changeReason != null ? '\n${s.changeReason}' : ''}'
                                      : '${'salary_from_to_current'.tr(args: [
                                              _formatDate(s.effectiveFrom),
                                            ])}'
                                          '${s.changeReason != null ? '\n${s.changeReason}' : ''}',
                                ),
                                trailing: s.isCurrent
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.success
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'current'.tr(),
                                          style: const TextStyle(
                                            color: AppColors.success,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : null,
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) =>
                            Center(child: Text('error'.tr(args: ['$e']))),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddSalaryDialog(context, ref, employeeId);
                  },
                  icon: const Icon(Icons.add),
                  label: Text('add_new_salary'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSalaryDialog(
    BuildContext context,
    WidgetRef ref,
    String employeeId,
  ) async {
    final formKey = GlobalKey<FormState>();
    final basicCtrl = TextEditingController();
    final allowancesCtrl = TextEditingController(text: '0');
    final deductionsCtrl = TextEditingController(text: '0');
    final reasonCtrl = TextEditingController();
    final effectiveFrom = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('add_new_salary'.tr()),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: basicCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'basic_salary'.tr(),
                  ),
                  validator: (v) => (v == null || double.tryParse(v) == null)
                      ? 'invalid_number'.tr()
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: allowancesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'allowances'.tr()),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: deductionsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'deductions'.tr()),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(labelText: 'change_reason'.tr()),
                ),
              ],
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
        final salary = EmployeeSalaryModel(
          id: '',
          employeeId: employeeId,
          basicSalary: double.parse(basicCtrl.text),
          allowances: double.tryParse(allowancesCtrl.text) ?? 0,
          deductions: double.tryParse(deductionsCtrl.text) ?? 0,
          effectiveFrom: effectiveFrom,
          changeReason:
              reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
          createdAt: DateTime.now(),
        );
        await ref.read(employeeServiceProvider).createSalary(salary);
        ref.invalidate(currentSalaryProvider(employeeId));
        ref.invalidate(salaryHistoryProvider(employeeId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('salary_added'.tr())),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('error'.tr(args: ['$e']))),
          );
        }
      }
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? _maritalLabel(String? status) {
    switch (status) {
      case 'single':
        return 'single'.tr();
      case 'married':
        return 'married'.tr();
      case 'divorced':
        return 'divorced'.tr();
      case 'widowed':
        return 'widowed'.tr();
      default:
        return null;
    }
  }

  String? _contractLabel(String? type) {
    switch (type) {
      case 'full_time':
        return 'full_time'.tr();
      case 'part_time':
        return 'part_time'.tr();
      case 'contract':
        return 'contract'.tr();
      case 'intern':
        return 'intern'.tr();
      default:
        return null;
    }
  }
}

// ── Small widgets ────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = AppColors.success;
        label = 'active'.tr();
        break;
      case 'on_leave':
        color = AppColors.warning;
        label = 'on_leave'.tr();
        break;
      case 'terminated':
        color = AppColors.error;
        label = 'terminated'.tr();
        break;
      default:
        color = AppColors.textSecondaryLight;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SalarySummary extends StatelessWidget {
  final EmployeeSalaryModel salary;
  const _SalarySummary({required this.salary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${salary.netSalary.toStringAsFixed(2)} ${salary.currency}',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'salary_summary'.tr(args: [
            salary.basicSalary.toStringAsFixed(2),
            salary.allowances.toStringAsFixed(2),
            salary.deductions.toStringAsFixed(2),
          ]),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondaryLight,
          ),
        ),
      ],
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
            child: Text(
              value!,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
