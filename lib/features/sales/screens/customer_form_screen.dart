import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/employee_form_fields.dart';
import '../models/customer_model.dart';
import '../providers/sales_provider.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final String? customerId;

  const CustomerFormScreen({super.key, this.customerId});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // ── Basic
  final _nameCtrl = TextEditingController();
  final _legalNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _customerType = 'individual';
  int _rating = 0;
  final List<String> _tags = [];
  final _tagCtrl = TextEditingController();

  // ── Contact
  final List<CustomerPhone> _phones = [];
  final List<CustomerEmail> _emails = [];
  final _cpNameCtrl = TextEditingController();
  final _cpTitleCtrl = TextEditingController();
  final _cpPhoneCtrl = TextEditingController();
  final _cpEmailCtrl = TextEditingController();

  // ── Social
  final _websiteCtrl = TextEditingController();
  final Map<String, TextEditingController> _socialCtrls = {
    'linkedin': TextEditingController(),
    'facebook': TextEditingController(),
    'instagram': TextEditingController(),
    'twitter': TextEditingController(),
    'whatsapp': TextEditingController(),
    'telegram': TextEditingController(),
    'wechat': TextEditingController(),
    'tiktok': TextEditingController(),
    'youtube': TextEditingController(),
  };

  // ── Shipping
  final _countryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _fullAddressCtrl = TextEditingController();
  final _shippingAddressCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _creditCtrl = TextEditingController(text: '0');
  String _currency = 'EGP';
  String? _paymentTerms;
  String? _incoterms;

  // ── Legal
  final _taxCtrl = TextEditingController();
  final _crCtrl = TextEditingController();
  final _vatCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;

  bool get _isEdit => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    if (_isEdit) _loadCustomer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _legalNameCtrl.dispose();
    _notesCtrl.dispose();
    _tagCtrl.dispose();
    _cpNameCtrl.dispose();
    _cpTitleCtrl.dispose();
    _cpPhoneCtrl.dispose();
    _cpEmailCtrl.dispose();
    _websiteCtrl.dispose();
    for (final c in _socialCtrls.values) {
      c.dispose();
    }
    _countryCtrl.dispose();
    _cityCtrl.dispose();
    _postalCtrl.dispose();
    _fullAddressCtrl.dispose();
    _shippingAddressCtrl.dispose();
    _portCtrl.dispose();
    _creditCtrl.dispose();
    _taxCtrl.dispose();
    _crCtrl.dispose();
    _vatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomer() async {
    setState(() => _isLoading = true);
    try {
      final customer = await ref
          .read(salesServiceProvider)
          .getCustomerById(widget.customerId!);
      if (customer != null && mounted) {
        setState(() {
          _nameCtrl.text = customer.name;
          _legalNameCtrl.text = customer.legalName ?? '';
          _notesCtrl.text = customer.notes ?? '';
          _customerType = customer.customerType;
          _rating = customer.rating;
          _tags
            ..clear()
            ..addAll(customer.tags);

          _phones
            ..clear()
            ..addAll(customer.phones);
          _emails
            ..clear()
            ..addAll(customer.emails);

          _cpNameCtrl.text = customer.contactPersonName ?? '';
          _cpTitleCtrl.text = customer.contactPersonTitle ?? '';
          _cpPhoneCtrl.text = customer.contactPersonPhone ?? '';
          _cpEmailCtrl.text = customer.contactPersonEmail ?? '';

          _websiteCtrl.text = customer.website ?? '';
          for (final entry in _socialCtrls.entries) {
            entry.value.text = customer.socialMedia[entry.key] ?? '';
          }

          _countryCtrl.text = customer.country ?? '';
          _cityCtrl.text = customer.city ?? '';
          _postalCtrl.text = customer.postalCode ?? '';
          _fullAddressCtrl.text = customer.fullAddress ?? '';
          _shippingAddressCtrl.text = customer.shippingAddress ?? '';
          _portCtrl.text = customer.preferredPort ?? '';
          _creditCtrl.text = customer.creditLimit.toString();
          _currency = customer.currency;
          _paymentTerms = customer.paymentTerms;
          _incoterms = customer.incoterms;

          _taxCtrl.text = customer.taxNumber ?? '';
          _crCtrl.text = customer.commercialRegister ?? '';
          _vatCtrl.text = customer.vatNumber ?? '';
        });
      }
    } catch (e) {
      debugPrint('LOAD CUSTOMER ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_label'.tr(args: [e.toString()]))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addTag() {
    final t = _tagCtrl.text.trim();
    if (t.isEmpty || _tags.contains(t)) return;
    setState(() {
      _tags.add(t);
      _tagCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // التحقق من الاسم
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('required'.tr())),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final service = ref.read(salesServiceProvider);

      // تجهيز خريطة السوشيال ميديا (فقط القيم غير الفارغة)
      final socialMap = <String, String>{};
      for (final entry in _socialCtrls.entries) {
        final v = entry.value.text.trim();
        if (v.isNotEmpty) socialMap[entry.key] = v;
      }

      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'legal_name': _legalNameCtrl.text.trim().isEmpty
            ? null
            : _legalNameCtrl.text.trim(),
        'customer_type': _customerType,
        'phones': _phones.map((e) => e.toJson()).toList(),
        'emails': _emails.map((e) => e.toJson()).toList(),
        'contact_person_name':
            _cpNameCtrl.text.trim().isEmpty ? null : _cpNameCtrl.text.trim(),
        'contact_person_title':
            _cpTitleCtrl.text.trim().isEmpty ? null : _cpTitleCtrl.text.trim(),
        'contact_person_phone':
            _cpPhoneCtrl.text.trim().isEmpty ? null : _cpPhoneCtrl.text.trim(),
        'contact_person_email':
            _cpEmailCtrl.text.trim().isEmpty ? null : _cpEmailCtrl.text.trim(),
        'website':
            _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        'social_media': socialMap,
        'country':
            _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
        'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        'postal_code':
            _postalCtrl.text.trim().isEmpty ? null : _postalCtrl.text.trim(),
        'full_address': _fullAddressCtrl.text.trim().isEmpty
            ? null
            : _fullAddressCtrl.text.trim(),
        'shipping_address': _shippingAddressCtrl.text.trim().isEmpty
            ? null
            : _shippingAddressCtrl.text.trim(),
        'currency': _currency,
        'payment_terms': _paymentTerms,
        'credit_limit': double.tryParse(_creditCtrl.text) ?? 0,
        'incoterms': _incoterms,
        'preferred_port':
            _portCtrl.text.trim().isEmpty ? null : _portCtrl.text.trim(),
        'tax_number':
            _taxCtrl.text.trim().isEmpty ? null : _taxCtrl.text.trim(),
        'commercial_register':
            _crCtrl.text.trim().isEmpty ? null : _crCtrl.text.trim(),
        'vat_number':
            _vatCtrl.text.trim().isEmpty ? null : _vatCtrl.text.trim(),
        'rating': _rating,
        'tags': _tags,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };

      // مزامنة phone/email القديمة مع أول عنصر primary
      if (_phones.isNotEmpty) {
        final primary = _phones.firstWhere(
          (p) => p.isPrimary,
          orElse: () => _phones.first,
        );
        data['phone'] = primary.number;
      }
      if (_emails.isNotEmpty) {
        final primary = _emails.firstWhere(
          (e) => e.isPrimary,
          orElse: () => _emails.first,
        );
        data['email'] = primary.email;
      }

      if (_isEdit) {
        await service.updateCustomer(widget.customerId!, data);
      } else {
        final customer = CustomerModel(
          id: '',
          name: _nameCtrl.text.trim(),
          customerType: _customerType,
          phones: _phones,
          emails: _emails,
          currency: _currency,
          rating: _rating,
          tags: _tags,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await service.createCustomer(customer);
      }

      ref.invalidate(customersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit ? 'customer_updated'.tr() : 'customer_added'.tr(),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('SAVE CUSTOMER ERROR: $e');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'edit_customer'.tr() : 'add_customer'.tr()),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.secondary,
          tabs: [
            Tab(text: 'basic_info'.tr()),
            Tab(text: 'customer_contact_info'.tr()),
            Tab(text: 'customer_social_media'.tr()),
            Tab(text: 'customer_shipping'.tr()),
            Tab(text: 'customer_legal'.tr()),
          ],
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
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicTab(),
                  _buildContactTab(),
                  _buildSocialTab(),
                  _buildShippingTab(),
                  _buildLegalTab(),
                ],
              ),
            ),
    );
  }

  // ============================================
  // TAB 1: BASIC
  // ============================================
  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormSection(
                title: 'customer_basic_info'.tr(),
                children: [
                  LabeledField(
                    label: 'customer_name'.tr(),
                    child: TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'enter_customer_name'.tr(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'required'.tr()
                          : null,
                    ),
                  ),
                  LabeledField(
                    label: 'legal_name'.tr(),
                    child: TextFormField(
                      controller: _legalNameCtrl,
                      decoration: InputDecoration(
                        hintText: 'enter_legal_name'.tr(),
                      ),
                    ),
                  ),
                  LabeledField(
                    label: 'customer_type'.tr(),
                    child: DropdownButtonFormField<String>(
                      initialValue: _customerType,
                      decoration: const InputDecoration(),
                      items: [
                        DropdownMenuItem(
                          value: 'individual',
                          child: Text('type_individual'.tr()),
                        ),
                        DropdownMenuItem(
                          value: 'company',
                          child: Text('type_company'.tr()),
                        ),
                        DropdownMenuItem(
                          value: 'distributor',
                          child: Text('type_distributor'.tr()),
                        ),
                        DropdownMenuItem(
                          value: 'agent',
                          child: Text('type_agent'.tr()),
                        ),
                        DropdownMenuItem(
                          value: 'government',
                          child: Text('type_government'.tr()),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _customerType = v ?? 'individual'),
                    ),
                  ),
                  LabeledField(
                    label: 'rating'.tr(),
                    child: Row(
                      children: List.generate(5, (i) {
                        return IconButton(
                          icon: Icon(
                            i < _rating ? Icons.star : Icons.star_border,
                            color: AppColors.secondary,
                          ),
                          onPressed: () => setState(
                            () => _rating = (i + 1 == _rating) ? 0 : i + 1,
                          ),
                        );
                      }),
                    ),
                  ),
                  LabeledField(
                    label: 'tags'.tr(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_tags.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _tags
                                .map((t) => Chip(
                                      label: Text(t),
                                      onDeleted: () =>
                                          setState(() => _tags.remove(t)),
                                    ))
                                .toList(),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _tagCtrl,
                                decoration: InputDecoration(
                                  hintText: 'add_tag'.tr(),
                                ),
                                onSubmitted: (_) => _addTag(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _addTag,
                            ),
                          ],
                        ),
                      ],
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
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // TAB 2: CONTACT
  // ============================================
  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormSection(
                title: 'phones'.tr(),
                children: [
                  ..._phones.asMap().entries.map((entry) {
                    final i = entry.key;
                    final p = entry.value;
                    return _PhoneRow(
                      phone: p,
                      onChanged: (updated) => setState(() {
                        if (updated.isPrimary) {
                          for (var j = 0; j < _phones.length; j++) {
                            if (j != i) {
                              _phones[j] =
                                  _phones[j].copyWith(isPrimary: false);
                            }
                          }
                        }
                        _phones[i] = updated;
                      }),
                      onDelete: () => setState(() => _phones.removeAt(i)),
                    );
                  }),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _phones.add(
                          CustomerPhone(
                            label: 'mobile',
                            number: '',
                            isPrimary: _phones.isEmpty,
                          ),
                        )),
                    icon: const Icon(Icons.add),
                    label: Text('add_phone'.tr()),
                  ),
                ],
              ),
              const Divider(height: 32),
              FormSection(
                title: 'emails'.tr(),
                children: [
                  ..._emails.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    return _EmailRow(
                      email: e,
                      onChanged: (updated) => setState(() {
                        if (updated.isPrimary) {
                          for (var j = 0; j < _emails.length; j++) {
                            if (j != i) {
                              _emails[j] =
                                  _emails[j].copyWith(isPrimary: false);
                            }
                          }
                        }
                        _emails[i] = updated;
                      }),
                      onDelete: () => setState(() => _emails.removeAt(i)),
                    );
                  }),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _emails.add(
                          CustomerEmail(
                            label: 'info',
                            email: '',
                            isPrimary: _emails.isEmpty,
                          ),
                        )),
                    icon: const Icon(Icons.add),
                    label: Text('add_email'.tr()),
                  ),
                ],
              ),
              const Divider(height: 32),
              FormSection(
                title: 'contact_person'.tr(),
                children: [
                  LabeledField(
                    label: 'contact_person_name'.tr(),
                    child: TextFormField(
                      controller: _cpNameCtrl,
                      decoration: const InputDecoration(),
                    ),
                  ),
                  LabeledField(
                    label: 'contact_person_title'.tr(),
                    child: TextFormField(
                      controller: _cpTitleCtrl,
                      decoration: const InputDecoration(),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: 'phone'.tr(),
                          child: TextFormField(
                            controller: _cpPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledField(
                          label: 'email'.tr(),
                          child: TextFormField(
                            controller: _cpEmailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // TAB 3: SOCIAL
  // ============================================
  Widget _buildSocialTab() {
    final labels = {
      'linkedin': 'social_linkedin',
      'facebook': 'social_facebook',
      'instagram': 'social_instagram',
      'twitter': 'social_twitter',
      'whatsapp': 'social_whatsapp',
      'telegram': 'social_telegram',
      'wechat': 'social_wechat',
      'tiktok': 'social_tiktok',
      'youtube': 'social_youtube',
    };
    final icons = {
      'linkedin': Icons.work_outline,
      'facebook': Icons.facebook,
      'instagram': Icons.camera_alt_outlined,
      'twitter': Icons.alternate_email,
      'whatsapp': Icons.chat,
      'telegram': Icons.send,
      'wechat': Icons.message,
      'tiktok': Icons.music_note,
      'youtube': Icons.play_circle_outline,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormSection(
                title: 'website'.tr(),
                children: [
                  LabeledField(
                    label: 'website'.tr(),
                    child: TextFormField(
                      controller: _websiteCtrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        hintText: 'https://example.com',
                        prefixIcon: Icon(Icons.language),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              FormSection(
                title: 'customer_social_media'.tr(),
                children: labels.entries.map((entry) {
                  return LabeledField(
                    label: entry.value.tr(),
                    child: TextFormField(
                      controller: _socialCtrls[entry.key],
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        prefixIcon: Icon(icons[entry.key]),
                        hintText: 'https://...',
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // TAB 4: SHIPPING
  // ============================================
  Widget _buildShippingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormSection(
                title: 'customer_shipping'.tr(),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: 'country'.tr(),
                          child: TextFormField(
                            controller: _countryCtrl,
                            decoration: const InputDecoration(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledField(
                          label: 'city'.tr(),
                          child: TextFormField(
                            controller: _cityCtrl,
                            decoration: const InputDecoration(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledField(
                          label: 'postal_code'.tr(),
                          child: TextFormField(
                            controller: _postalCtrl,
                            decoration: const InputDecoration(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  LabeledField(
                    label: 'full_address'.tr(),
                    child: TextFormField(
                      controller: _fullAddressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(),
                    ),
                  ),
                  LabeledField(
                    label: 'shipping_address'.tr(),
                    child: TextFormField(
                      controller: _shippingAddressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(),
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
                          label: 'currency'.tr(),
                          child: DropdownButtonFormField<String>(
                            initialValue: _currency,
                            decoration: const InputDecoration(),
                            items: const [
                              DropdownMenuItem(
                                  value: 'EGP', child: Text('EGP')),
                              DropdownMenuItem(
                                  value: 'USD', child: Text('USD')),
                              DropdownMenuItem(
                                  value: 'EUR', child: Text('EUR')),
                              DropdownMenuItem(
                                  value: 'CNY', child: Text('CNY')),
                              DropdownMenuItem(
                                  value: 'GBP', child: Text('GBP')),
                              DropdownMenuItem(
                                  value: 'AED', child: Text('AED')),
                              DropdownMenuItem(
                                  value: 'SAR', child: Text('SAR')),
                            ],
                            onChanged: (v) =>
                                setState(() => _currency = v ?? 'EGP'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledField(
                          label: 'credit_limit'.tr(),
                          child: TextFormField(
                            controller: _creditCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: const InputDecoration(hintText: '0'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: 'payment_terms'.tr(),
                          child: DropdownButtonFormField<String>(
                            initialValue: _paymentTerms,
                            decoration: const InputDecoration(),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('-')),
                              DropdownMenuItem(
                                value: 'cash',
                                child: Text('payment_cash'.tr()),
                              ),
                              DropdownMenuItem(
                                value: 'net_30',
                                child: Text('payment_net_30'.tr()),
                              ),
                              DropdownMenuItem(
                                value: 'net_60',
                                child: Text('payment_net_60'.tr()),
                              ),
                              DropdownMenuItem(
                                value: 'net_90',
                                child: Text('payment_net_90'.tr()),
                              ),
                              DropdownMenuItem(
                                value: 'lc',
                                child: Text('payment_lc'.tr()),
                              ),
                              DropdownMenuItem(
                                value: 'tt',
                                child: Text('payment_tt'.tr()),
                              ),
                              DropdownMenuItem(
                                value: 'advance',
                                child: Text('payment_advance'.tr()),
                              ),
                            ],
                            onChanged: (v) => setState(() => _paymentTerms = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledField(
                          label: 'incoterms'.tr(),
                          child: DropdownButtonFormField<String>(
                            initialValue: _incoterms,
                            decoration: const InputDecoration(),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('-')),
                              DropdownMenuItem(
                                  value: 'FOB', child: Text('FOB')),
                              DropdownMenuItem(
                                  value: 'CIF', child: Text('CIF')),
                              DropdownMenuItem(
                                  value: 'EXW', child: Text('EXW')),
                              DropdownMenuItem(
                                  value: 'DDP', child: Text('DDP')),
                              DropdownMenuItem(
                                  value: 'FCA', child: Text('FCA')),
                              DropdownMenuItem(
                                  value: 'CFR', child: Text('CFR')),
                            ],
                            onChanged: (v) => setState(() => _incoterms = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  LabeledField(
                    label: 'preferred_port'.tr(),
                    child: TextFormField(
                      controller: _portCtrl,
                      decoration: const InputDecoration(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // TAB 5: LEGAL
  // ============================================
  Widget _buildLegalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormSection(
                title: 'customer_legal'.tr(),
                children: [
                  LabeledField(
                    label: 'tax_number'.tr(),
                    child: TextFormField(
                      controller: _taxCtrl,
                      decoration: const InputDecoration(),
                    ),
                  ),
                  LabeledField(
                    label: 'commercial_register'.tr(),
                    child: TextFormField(
                      controller: _crCtrl,
                      decoration: const InputDecoration(),
                    ),
                  ),
                  LabeledField(
                    label: 'vat_number'.tr(),
                    child: TextFormField(
                      controller: _vatCtrl,
                      decoration: const InputDecoration(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// Phone Row
// ============================================
class _PhoneRow extends StatelessWidget {
  final CustomerPhone phone;
  final ValueChanged<CustomerPhone> onChanged;
  final VoidCallback onDelete;

  const _PhoneRow({
    required this.phone,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: DropdownButtonFormField<String>(
              initialValue: phone.label,
              decoration: const InputDecoration(),
              items: [
                DropdownMenuItem(
                    value: 'mobile', child: Text('label_mobile'.tr())),
                DropdownMenuItem(
                    value: 'landline', child: Text('label_landline'.tr())),
                DropdownMenuItem(
                    value: 'whatsapp', child: Text('label_whatsapp'.tr())),
                DropdownMenuItem(value: 'fax', child: Text('label_fax'.tr())),
              ],
              onChanged: (v) =>
                  onChanged(phone.copyWith(label: v ?? phone.label)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              key: ValueKey('phone_${phone.number}'),
              initialValue: phone.number,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: '+20...'),
              onChanged: (v) => onChanged(phone.copyWith(number: v)),
            ),
          ),
          IconButton(
            tooltip: 'primary'.tr(),
            icon: Icon(
              phone.isPrimary ? Icons.star : Icons.star_border,
              color: phone.isPrimary ? AppColors.secondary : null,
            ),
            onPressed: () =>
                onChanged(phone.copyWith(isPrimary: !phone.isPrimary)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ============================================
// Email Row
// ============================================
class _EmailRow extends StatelessWidget {
  final CustomerEmail email;
  final ValueChanged<CustomerEmail> onChanged;
  final VoidCallback onDelete;

  const _EmailRow({
    required this.email,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: DropdownButtonFormField<String>(
              initialValue: email.label,
              decoration: const InputDecoration(),
              items: [
                DropdownMenuItem(value: 'info', child: Text('label_info'.tr())),
                DropdownMenuItem(
                    value: 'sales', child: Text('label_sales'.tr())),
                DropdownMenuItem(
                    value: 'support', child: Text('label_support'.tr())),
              ],
              onChanged: (v) =>
                  onChanged(email.copyWith(label: v ?? email.label)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              key: ValueKey('email_${email.email}'),
              initialValue: email.email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'example@email.com'),
              onChanged: (v) => onChanged(email.copyWith(email: v)),
            ),
          ),
          IconButton(
            tooltip: 'primary'.tr(),
            icon: Icon(
              email.isPrimary ? Icons.star : Icons.star_border,
              color: email.isPrimary ? AppColors.secondary : null,
            ),
            onPressed: () =>
                onChanged(email.copyWith(isPrimary: !email.isPrimary)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
