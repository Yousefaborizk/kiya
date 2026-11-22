import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../models/customer_model.dart';
import '../providers/sales_provider.dart';

class CustomerProfileScreen extends ConsumerWidget {
  final String customerId;

  const CustomerProfileScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerByIdProvider(customerId));

    return Scaffold(
      appBar: AppBar(
        title: Text('customer_profile'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'edit'.tr(),
            onPressed: () => context.push('/sales/customers/$customerId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'refresh'.tr(),
            onPressed: () => ref.invalidate(customerByIdProvider(customerId)),
          ),
        ],
      ),
      body: customerAsync.when(
        data: (customer) {
          if (customer == null) {
            return Center(child: Text('customer_not_found'.tr()));
          }
          return _CustomerProfileBody(customer: customer);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('error_label'.tr(args: [e.toString()]))),
      ),
    );
  }
}

class _CustomerProfileBody extends StatelessWidget {
  final CustomerModel customer;

  const _CustomerProfileBody({required this.customer});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderCard(customer: customer),
              const SizedBox(height: 16),
              _ContactCard(customer: customer),
              const SizedBox(height: 16),
              if (customer.contactPersonName != null &&
                  customer.contactPersonName!.isNotEmpty) ...[
                _ContactPersonCard(customer: customer),
                const SizedBox(height: 16),
              ],
              if (customer.website != null && customer.website!.isNotEmpty ||
                  customer.socialMedia.isNotEmpty) ...[
                _SocialCard(customer: customer),
                const SizedBox(height: 16),
              ],
              _ShippingCard(customer: customer),
              const SizedBox(height: 16),
              if (_hasLegalData(customer)) ...[
                _LegalCard(customer: customer),
                const SizedBox(height: 16),
              ],
              if (customer.notes != null && customer.notes!.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'notes'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 24),
                        Text(customer.notes!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                onPressed: () =>
                    context.push('/sales/customers/${customer.id}/edit'),
                icon: const Icon(Icons.edit),
                label: Text('edit_customer'.tr()),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasLegalData(CustomerModel c) =>
      (c.taxNumber != null && c.taxNumber!.isNotEmpty) ||
      (c.commercialRegister != null && c.commercialRegister!.isNotEmpty) ||
      (c.vatNumber != null && c.vatNumber!.isNotEmpty);
}

// ============================================
// Header Card
// ============================================
class _HeaderCard extends StatelessWidget {
  final CustomerModel customer;
  const _HeaderCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
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
                    customer.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (customer.legalName != null &&
                      customer.legalName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      customer.legalName!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        customer.customerCode ?? '-',
                        style: const TextStyle(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _TypeBadge(type: customer.customerType),
                    ],
                  ),
                  if (customer.rating > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < customer.rating ? Icons.star : Icons.star_border,
                          color: AppColors.secondary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                  if (customer.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: customer.tags
                          .map((t) => Chip(
                                label: Text(
                                  t,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// Contact Card
// ============================================
class _ContactCard extends StatelessWidget {
  final CustomerModel customer;
  const _ContactCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    final hasPhones = customer.phones.isNotEmpty;
    final hasEmails = customer.emails.isNotEmpty;
    if (!hasPhones && !hasEmails) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'customer_contact_info'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            if (hasPhones) ...[
              Row(
                children: [
                  const Icon(Icons.phone_outlined,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'phones'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...customer.phones.map((p) => _PhoneTile(phone: p)),
            ],
            if (hasPhones && hasEmails) const SizedBox(height: 12),
            if (hasEmails) ...[
              Row(
                children: [
                  const Icon(Icons.email_outlined,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'emails'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...customer.emails.map((e) => _EmailTile(email: e)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhoneTile extends StatelessWidget {
  final CustomerPhone phone;
  const _PhoneTile({required this.phone});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        phone.isPrimary ? Icons.star : Icons.phone,
        color: phone.isPrimary ? AppColors.secondary : null,
        size: 18,
      ),
      title: Text(phone.number),
      subtitle: Text(phone.label.tr()),
      trailing: IconButton(
        icon: const Icon(Icons.call, size: 18),
        onPressed: () => _launch('tel:${phone.number}'),
      ),
    );
  }
}

class _EmailTile extends StatelessWidget {
  final CustomerEmail email;
  const _EmailTile({required this.email});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        email.isPrimary ? Icons.star : Icons.email,
        color: email.isPrimary ? AppColors.secondary : null,
        size: 18,
      ),
      title: Text(email.email),
      subtitle: Text(email.label.tr()),
      trailing: IconButton(
        icon: const Icon(Icons.mail_outline, size: 18),
        onPressed: () => _launch('mailto:${email.email}'),
      ),
    );
  }
}

// ============================================
// Contact Person Card
// ============================================
class _ContactPersonCard extends StatelessWidget {
  final CustomerModel customer;
  const _ContactPersonCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'contact_person'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            _InfoRow(
                label: 'contact_person_name'.tr(),
                value: customer.contactPersonName),
            _InfoRow(
                label: 'contact_person_title'.tr(),
                value: customer.contactPersonTitle),
            _InfoRow(label: 'phone'.tr(), value: customer.contactPersonPhone),
            _InfoRow(label: 'email'.tr(), value: customer.contactPersonEmail),
          ],
        ),
      ),
    );
  }
}

// ============================================
// Social Card
// ============================================
class _SocialCard extends StatelessWidget {
  final CustomerModel customer;
  const _SocialCard({required this.customer});

  static const _icons = {
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

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'customer_social_media'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            if (customer.website != null && customer.website!.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.language,
                    size: 18, color: AppColors.primary),
                title: Text(customer.website!),
                subtitle: Text('website'.tr()),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () => _launch(_normalizeUrl(customer.website!)),
                ),
              ),
            ...customer.socialMedia.entries.map((entry) {
              final key = entry.key;
              final value = entry.value;
              if (value.isEmpty) return const SizedBox.shrink();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  _icons[key] ?? Icons.link,
                  size: 18,
                  color: AppColors.primary,
                ),
                title: Text(value),
                subtitle: Text('social_$key'.tr()),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () => _launch(_socialUrl(key, value)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _normalizeUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://$url';
  }

  String _socialUrl(String key, String value) {
    if (value.startsWith('http')) return value;
    // لو رقم (whatsapp/telegram) ممكن نستخدم wa.me أو t.me
    if (key == 'whatsapp') {
      return 'https://wa.me/${value.replaceAll(RegExp(r'[^0-9]'), '')}';
    }
    if (key == 'telegram') {
      final handle = value.replaceAll('@', '');
      return 'https://t.me/$handle';
    }
    return 'https://$value';
  }
}

// ============================================
// Shipping Card
// ============================================
class _ShippingCard extends StatelessWidget {
  final CustomerModel customer;
  const _ShippingCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'customer_shipping'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            _InfoRow(label: 'country'.tr(), value: customer.country),
            _InfoRow(label: 'city'.tr(), value: customer.city),
            _InfoRow(label: 'postal_code'.tr(), value: customer.postalCode),
            _InfoRow(label: 'full_address'.tr(), value: customer.fullAddress),
            _InfoRow(
                label: 'shipping_address'.tr(),
                value: customer.shippingAddress),
            _InfoRow(
                label: 'preferred_port'.tr(), value: customer.preferredPort),
            _InfoRow(label: 'currency'.tr(), value: customer.currency),
            _InfoRow(
                label: 'payment_terms'.tr(),
                value: customer.paymentTerms?.tr()),
            _InfoRow(label: 'incoterms'.tr(), value: customer.incoterms),
            _InfoRow(
                label: 'credit_limit'.tr(),
                value: customer.creditLimit.toStringAsFixed(2)),
          ],
        ),
      ),
    );
  }
}

// ============================================
// Legal Card
// ============================================
class _LegalCard extends StatelessWidget {
  final CustomerModel customer;
  const _LegalCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'customer_legal'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            _InfoRow(label: 'tax_number'.tr(), value: customer.taxNumber),
            _InfoRow(
                label: 'commercial_register'.tr(),
                value: customer.commercialRegister),
            _InfoRow(label: 'vat_number'.tr(), value: customer.vatNumber),
          ],
        ),
      ),
    );
  }
}

// ============================================
// Type Badge
// ============================================
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  Color get _color {
    switch (type) {
      case 'company':
        return AppColors.info;
      case 'distributor':
        return AppColors.secondary;
      case 'agent':
        return AppColors.warning;
      case 'government':
        return AppColors.primary;
      default:
        return AppColors.textSecondaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'type_$type'.tr(),
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ============================================
// Info Row
// ============================================
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

// ============================================
// Launcher Helper
// ============================================
Future<void> _launch(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    debugPrint('Could not launch $url');
  }
}
