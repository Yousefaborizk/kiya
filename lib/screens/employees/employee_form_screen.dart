import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/employee_model.dart';
import '../../providers/employee_provider.dart';
import '../../providers/job_title_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/service_providers.dart';
import '../../utils/validators.dart';
import '../../widgets/employee_form_fields.dart';

class EmployeeFormScreen extends ConsumerStatefulWidget {
  final String? employeeId;

  const EmployeeFormScreen({super.key, this.employeeId});

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _gender;
  String? _maritalStatus;
  String? _contractType;
  String? _departmentId;
  String? _jobTitleId;
  DateTime? _birthDate;
  DateTime? _hireDate;

  // قائمة الأقسام اللي هتتحمل من الداتابيز
  List<Map<String, dynamic>> _departments = [];
  bool _departmentsLoaded = false;

  bool _isLoading = false;
  bool _isSaving = false;

  bool get _isEdit => widget.employeeId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadEmployee();
    _loadDepartments();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nationalIdCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final depts = await ref.read(employeeServiceProvider).getDepartments();
      if (mounted) {
        setState(() {
          _departments = depts;
          _departmentsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('LOAD DEPARTMENTS ERROR: $e');
      if (mounted) setState(() => _departmentsLoaded = true);
    }
  }

  Future<void> _loadEmployee() async {
    setState(() => _isLoading = true);
    try {
      final emp = await ref
          .read(employeeServiceProvider)
          .getEmployeeById(widget.employeeId!);
      if (emp != null && mounted) {
        setState(() {
          _nameCtrl.text = emp.fullName;
          _nationalIdCtrl.text = emp.nationalId ?? '';
          _phoneCtrl.text = emp.phone ?? '';
          _emailCtrl.text = emp.email ?? '';
          _addressCtrl.text = emp.address ?? '';
          _notesCtrl.text = emp.notes ?? '';
          _gender = emp.gender;
          _maritalStatus = emp.maritalStatus;
          _contractType = emp.contractType;
          _departmentId = emp.departmentId;
          _jobTitleId = emp.jobTitleId;
          _birthDate = emp.birthDate;
          _hireDate = emp.hireDate;
        });
      }
    } catch (e) {
      debugPrint('LOAD EMPLOYEE ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_label'.tr(args: [e.toString()]))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate(
    DateTime? initial,
    Function(DateTime) onPicked,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(now.year - 25),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final service = ref.read(employeeServiceProvider);

      final data = {
        'full_name': _nameCtrl.text.trim(),
        'national_id': _nationalIdCtrl.text.trim().isEmpty
            ? null
            : _nationalIdCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'address':
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'gender': _gender,
        'marital_status': _maritalStatus,
        'department_id': _departmentId,
        'job_title_id': _jobTitleId,
        'contract_type': _contractType,
        'birth_date': _birthDate?.toIso8601String().split('T').first,
        'hire_date': _hireDate?.toIso8601String().split('T').first,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };

      if (_isEdit) {
        await service.updateEmployee(widget.employeeId!, data);
      } else {
        final employee = EmployeeModel(
          id: '',
          employeeCode: '',
          fullName: _nameCtrl.text.trim(),
          nationalId: _nationalIdCtrl.text.trim().isEmpty
              ? null
              : _nationalIdCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          gender: _gender,
          maritalStatus: _maritalStatus,
          departmentId: _departmentId,
          jobTitleId: _jobTitleId,
          contractType: _contractType,
          birthDate: _birthDate,
          hireDate: _hireDate,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await service.createEmployee(employee);
      }

      ref.invalidate(employeesListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit ? 'employee_updated'.tr() : 'employee_added'.tr(),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e, stackTrace) {
      debugPrint('SAVE EMPLOYEE ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_label'.tr(args: [e.toString()])),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'edit_employee'.tr() : 'add_employee'.tr(),
        ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FormSection(
                          title: 'basic_info'.tr(),
                          children: [
                            LabeledField(
                              label: 'full_name'.tr(),
                              child: TextFormField(
                                controller: _nameCtrl,
                                decoration: InputDecoration(
                                  hintText: 'enter_full_name'.tr(),
                                ),
                                validator: (v) => AppValidators.required(
                                  v,
                                  message: 'required'.tr(),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: LabeledField(
                                    label: 'national_id'.tr(),
                                    child: TextFormField(
                                      controller: _nationalIdCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: 'national_id_hint'.tr(),
                                      ),
                                      validator: AppValidators.nationalId,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: LabeledField(
                                    label: 'phone'.tr(),
                                    child: TextFormField(
                                      controller: _phoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        hintText: 'phone_hint'.tr(),
                                      ),
                                      validator: AppValidators.phone,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            LabeledField(
                              label: 'email'.tr(),
                              child: TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  hintText: 'email_hint'.tr(),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? null
                                    : AppValidators.email(v),
                              ),
                            ),
                            LabeledField(
                              label: 'address'.tr(),
                              child: TextFormField(
                                controller: _addressCtrl,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: 'address_hint'.tr(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        FormSection(
                          title: 'personal_info'.tr(),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: LabeledField(
                                    label: 'birth_date'.tr(),
                                    child: _DateField(
                                      value: _birthDate,
                                      onTap: () => _pickDate(
                                        _birthDate,
                                        (d) => setState(() => _birthDate = d),
                                      ),
                                      onClear: () =>
                                          setState(() => _birthDate = null),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: LabeledField(
                                    label: 'gender'.tr(),
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _gender,
                                      decoration: const InputDecoration(),
                                      items: [
                                        DropdownMenuItem(
                                          value: 'male',
                                          child: Text('male'.tr()),
                                        ),
                                        DropdownMenuItem(
                                          value: 'female',
                                          child: Text('female'.tr()),
                                        ),
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _gender = v),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            LabeledField(
                              label: 'marital_status'.tr(),
                              child: DropdownButtonFormField<String>(
                                initialValue: _maritalStatus,
                                decoration: const InputDecoration(),
                                items: [
                                  DropdownMenuItem(
                                    value: 'single',
                                    child: Text('single'.tr()),
                                  ),
                                  DropdownMenuItem(
                                    value: 'married',
                                    child: Text('married'.tr()),
                                  ),
                                  DropdownMenuItem(
                                    value: 'divorced',
                                    child: Text('divorced'.tr()),
                                  ),
                                  DropdownMenuItem(
                                    value: 'widowed',
                                    child: Text('widowed'.tr()),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _maritalStatus = v),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        FormSection(
                          title: 'work_info'.tr(),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: LabeledField(
                                    label: 'hire_date'.tr(),
                                    child: _DateField(
                                      value: _hireDate,
                                      onTap: () => _pickDate(
                                        _hireDate ?? DateTime.now(),
                                        (d) => setState(() => _hireDate = d),
                                      ),
                                      onClear: () =>
                                          setState(() => _hireDate = null),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: LabeledField(
                                    label: 'contract_type'.tr(),
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _contractType,
                                      decoration: const InputDecoration(),
                                      items: [
                                        DropdownMenuItem(
                                          value: 'full_time',
                                          child: Text('full_time'.tr()),
                                        ),
                                        DropdownMenuItem(
                                          value: 'part_time',
                                          child: Text('part_time'.tr()),
                                        ),
                                        DropdownMenuItem(
                                          value: 'contract',
                                          child: Text('contract'.tr()),
                                        ),
                                        DropdownMenuItem(
                                          value: 'intern',
                                          child: Text('intern'.tr()),
                                        ),
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _contractType = v),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: LabeledField(
                                    label: 'department'.tr(),
                                    child: _departmentsLoaded
                                        ? DropdownButtonFormField<String>(
                                            initialValue: _departmentId,
                                            decoration: const InputDecoration(),
                                            items: [
                                              DropdownMenuItem(
                                                value: null,
                                                child:
                                                    Text('no_department'.tr()),
                                              ),
                                              ..._departments.map(
                                                (d) => DropdownMenuItem(
                                                  value: d['id'] as String,
                                                  child:
                                                      Text(d['name'] as String),
                                                ),
                                              ),
                                            ],
                                            onChanged: (v) => setState(() {
                                              _departmentId = v;
                                              _jobTitleId = null;
                                            }),
                                          )
                                        : const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: LinearProgressIndicator(),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Consumer(
                                    builder: (context, ref, _) {
                                      final titlesAsync = ref.watch(
                                        jobTitlesByDepartmentProvider(
                                          _departmentId,
                                        ),
                                      );
                                      return LabeledField(
                                        label: 'job_title'.tr(),
                                        child: titlesAsync.when(
                                          data: (titles) =>
                                              DropdownButtonFormField<String>(
                                            initialValue: _jobTitleId,
                                            decoration: const InputDecoration(),
                                            items: [
                                              DropdownMenuItem(
                                                value: null,
                                                child:
                                                    Text('no_job_title'.tr()),
                                              ),
                                              ...titles.map(
                                                (t) => DropdownMenuItem(
                                                  value: t.id,
                                                  child: Text(t.name),
                                                ),
                                              ),
                                            ],
                                            onChanged: (v) => setState(
                                              () => _jobTitleId = v,
                                            ),
                                          ),
                                          loading: () => const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: LinearProgressIndicator(),
                                          ),
                                          error: (_, __) => Text(
                                            'error_loading_job_titles'.tr(),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        FormSection(
                          title: 'notes'.tr(),
                          children: [
                            LabeledField(
                              label: 'additional_notes'.tr(),
                              child: TextFormField(
                                controller: _notesCtrl,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: 'notes_hint'.tr(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: const Icon(Icons.save),
                          label: Text(
                              _isEdit ? 'update'.tr() : 'add_employee'.tr()),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateField({
    this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: 'select_date'.tr(),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value != null
              ? '${value!.year}-'
                  '${value!.month.toString().padLeft(2, '0')}-'
                  '${value!.day.toString().padLeft(2, '0')}'
              : '',
        ),
      ),
    );
  }
}
