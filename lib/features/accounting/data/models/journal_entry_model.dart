class JournalEntryLineModel {
  final String id;
  final String entryId;
  final String accountId;
  final String? description;
  final double debit;
  final double credit;
  final int lineOrder;
  final DateTime createdAt;

  // للعرض
  final String? accountCode;
  final String? accountName;

  const JournalEntryLineModel({
    required this.id,
    required this.entryId,
    required this.accountId,
    this.description,
    this.debit = 0,
    this.credit = 0,
    this.lineOrder = 0,
    required this.createdAt,
    this.accountCode,
    this.accountName,
  });

  factory JournalEntryLineModel.fromJson(Map<String, dynamic> json) {
    return JournalEntryLineModel(
      id: json['id'] as String,
      entryId: json['entry_id'] as String,
      accountId: json['account_id'] as String,
      description: json['description'] as String?,
      debit: (json['debit'] as num?)?.toDouble() ?? 0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0,
      lineOrder: (json['line_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      accountCode: json['accounts'] != null
          ? (json['accounts'] as Map<String, dynamic>)['code'] as String?
          : null,
      accountName: json['accounts'] != null
          ? (json['accounts'] as Map<String, dynamic>)['name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'account_id': accountId,
        'description': description,
        'debit': debit,
        'credit': credit,
        'line_order': lineOrder,
      };

  JournalEntryLineModel copyWith({
    String? id,
    String? entryId,
    String? accountId,
    String? description,
    double? debit,
    double? credit,
    int? lineOrder,
    DateTime? createdAt,
    String? accountCode,
    String? accountName,
  }) {
    return JournalEntryLineModel(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      accountId: accountId ?? this.accountId,
      description: description ?? this.description,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      lineOrder: lineOrder ?? this.lineOrder,
      createdAt: createdAt ?? this.createdAt,
      accountCode: accountCode ?? this.accountCode,
      accountName: accountName ?? this.accountName,
    );
  }
}

class JournalEntryModel {
  final String id;
  final String entryNumber;
  final DateTime entryDate;
  final String description;
  final String? referenceType;
  final String? referenceId;
  final String status; // draft, posted, voided
  final DateTime? postedAt;
  final String? postedBy;
  final String? notes;
  final String? branchId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  final List<JournalEntryLineModel>? lines;

  const JournalEntryModel({
    required this.id,
    required this.entryNumber,
    required this.entryDate,
    required this.description,
    this.referenceType,
    this.referenceId,
    this.status = 'draft',
    this.postedAt,
    this.postedBy,
    this.notes,
    this.branchId,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.lines,
  });

  double get totalDebit => lines?.fold<double>(0, (s, l) => s + l.debit) ?? 0;

  double get totalCredit => lines?.fold<double>(0, (s, l) => s + l.credit) ?? 0;

  bool get isBalanced =>
      (totalDebit - totalCredit).abs() < 0.01 && totalDebit > 0;

  bool get canEdit => status == 'draft';
  bool get canPost => status == 'draft' && isBalanced;
  bool get canVoid => status == 'posted' || status == 'draft';

  factory JournalEntryModel.fromJson(Map<String, dynamic> json) {
    return JournalEntryModel(
      id: json['id'] as String,
      entryNumber: json['entry_number'] as String,
      entryDate: DateTime.parse(json['entry_date'] as String),
      description: json['description'] as String,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      status: json['status'] as String? ?? 'draft',
      postedAt: json['posted_at'] != null
          ? DateTime.parse(json['posted_at'] as String)
          : null,
      postedBy: json['posted_by'] as String?,
      notes: json['notes'] as String?,
      branchId: json['branch_id'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lines: json['journal_entry_lines'] != null
          ? (json['journal_entry_lines'] as List)
              .map((e) =>
                  JournalEntryLineModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'entry_number': entryNumber,
        'entry_date': entryDate.toIso8601String().split('T').first,
        'description': description,
        'reference_type': referenceType,
        'reference_id': referenceId,
        'status': status,
        'notes': notes,
        'branch_id': branchId,
      };

  JournalEntryModel copyWith({
    String? id,
    String? entryNumber,
    DateTime? entryDate,
    String? description,
    String? referenceType,
    String? referenceId,
    String? status,
    DateTime? postedAt,
    String? postedBy,
    String? notes,
    String? branchId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<JournalEntryLineModel>? lines,
  }) {
    return JournalEntryModel(
      id: id ?? this.id,
      entryNumber: entryNumber ?? this.entryNumber,
      entryDate: entryDate ?? this.entryDate,
      description: description ?? this.description,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      status: status ?? this.status,
      postedAt: postedAt ?? this.postedAt,
      postedBy: postedBy ?? this.postedBy,
      notes: notes ?? this.notes,
      branchId: branchId ?? this.branchId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lines: lines ?? this.lines,
    );
  }
}
