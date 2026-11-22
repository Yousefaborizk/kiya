import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/employee_provider.dart';
import '../../providers/job_title_provider.dart';
import '../../providers/service_providers.dart';
import '../../widgets/employee_card.dart';
import '../../widgets/employee_filter_bar.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/shared/app_bar_actions.dart';
import '../../widgets/shared/app_shell.dart';

class EmployeesListScreen extends ConsumerStatefulWidget {
  const EmployeesListScreen({super.key});

  @override
  ConsumerState<EmployeesListScreen> createState() =>
      _EmployeesListScreenState();
}

class _EmployeesListScreenState extends ConsumerState<EmployeesListScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('are_you_sure_delete_employee'.tr(args: [name])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(employeeServiceProvider).deleteEmployee(id);
      ref.invalidate(employeesListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('employee_deleted'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_label'.tr(args: [e.toString()]))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // بنستمع للغة عشان نضمن إن الشاشة بتعيد البناء لو الـ MaterialApp مغيّرش الـ Key لأي سبب
    context.locale;

    final employeesAsync = ref.watch(employeesListProvider);
    final jobTitlesAsync = ref.watch(jobTitlesListProvider);

    return AppShell(
      currentRoute: '/employees',
      child: Scaffold(
        appBar: AppBar(
          title: _showSearch
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'search_employee_hint'.tr(),
                    hintStyle: const TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    ref.read(employeeFilterProvider.notifier).state = ref
                        .read(employeeFilterProvider)
                        .copyWith(search: value);
                  },
                )
              : Text('employees'.tr()),
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
              icon: Icon(_showSearch ? Icons.close : Icons.search),
              tooltip: 'search'.tr(),
              onPressed: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchController.clear();
                    ref.read(employeeFilterProvider.notifier).state =
                        ref.read(employeeFilterProvider).copyWith(search: '');
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'refresh'.tr(),
              onPressed: () => ref.invalidate(employeesListProvider),
            ),
            const AppBarActions(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/employees/new'),
          icon: const Icon(Icons.person_add),
          label: Text('add_employee'.tr()),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(employeesListProvider);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EmployeeFilterBar(),
                const SizedBox(height: 16),
                Expanded(
                  child: employeesAsync.when(
                    data: (employees) {
                      if (employees.isEmpty) {
                        return EmptyStateWidget(
                          icon: Icons.people_outline,
                          title: 'no_employees'.tr(),
                          subtitle: 'no_employees_subtitle'.tr(),
                          actionLabel: 'add_employee'.tr(),
                          onAction: () => context.push('/employees/new'),
                        );
                      }

                      final jobTitlesMap = {
                        for (final t in (jobTitlesAsync.valueOrNull ?? []))
                          t.id: t.name,
                      };

                      return ListView.builder(
                        itemCount: employees.length,
                        itemBuilder: (context, index) {
                          final employee = employees[index];
                          return EmployeeCard(
                            employee: employee,
                            jobTitleName: employee.jobTitleId != null
                                ? jobTitlesMap[employee.jobTitleId]
                                : null,
                            onTap: () =>
                                context.push('/employees/${employee.id}'),
                            onEdit: () =>
                                context.push('/employees/${employee.id}/edit'),
                            onDelete: () =>
                                _confirmDelete(employee.id, employee.fullName),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 12),
                          Text('error_label'.tr(args: [error.toString()])),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () =>
                                ref.invalidate(employeesListProvider),
                            child: Text('retry'.tr()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
