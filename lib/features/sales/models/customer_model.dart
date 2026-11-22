// ============================================
// CustomerPhone — رقم تواصل واحد
// ============================================
class CustomerPhone {
  final String label; // mobile, landline, whatsapp, fax
  final String number;
  final bool isPrimary;

  const CustomerPhone({
    required this.label,
    required this.number,
    this.isPrimary = false,
  });

  factory CustomerPhone.fromJson(Map<String, dynamic> json) {
    return CustomerPhone(
      label: json['label'] as String? ?? 'mobile',
      number: json['number'] as String? ?? '',
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'number': number,
        'is_primary': isPrimary,
      };

  CustomerPhone copyWith({
    String? label,
    String? number,
    bool? isPrimary,
  }) {
    return CustomerPhone(
      label: label ?? this.label,
      number: number ?? this.number,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

// ============================================
// CustomerEmail — إيميل واحد
// ============================================
class CustomerEmail {
  final String label; // sales, info, support, personal
  final String email;
  final bool isPrimary;

  const CustomerEmail({
    required this.label,
    required this.email,
    this.isPrimary = false,
  });

  factory CustomerEmail.fromJson(Map<String, dynamic> json) {
    return CustomerEmail(
      label: json['label'] as String? ?? 'info',
      email: json['email'] as String? ?? '',
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'email': email,
        'is_primary': isPrimary,
      };

  CustomerEmail copyWith({
    String? label,
    String? email,
    bool? isPrimary,
  }) {
    return CustomerEmail(
      label: label ?? this.label,
      email: email ?? this.email,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

// ============================================
// CustomerModel — العميل الكامل
// ============================================
class CustomerModel {
  // ── الحقول القديمة ──────────────────────────
  final String id;
  final String? customerCode;
  final String name;
  final String? phone; // للتوافق — الأفضل phones
  final String? email; // للتوافق — الأفضل emails
  final String? address;
  final String? notes;
  final bool isActive;
  final String? branchId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── الحقول الجديدة ──────────────────────────
  final String? legalName;
  final String
      customerType; // individual, company, distributor, agent, government
  final List<CustomerPhone> phones;
  final List<CustomerEmail> emails;

  final String? contactPersonName;
  final String? contactPersonTitle;
  final String? contactPersonPhone;
  final String? contactPersonEmail;

  final String? website;
  final Map<String, String> socialMedia;

  final String? country;
  final String? city;
  final String? postalCode;
  final String? fullAddress;

  final String? taxNumber;
  final String? commercialRegister;
  final String? vatNumber;

  final String currency;
  final String? paymentTerms;
  final double creditLimit;
  final String? incoterms;
  final String? preferredPort;
  final String? shippingAddress;

  final int rating;
  final List<String> tags;

  const CustomerModel({
    required this.id,
    this.customerCode,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.isActive = true,
    this.branchId,
    required this.createdAt,
    required this.updatedAt,
    // جديدة
    this.legalName,
    this.customerType = 'individual',
    this.phones = const [],
    this.emails = const [],
    this.contactPersonName,
    this.contactPersonTitle,
    this.contactPersonPhone,
    this.contactPersonEmail,
    this.website,
    this.socialMedia = const {},
    this.country,
    this.city,
    this.postalCode,
    this.fullAddress,
    this.taxNumber,
    this.commercialRegister,
    this.vatNumber,
    this.currency = 'EGP',
    this.paymentTerms,
    this.creditLimit = 0,
    this.incoterms,
    this.preferredPort,
    this.shippingAddress,
    this.rating = 0,
    this.tags = const [],
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String,
      customerCode: json['customer_code'] as String?,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      branchId: json['branch_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // جديدة
      legalName: json['legal_name'] as String?,
      customerType: json['customer_type'] as String? ?? 'individual',
      phones: (json['phones'] as List?)
              ?.map((e) => CustomerPhone.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      emails: (json['emails'] as List?)
              ?.map((e) => CustomerEmail.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      contactPersonName: json['contact_person_name'] as String?,
      contactPersonTitle: json['contact_person_title'] as String?,
      contactPersonPhone: json['contact_person_phone'] as String?,
      contactPersonEmail: json['contact_person_email'] as String?,
      website: json['website'] as String?,
      socialMedia: (json['social_media'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v?.toString() ?? '')) ??
          const {},
      country: json['country'] as String?,
      city: json['city'] as String?,
      postalCode: json['postal_code'] as String?,
      fullAddress: json['full_address'] as String?,
      taxNumber: json['tax_number'] as String?,
      commercialRegister: json['commercial_register'] as String?,
      vatNumber: json['vat_number'] as String?,
      currency: json['currency'] as String? ?? 'EGP',
      paymentTerms: json['payment_terms'] as String?,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
      incoterms: json['incoterms'] as String?,
      preferredPort: json['preferred_port'] as String?,
      shippingAddress: json['shipping_address'] as String?,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    // مزامنة phone/email القديمة مع أول عنصر primary
    String? resolvedPhone = phone;
    if (phones.isNotEmpty) {
      final primary = phones.firstWhere(
        (p) => p.isPrimary,
        orElse: () => phones.first,
      );
      if (primary.number.isNotEmpty) resolvedPhone = primary.number;
    }

    String? resolvedEmail = email;
    if (emails.isNotEmpty) {
      final primary = emails.firstWhere(
        (e) => e.isPrimary,
        orElse: () => emails.first,
      );
      if (primary.email.isNotEmpty) resolvedEmail = primary.email;
    }

    return {
      'customer_code': customerCode,
      'name': name,
      'phone': resolvedPhone,
      'email': resolvedEmail,
      'address': address,
      'notes': notes,
      'is_active': isActive,
      'branch_id': branchId,
      // جديدة
      'legal_name': legalName,
      'customer_type': customerType,
      'phones': phones.map((e) => e.toJson()).toList(),
      'emails': emails.map((e) => e.toJson()).toList(),
      'contact_person_name': contactPersonName,
      'contact_person_title': contactPersonTitle,
      'contact_person_phone': contactPersonPhone,
      'contact_person_email': contactPersonEmail,
      'website': website,
      'social_media': socialMedia,
      'country': country,
      'city': city,
      'postal_code': postalCode,
      'full_address': fullAddress,
      'tax_number': taxNumber,
      'commercial_register': commercialRegister,
      'vat_number': vatNumber,
      'currency': currency,
      'payment_terms': paymentTerms,
      'credit_limit': creditLimit,
      'incoterms': incoterms,
      'preferred_port': preferredPort,
      'shipping_address': shippingAddress,
      'rating': rating,
      'tags': tags,
    };
  }

  CustomerModel copyWith({
    String? id,
    String? customerCode,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    bool? isActive,
    String? branchId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? legalName,
    String? customerType,
    List<CustomerPhone>? phones,
    List<CustomerEmail>? emails,
    String? contactPersonName,
    String? contactPersonTitle,
    String? contactPersonPhone,
    String? contactPersonEmail,
    String? website,
    Map<String, String>? socialMedia,
    String? country,
    String? city,
    String? postalCode,
    String? fullAddress,
    String? taxNumber,
    String? commercialRegister,
    String? vatNumber,
    String? currency,
    String? paymentTerms,
    double? creditLimit,
    String? incoterms,
    String? preferredPort,
    String? shippingAddress,
    int? rating,
    List<String>? tags,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      customerCode: customerCode ?? this.customerCode,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      branchId: branchId ?? this.branchId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      legalName: legalName ?? this.legalName,
      customerType: customerType ?? this.customerType,
      phones: phones ?? this.phones,
      emails: emails ?? this.emails,
      contactPersonName: contactPersonName ?? this.contactPersonName,
      contactPersonTitle: contactPersonTitle ?? this.contactPersonTitle,
      contactPersonPhone: contactPersonPhone ?? this.contactPersonPhone,
      contactPersonEmail: contactPersonEmail ?? this.contactPersonEmail,
      website: website ?? this.website,
      socialMedia: socialMedia ?? this.socialMedia,
      country: country ?? this.country,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      fullAddress: fullAddress ?? this.fullAddress,
      taxNumber: taxNumber ?? this.taxNumber,
      commercialRegister: commercialRegister ?? this.commercialRegister,
      vatNumber: vatNumber ?? this.vatNumber,
      currency: currency ?? this.currency,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      creditLimit: creditLimit ?? this.creditLimit,
      incoterms: incoterms ?? this.incoterms,
      preferredPort: preferredPort ?? this.preferredPort,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      rating: rating ?? this.rating,
      tags: tags ?? this.tags,
    );
  }
}
