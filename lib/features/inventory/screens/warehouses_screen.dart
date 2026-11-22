import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/shared/app_bar_actions.dart';
import '../../../widgets/shared/app_shell.dart';
import '../models/warehouse_model.dart';
import '../providers/warehouse_provider.dart';

class WarehousesScreen extends ConsumerWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehousesAsync = ref.watch(warehousesListProvider);

    return AppShell(
      currentRoute: '/inventory',
      child: Scaffold(
        appBar: AppBar(
          title: Text('warehouses_title'.tr()),
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
              onPressed: () => ref.invalidate(warehousesListProvider),
            ),
            const AppBarActions(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showWarehouseForm(context, ref),
          icon: const Icon(Icons.add),
          label: Text('add_warehouse'.tr()),
        ),
        body: warehousesAsync.when(
          data: (warehouses) {
            if (warehouses.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.warehouse_outlined,
                title: 'no_warehouses'.tr(),
                subtitle: 'no_warehouses_subtitle'.tr(),
                actionLabel: 'add_warehouse'.tr(),
                onAction: () => _showWarehouseForm(context, ref),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: warehouses.length,
              itemBuilder: (context, index) {
                final warehouse = warehouses[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(
                      Icons.warehouse_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      warehouse.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: warehouse.location != null
                        ? Text(warehouse.location!)
                        : null,
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (v) async {
                        if (v == 'edit') {
                          _showWarehouseForm(context, ref, existing: warehouse);
                        } else if (v == 'delete') {
                          _confirmDelete(context, ref, warehouse);
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

  Future<void> _showWarehouseForm(
    BuildContext context,
    WidgetRef ref, {
    WarehouseModel? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final locationCtrl = TextEditingController(text: existing?.location ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null ? 'add_warehouse'.tr() : 'edit_warehouse'.tr(),
        ),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration:
                        InputDecoration(labelText: 'warehouse_name'.tr()),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'required'.tr()
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: locationCtrl,
                    decoration: InputDecoration(
                      labelText: 'warehouse_location'.tr(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'notes'.tr(),
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
        final service = ref.read(inventoryServiceProvider);
        if (existing == null) {
          final newWarehouse = WarehouseModel(
            id: '',
            name: nameCtrl.text.trim(),
            location: locationCtrl.text.trim().isEmpty
                ? null
                : locationCtrl.text.trim(),
            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await service.createWarehouse(newWarehouse);
        } else {
          await service.updateWarehouse(existing.id, {
            'name': nameCtrl.text.trim(),
            'location': locationCtrl.text.trim().isEmpty
                ? null
                : locationCtrl.text.trim(),
            'notes':
                notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
          });
        }
        ref.invalidate(warehousesListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                existing == null
                    ? 'warehouse_added'.tr()
                    : 'warehouse_updated'.tr(),
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        debugPrint('CREATE WAREHOUSE ERROR: $e');
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
    WarehouseModel warehouse,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('delete_warehouse_confirm'.tr(args: [warehouse.name])),
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
      await ref.read(inventoryServiceProvider).deleteWarehouse(warehouse.id);
      ref.invalidate(warehousesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('warehouse_deleted'.tr())),
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
