import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/products/providers/product_provider.dart';
import '../../../features/inventory/providers/warehouse_provider.dart';
import '../../../features/inventory/providers/inventory_provider.dart';
import '../../../widgets/employee_form_fields.dart';
import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';
import '../providers/sales_provider.dart';

class InvoiceFormScreen extends ConsumerStatefulWidget {
  const InvoiceFormScreen({super.key});

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _customerId;

  // ── متغيرات الخصم والضريبة ──
  final _discountCtrl = TextEditingController(text: '0');
  final _taxCtrl = TextEditingController(text: '0');
  String _discountType = 'fixed'; // 'fixed' or 'percentage'
  String _taxType = 'percentage'; // 'fixed' or 'percentage'

  final List<InvoiceItemModel> _items = [];
  bool _isSaving = false;

  // ── الحسابات ──
  double get _subtotal =>
      _items.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice));

  double get _calculatedDiscount {
    final val = double.tryParse(_discountCtrl.text) ?? 0;
    if (_discountType == 'percentage') {
      final calc = _subtotal * (val / 100);
      return calc > _subtotal ? _subtotal : calc;
    }
    return val > _subtotal ? _subtotal : val;
  }

  double get _calculatedTax {
    final val = double.tryParse(_taxCtrl.text) ?? 0;
    final afterDiscount = _subtotal - _calculatedDiscount;
    if (_taxType == 'percentage') {
      return afterDiscount * (val / 100);
    }
    return val;
  }

  double get _total => _subtotal - _calculatedDiscount + _calculatedTax;

  @override
  void dispose() {
    _discountCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  /// توليد رقم فاتورة فريد قابل للقراءة
  /// مثال: INV-20241101-143025123
  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final sec = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return 'INV-$y$m$d-$h$min$sec$ms';
  }

  Future<void> _save() async {
    if (_customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('select_customer'.tr())),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('add_at_least_one_item'.tr())),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final service = ref.read(salesServiceProvider);

      // ⚠️ رقم الفاتورة إجباري في الداتابيز (NOT NULL UNIQUE)
      //    بنولّده هنا عشان نتجنب error الـ insert
      final newInvoice = InvoiceModel(
        id: '',
        invoiceNumber: _generateInvoiceNumber(),
        customerId: _customerId,
        invoiceDate: DateTime.now(),
        subtotal: _subtotal,
        discount: _calculatedDiscount,
        tax: _calculatedTax,
        total: _total,
        paidAmount: 0,
        status: 'issued',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final finalItems = _items.map((e) => e.copyWith(invoiceId: '')).toList();

      await service.createInvoice(newInvoice, finalItems);

      // تحديث كل الشاشات المتأثرة (لو فيه DB trigger بيخصم من المخزون)
      ref.invalidate(invoicesListProvider);
      ref.invalidate(inventoryStockListProvider);
      ref.invalidate(inventoryTransactionsListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('invoice_added'.tr()),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        // تنظيف نص الإيرور عشان يظهر بشكل شيك
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addItem() async {
    // بنجيب المنتجات والمخازن
    final products = await ref.read(productsListProvider.future);
    final warehouses = await ref.read(warehousesListProvider.future);

    if (products.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('no_products_add_first'.tr())),
        );
      }
      return;
    }
    if (warehouses.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أضف مستودعات أولاً من قسم المخازن')),
        );
      }
      return;
    }

    String? selectedProductId;
    String? selectedWarehouseId;
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();

    if (!mounted) return;

    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('add_item'.tr()),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. اختيار المنتج
                DropdownButtonFormField<String>(
                  initialValue: selectedProductId,
                  decoration: InputDecoration(labelText: 'product'.tr()),
                  items: products
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setDialogState(() {
                      selectedProductId = v;
                      final product =
                          products.where((p) => p.id == v).firstOrNull;
                      if (product != null) {
                        priceCtrl.text = product.sellingPrice.toString();
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                // 2. اختيار المخزن
                DropdownButtonFormField<String>(
                  initialValue: selectedWarehouseId,
                  decoration:
                      const InputDecoration(labelText: 'المخزن (Warehouse)'),
                  items: warehouses
                      .map((w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setDialogState(() {
                      selectedWarehouseId = v;
                    });
                  },
                ),
                const SizedBox(height: 8),
                // 3. الكمية
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'quantity'.tr()),
                ),
                const SizedBox(height: 8),
                // 4. السعر
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'unit_price'.tr()),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel_btn'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedProductId != null &&
                  selectedWarehouseId != null &&
                  qtyCtrl.text.isNotEmpty) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يجب اختيار المنتج والمخزن')),
                );
              }
            },
            child: Text('add'.tr()),
          ),
        ],
      ),
    );

    if (added == true) {
      final product =
          products.where((p) => p.id == selectedProductId).firstOrNull;
      final warehouse =
          warehouses.where((w) => w.id == selectedWarehouseId).firstOrNull;

      final qty = double.tryParse(qtyCtrl.text) ?? 0;
      final price = double.tryParse(priceCtrl.text) ?? 0;

      if (qty <= 0 || price <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الكمية والسعر يجب أن يكونا أكبر من صفر'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      setState(() {
        _items.add(InvoiceItemModel(
          id: '',
          invoiceId: '',
          productId: selectedProductId,
          warehouseId: selectedWarehouseId,
          quantity: qty,
          unitPrice: price,
          discount: 0,
          total: qty * price,
          createdAt: DateTime.now(),
          productName: product?.name,
          warehouseName: warehouse?.name,
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('add_invoice'.tr()),
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
                    title: 'customer_info'.tr(),
                    children: [
                      LabeledField(
                        label: 'customer'.tr(),
                        child: customersAsync.when(
                          data: (customers) => DropdownButtonFormField<String>(
                            initialValue: _customerId,
                            decoration: const InputDecoration(),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text('select_customer'.tr()),
                              ),
                              ...customers.map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _customerId = v),
                            validator: (v) =>
                                v == null ? 'required'.tr() : null,
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => Text('error_label'
                              .tr(args: ['Error loading customers'])),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  FormSection(
                    title: 'invoice_items'.tr(),
                    children: [
                      ..._items.map((item) => ListTile(
                            title: Text(item.productName ?? '-'),
                            subtitle: Text(
                              '${item.quantity} x ${item.unitPrice} = ${item.total}\nالمخزن: ${item.warehouseName ?? "-"}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.error),
                              onPressed: () {
                                setState(() => _items.remove(item));
                              },
                            ),
                          )),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: Text('add_item'.tr()),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // ── كارت الخصم والضريبة ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _discountCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d*')),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'discount'.tr(),
                                    prefixIcon:
                                        const Icon(Icons.discount_outlined),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 100,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _discountType,
                                  decoration: const InputDecoration(),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'fixed', child: Text('EGP')),
                                    DropdownMenuItem(
                                        value: 'percentage', child: Text('%')),
                                  ],
                                  onChanged: (v) => setState(
                                      () => _discountType = v ?? 'fixed'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _taxCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d*')),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'tax'.tr(),
                                    prefixIcon:
                                        const Icon(Icons.receipt_long_outlined),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 100,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _taxType,
                                  decoration: const InputDecoration(),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'fixed', child: Text('EGP')),
                                    DropdownMenuItem(
                                        value: 'percentage', child: Text('%')),
                                  ],
                                  onChanged: (v) => setState(
                                      () => _taxType = v ?? 'percentage'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── الإجماليات ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _TotalRow(
                              label: 'subtotal'.tr(),
                              value: _subtotal.toStringAsFixed(2)),
                          _TotalRow(
                              label: 'discount'.tr(),
                              value:
                                  '- ${_calculatedDiscount.toStringAsFixed(2)}',
                              valueColor: AppColors.error),
                          _TotalRow(
                              label: 'tax'.tr(),
                              value: '+ ${_calculatedTax.toStringAsFixed(2)}',
                              valueColor: AppColors.success),
                          const Divider(),
                          _TotalRow(
                            label: 'total'.tr(),
                            value: _total.toStringAsFixed(2),
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text('save_invoice'.tr()),
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
