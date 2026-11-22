// =====================================================
// employee_model.dart
// =====================================================
// Key behaviors:
//   • null-safe fromJson (DB columns can be NULL)
//   • toCreateJson() — always provides a unique employee_code
//     to avoid the classic DEFAULT 'PENDING' + UNIQUE collision
//   • generateCode() — client-side fallback (server trigger also exists)
// =====================================================

class EmployeeModel {
  final String id;
  final String? userId;
  final String employeeCode;
  final String fullName;
  final String? nationalId;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime? birthDate;
  final String? gender;
  final String? maritalStatus;
  final String? departmentId;
  final String? jobTitleId;
  final DateTime? hireDate;
  final String? contractType;
  final String? branchId;
  final String status;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployeeModel({
    required this.id,
    this.userId,
    required this.employeeCode,
    required this.fullName,
    this.nationalId,
    this.phone,
    this.email,
    this.address,
    this.birthDate,
    this.gender,
    this.maritalStatus,
    this.departmentId,
    this.jobTitleId,
    this.hireDate,
    this.contractType,
    this.branchId,
    this.status = 'active',
    this.notes,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True for rows that haven't been persisted yet (empty code).
  bool get isDraft => employeeCode.trim().isEmpty;

  // ============================================
  // fromJson
  // ============================================
  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'] as String,
      userId: _asNullableString(json['user_id']),
      employeeCode: (json['employee_code'] as String?)?.trim() ?? '',
      fullName: (json['full_name'] as String?)?.trim() ?? '',
      nationalId: _asNullableString(json['national_id']),
      phone: _asNullableString(json['phone']),
      email: _asNullableString(json['email']),
      address: _asNullableString(json['address']),
      birthDate: _asNullableDate(json['birth_date']),
      gender: _asNullableString(json['gender']),
      maritalStatus: _asNullableString(json['marital_status']),
      departmentId: _asNullableString(json['department_id']),
      jobTitleId: _asNullableString(json['job_title_id']),
      hireDate: _asNullableDate(json['hire_date']),
      contractType: _asNullableString(json['contract_type']),
      branchId: _asNullableString(json['branch_id']),
      status: (json['status'] as String?) ?? 'active',
      notes: _asNullableString(json['notes']),
      createdBy: _asNullableString(json['created_by']),
      createdAt: _asRequiredDate(json['created_at']),
      updatedAt: _asRequiredDate(json['updated_at']),
    );
  }

  // ============================================
  // toJson — generic serialization
  // ============================================
  // Omits employee_code when empty so the DB can supply it.
  // ⚠️ Prefer toCreateJson() for INSERT to guarantee a code.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'user_id': userId,
      'full_name': fullName.trim(),
      'national_id': _trimOrNull(nationalId),
      'phone': _trimOrNull(phone),
      'email': _trimOrNull(email),
      'address': _trimOrNull(address),
      'birth_date': _formatDate(birthDate),
      'gender': _trimOrNull(gender),
      'marital_status': _trimOrNull(maritalStatus),
      'department_id': departmentId,
      'job_title_id': jobTitleId,
      'hire_date': _formatDate(hireDate),
      'contract_type': _trimOrNull(contractType),
      'branch_id': branchId,
      'status': status,
      'notes': _trimOrNull(notes),
    };

    if (employeeCode.trim().isNotEmpty) {
      map['employee_code'] = employeeCode.trim();
    }

    return map;
  }

  // ============================================
  // toCreateJson — safe INSERT payload
  // ============================================
  // Always provides employee_code. If the caller didn't set
  // one, generates a client-side unique code. This avoids the
  // DEFAULT 'PENDING' + UNIQUE collision on the second insert.
  //
  // The DB also has a trigger that generates codes — whichever
  // fires first wins, and both produce unique codes.
  Map<String, dynamic> toCreateJson() {
    final map = toJson();
    map['employee_code'] = employeeCode.trim().isNotEmpty
        ? employeeCode.trim()
        : EmployeeModel.generateCode();
    return map;
  }

  // ============================================
  // Code generator
  // ============================================
  static String generateCode({String prefix = 'EMP'}) {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final ms = now.millisecondsSinceEpoch.toString();
    final tail = ms.substring(ms.length - 6);
    return '$prefix-$y$m$d-$tail';
  }

  // ============================================
  // copyWith
  // ============================================
  EmployeeModel copyWith({
    String? id,
    String? userId,
    String? employeeCode,
    String? fullName,
    String? nationalId,
    String? phone,
    String? email,
    String? address,
    DateTime? birthDate,
    String? gender,
    String? maritalStatus,
    String? departmentId,
    String? jobTitleId,
    DateTime? hireDate,
    String? contractType,
    String? branchId,
    String? status,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      employeeCode: employeeCode ?? this.employeeCode,
      fullName: fullName ?? this.fullName,
      nationalId: nationalId ?? this.nationalId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      departmentId: departmentId ?? this.departmentId,
      jobTitleId: jobTitleId ?? this.jobTitleId,
      hireDate: hireDate ?? this.hireDate,
      contractType: contractType ?? this.contractType,
      branchId: branchId ?? this.branchId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmployeeModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, updatedAt);

  @override
  String toString() =>
      'EmployeeModel(id: $id, code: $employeeCode, name: $fullName)';
}

// ============================================
// Helpers
// ============================================
String? _asNullableString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _asNullableDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

DateTime _asRequiredDate(dynamic v) {
  if (v is DateTime) return v;
  if (v is String) {
    final d = DateTime.tryParse(v);
    if (d != null) return d;
  }
  return DateTime.now().toUtc();
}

String? _trimOrNull(String? s) {
  if (s == null) return null;
  final t = s.trim();
  return t.isEmpty ? null : t;
}

String? _formatDate(DateTime? d) => d?.toIso8601String().split('T').first;
