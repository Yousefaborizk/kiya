import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/job_title_model.dart';
import '../../providers/job_title_provider.dart';
import '../../providers/service_providers.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/shared/app_bar_actions.dart';
import '../../widgets/shared/app_shell.dart';

class JobTitlesScreen extends ConsumerWidget {
  const JobTitlesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langCode = context.locale.languageCode; // اللغة الحالية
    final titlesAsync = ref.watch(jobTitlesListProvider);

    return AppShell(
      currentRoute: '/job-titles',
      child: Scaffold(
        appBar: AppBar(
          title: Text('job_titles_title'.tr()),
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
              onPressed: () => ref.invalidate(jobTitlesListProvider),
            ),
            const AppBarActions(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showFormDialog(context, ref),
          icon: const Icon(Icons.add),
          label: Text('add_job_title_btn'.tr()),
        ),
        body: titlesAsync.when(
          data: (titles) {
            if (titles.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.work_outline,
                title: 'no_job_titles'.tr(),
                subtitle: 'no_job_titles_subtitle'.tr(),
                actionLabel: 'add_job_title_btn'.tr(),
                onAction: () => _showFormDialog(context, ref),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: titles.length,
              itemBuilder: (context, index) {
                final title = titles[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.work_outline,
                        color: AppColors.primary),
                    title: Text(
                      title.getLocalizedName(langCode),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: title.description != null
                        ? Text(title.description!)
                        : null,
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (v) async {
                        if (v == 'edit') {
                          _showFormDialog(context, ref, existing: title);
                        } else if (v == 'delete') {
                          _confirmDelete(context, ref, title);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text('edit_btn'.tr()),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline,
                                  size: 20, color: AppColors.error),
                              const SizedBox(width: 8),
                              Text(
                                'delete_btn'.tr(),
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('error_label'.tr(args: [e.toString()]))),
        ),
      ),
    );
  }

  Future<void> _showFormDialog(
    BuildContext context,
    WidgetRef ref, {
    JobTitleModel? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final nameEnCtrl = TextEditingController(text: existing?.nameEn ?? '');
    final nameZhCtrl = TextEditingController(text: existing?.nameZh ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null
              ? 'add_job_title_btn'.tr()
              : 'edit_job_title_btn'.tr(),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration:
                      InputDecoration(labelText: 'job_title_name_label'.tr()),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'required'.tr() : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameEnCtrl,
                  decoration: InputDecoration(
                    labelText: 'job_title_name_en_label'.tr(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameZhCtrl,
                  decoration: InputDecoration(
                    labelText: 'job_title_name_zh_label'.tr(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descCtrl,
                  decoration:
                      InputDecoration(labelText: 'job_title_desc_label'.tr()),
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
        final service = ref.read(employeeServiceProvider);
        if (existing == null) {
          final newTitle = JobTitleModel(
            id: '',
            name: nameCtrl.text.trim(),
            nameEn:
                nameEnCtrl.text.trim().isEmpty ? null : nameEnCtrl.text.trim(),
            nameZh:
                nameZhCtrl.text.trim().isEmpty ? null : nameZhCtrl.text.trim(),
            description:
                descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await service.createJobTitle(newTitle);
        } else {
          await service.updateJobTitle(existing.id, {
            'name': nameCtrl.text.trim(),
            'name_en':
                nameEnCtrl.text.trim().isEmpty ? null : nameEnCtrl.text.trim(),
            'name_zh':
                nameZhCtrl.text.trim().isEmpty ? null : nameZhCtrl.text.trim(),
            'description':
                descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          });
        }
        ref.invalidate(jobTitlesListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                existing == null
                    ? 'job_title_added_success'.tr()
                    : 'job_title_updated_success'.tr(),
              ),
              backgroundColor: AppColors.success,
            ),
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

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    JobTitleModel title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('delete_job_title_confirm'.tr(args: [title.name])),
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
      await ref.read(employeeServiceProvider).deleteJobTitle(title.id);
      ref.invalidate(jobTitlesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('job_title_deleted_success'.tr())),
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
