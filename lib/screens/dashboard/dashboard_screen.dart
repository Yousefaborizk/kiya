import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/employee_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/shared/app_bar_actions.dart';
import '../../widgets/shared/app_shell.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // السطر ده هو أهم سطر عشان المحتوى يتحدث
    final language = ref.watch(languageProvider);

    return AppShell(
      currentRoute: '/dashboard',
      child: Scaffold(
        key: ValueKey('dash_${language.languageCode}'),
        appBar: AppBar(
          title: Text('dashboard'.tr()),
          automaticallyImplyLeading: false,
          leading: MediaQuery.of(context).size.width < 900
              ? Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                )
              : null,
          actions: const [AppBarActions()],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primaryLight,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'welcome_hi'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'welcome_quick_overview'.tr(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.dashboard,
                        size: 64,
                        color: Colors.white24,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final employeesAsync = ref.watch(employeesListProvider);
                  return employeesAsync.when(
                    data: (employees) {
                      final active =
                          employees.where((e) => e.status == 'active').length;
                      final onLeave =
                          employees.where((e) => e.status == 'on_leave').length;
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final crossCount = constraints.maxWidth > 900 ? 4 : 2;
                          return GridView.count(
                            crossAxisCount: crossCount,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.6,
                            children: [
                              _StatCard(
                                title: 'total_employees'.tr(),
                                value: employees.length.toString(),
                                icon: Icons.people,
                                color: AppColors.primary,
                              ),
                              _StatCard(
                                title: 'active_employees'.tr(),
                                value: active.toString(),
                                icon: Icons.check_circle,
                                color: AppColors.success,
                              ),
                              _StatCard(
                                title: 'on_leave'.tr(),
                                value: onLeave.toString(),
                                icon: Icons.beach_access,
                                color: AppColors.warning,
                              ),
                              _StatCard(
                                title: 'job_titles'.tr(),
                                value: '—',
                                icon: Icons.work,
                                color: AppColors.info,
                              ),
                            ],
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'error_loading_stats'.tr(args: [e.toString()]),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'quick_actions'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _QuickAction(
                            label: 'add_employee'.tr(),
                            icon: Icons.person_add,
                            onTap: () => context.push('/employees/new'),
                          ),
                          _QuickAction(
                            label: 'employees_list'.tr(),
                            icon: Icons.people,
                            onTap: () => context.go('/employees'),
                          ),
                          _QuickAction(
                            label: 'job_titles'.tr(),
                            icon: Icons.work,
                            onTap: () => context.go('/job-titles'),
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
