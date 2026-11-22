import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/employee_form_fields.dart';
import '../models/product_model.dart';
import '../providers/product_category_provider.dart';
import '../providers/product_provider.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  final _nameZhCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _purchaseCtrl = TextEditingController(text: '0');
  final _sellingCtrl = TextEditingController(text: '0');
  final _minStockCtrl = TextEditingController(text: '0');
  final _unitCtrl = TextEditingController(text: 'قطعة');

  String? _categoryId;
  bool _isLoading = false;
  bool _isSaving = false;

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadProduct();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameEnCtrl.dispose();
    _nameZhCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    _purchaseCtrl.dispose();
    _sellingCtrl.dispose();
    _minStockCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    try {
      final product = await ref
          .read(productServiceProvider)
          .getProductById(widget.productId!);
      if (product != null && mounted) {
        setState(() {
          _nameCtrl.text = product.name;
          _nameEnCtrl.text = product.nameEn ?? '';
          _nameZhCtrl.text = product.nameZh ?? '';
          _descCtrl.text = product.description ?? '';
          _notesCtrl.text = product.notes ?? '';
          _purchaseCtrl.text = product.purchasePrice.toString();
          _sellingCtrl.text = product.sellingPrice.toString();
          _minStockCtrl.text = product.minStockLevel.toString();
          _unitCtrl.text = product.unit;
          _categoryId = product.categoryId;
        });
      }
    } catch (e) {
      debugPrint('LOAD PRODUCT ERROR: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final service = ref.read(productServiceProvider);

      final data = {
        'name': _nameCtrl.text.trim(),
        'name_en':
            _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        'name_zh':
            _nameZhCtrl.text.trim().isEmpty ? null : _nameZhCtrl.text.trim(),
        'category_id': _categoryId,
        'description':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'unit': _unitCtrl.text.trim().isEmpty ? 'قطعة' : _unitCtrl.text.trim(),
        'purchase_price': double.tryParse(_purchaseCtrl.text) ?? 0,
        'selling_price': double.tryParse(_sellingCtrl.text) ?? 0,
        'min_stock_level': int.tryParse(_minStockCtrl.text) ?? 0,
      };

      if (_isEdit) {
        await service.updateProduct(widget.productId!, data);
      } else {
        final product = ProductModel(
          id: '',
          name: _nameCtrl.text.trim(),
          nameEn:
              _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
          nameZh:
              _nameZhCtrl.text.trim().isEmpty ? null : _nameZhCtrl.text.trim(),
          categoryId: _categoryId,
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          unit: _unitCtrl.text.trim().isEmpty ? 'قطعة' : _unitCtrl.text.trim(),
          purchasePrice: double.tryParse(_purchaseCtrl.text) ?? 0,
          sellingPrice: double.tryParse(_sellingCtrl.text) ?? 0,
          minStockLevel: int.tryParse(_minStockCtrl.text) ?? 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await service.createProduct(product);
      }

      ref.invalidate(productsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit ? 'product_updated'.tr() : 'product_added'.tr(),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e, stackTrace) {
      debugPrint('SAVE PRODUCT ERROR: $e');
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
    final categoriesAsync = ref.watch(productCategoriesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'edit_product'.tr() : 'add_product'.tr()),
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
                          title: 'product_info'.tr(),
                          children: [
                            LabeledField(
                              label: 'product_name'.tr(),
                              child: TextFormField(
                                controller: _nameCtrl,
                                decoration: InputDecoration(
                                  hintText: 'enter_product_name'.tr(),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'required'.tr()
                                        : null,
                              ),
                            ),
                            LabeledField(
                              label: 'product_name_en'.tr(),
                              child: TextFormField(
                                controller: _nameEnCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Product Name (English)',
                                ),
                              ),
                            ),
                            LabeledField(
                              label: 'product_name_zh'.tr(),
                              child: TextFormField(
                                controller: _nameZhCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Product Name (Chinese)',
                                ),
                              ),
                            ),
                            LabeledField(
                              label: 'category'.tr(),
                              child: categoriesAsync.when(
                                data: (categories) =>
                                    DropdownButtonFormField<String>(
                                  initialValue: _categoryId,
                                  decoration: const InputDecoration(),
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text('no_category'.tr()),
                                    ),
                                    ...categories.map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.getLocalizedName(
                                            context.locale.languageCode)),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _categoryId = v),
                                ),
                                loading: () => const LinearProgressIndicator(),
                                error: (_, __) => Text('error_label'.tr()),
                              ),
                            ),
                            LabeledField(
                              label: 'unit'.tr(),
                              child: TextFormField(
                                controller: _unitCtrl,
                                decoration: InputDecoration(
                                  hintText: 'unit_hint'.tr(),
                                ),
                              ),
                            ),
                            LabeledField(
                              label: 'description'.tr(),
                              child: TextFormField(
                                controller: _descCtrl,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'description_hint'.tr(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        FormSection(
                          title: 'pricing'.tr(),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: LabeledField(
                                    label: 'purchase_price'.tr(),
                                    child: TextFormField(
                                      controller: _purchaseCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration:
                                          const InputDecoration(hintText: '0'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: LabeledField(
                                    label: 'selling_price'.tr(),
                                    child: TextFormField(
                                      controller: _sellingCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration:
                                          const InputDecoration(hintText: '0'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            LabeledField(
                              label: 'min_stock_level'.tr(),
                              child: TextFormField(
                                controller: _minStockCtrl,
                                keyboardType: TextInputType.number,
                                decoration:
                                    const InputDecoration(hintText: '0'),
                              ),
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
                          label: Text(
                            _isEdit ? 'update'.tr() : 'add_product'.tr(),
                          ),
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
