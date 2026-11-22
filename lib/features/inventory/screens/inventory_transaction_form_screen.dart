import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/products/providers/product_provider.dart';
import '../../../utils/inventory_validators.dart';
import '../../../widgets/employee_form_fields.dart';
import '../models/inventory_transaction_model.dart';
import '../providers/inventory_provider.dart';
import '../providers/warehouse_provider.dart';

class InventoryTransactionFormScreen extends ConsumerStatefulWidget {
  const InventoryTransactionFormScreen({super.key});

  @override
  ConsumerState<InventoryTransactionFormScreen> createState() =>
      _InventoryTransactionFormScreenState();
}

class _InventoryTransactionFormScreenState
    extends ConsumerState<InventoryTransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _productId;
  String? _warehouseId;
  String _transactionType = 'in';
  bool _isSaving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_productId == null || _warehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('select_product_and_warehouse'.tr())),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final service = ref.read(inventoryServiceProvider);

      final transaction = InventoryTransactionModel(
        id: '',
        productId: _productId!,
        warehouseId: _warehouseId!,
        transactionType: _transactionType,
        quantity: double.parse(_qtyCtrl.text),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: DateTime.now(),
      );

      await service.createTransaction(transaction);

      ref.invalidate(inventoryStockListProvider);
      ref.invalidate(inventoryTransactionsListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('transaction_added'.tr()),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('SAVE TRANSACTION ERROR: $e');
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
    final productsAsync = ref.watch(productsListProvider);
    final warehousesAsync = ref.watch(warehousesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('add_transaction'.tr()),
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
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormSection(
                    title: 'transaction_info'.tr(),
                    children: [
                      LabeledField(
                        label: 'transaction_type'.tr(),
                        child: DropdownButtonFormField<String>(
                          initialValue: _transactionType,
                          decoration: const InputDecoration(),
                          items: [
                            DropdownMenuItem(
                              value: 'in',
                              child: Text('in'.tr()),
                            ),
                            DropdownMenuItem(
                              value: 'out',
                              child: Text('out'.tr()),
                            ),
                            DropdownMenuItem(
                              value: 'adjustment',
                              child: Text('adjustment'.tr()),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _transactionType = v!),
                        ),
                      ),
                      LabeledField(
                        label: 'product'.tr(),
                        child: productsAsync.when(
                          data: (products) => DropdownButtonFormField<String>(
                            initialValue: _productId,
                            decoration: const InputDecoration(),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text('select_product'.tr()),
                              ),
                              ...products.map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  // هنا بنستخدم p.name مش getLocalizedName
                                  child: Text(p.name),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _productId = v),
                            validator: (v) =>
                                v == null ? 'required'.tr() : null,
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => Text('error_label'.tr()),
                        ),
                      ),
                      LabeledField(
                        label: 'warehouse'.tr(),
                        child: warehousesAsync.when(
                          data: (warehouses) => DropdownButtonFormField<String>(
                            initialValue: _warehouseId,
                            decoration: const InputDecoration(),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text('select_warehouse'.tr()),
                              ),
                              ...warehouses.map(
                                (w) => DropdownMenuItem(
                                  value: w.id,
                                  // هنا بنستخدم w.name مش getLocalizedName
                                  child: Text(w.name),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _warehouseId = v),
                            validator: (v) =>
                                v == null ? 'required'.tr() : null,
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => Text('error_label'.tr()),
                        ),
                      ),
                      LabeledField(
                        label: 'quantity'.tr(),
                        child: TextFormField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '0'),
                          validator: (v) => InventoryValidators.positiveNumber(
                            v,
                            message: 'invalid_quantity'.tr(),
                          ),
                        ),
                      ),
                      LabeledField(
                        label: 'notes'.tr(),
                        child: TextFormField(
                          controller: _notesCtrl,
                          maxLines: 3,
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
                    label: Text('add_transaction'.tr()),
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
