class TrialBalanceRow {
  final String accountId;
  final String accountCode;
  final String accountName;
  final String accountType;
  final double totalDebit;
  final double totalCredit;
  final double balance;

  const TrialBalanceRow({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    this.totalDebit = 0,
    this.totalCredit = 0,
    this.balance = 0,
  });

  factory TrialBalanceRow.fromJson(Map<String, dynamic> json) {
    return TrialBalanceRow(
      accountId: json['account_id'] as String,
      accountCode: json['account_code'] as String,
      accountName: json['account_name'] as String,
      accountType: json['account_type'] as String,
      totalDebit: (json['total_debit'] as num?)?.toDouble() ?? 0,
      totalCredit: (json['total_credit'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
    );
  }

  bool get hasActivity => totalDebit > 0 || totalCredit > 0;
}

class LedgerRow {
  final String entryId;
  final String entryNumber;
  final DateTime entryDate;
  final String? description;
  final String? lineDescription;
  final double debit;
  final double credit;
  final double runningBalance;

  const LedgerRow({
    required this.entryId,
    required this.entryNumber,
    required this.entryDate,
    this.description,
    this.lineDescription,
    this.debit = 0,
    this.credit = 0,
    this.runningBalance = 0,
  });

  factory LedgerRow.fromJson(Map<String, dynamic> json) {
    return LedgerRow(
      entryId: json['entry_id'] as String,
      entryNumber: json['entry_number'] as String,
      entryDate: DateTime.parse(json['entry_date'] as String),
      description: json['description'] as String?,
      lineDescription: json['line_description'] as String?,
      debit: (json['debit'] as num?)?.toDouble() ?? 0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0,
      runningBalance: (json['running_balance'] as num?)?.toDouble() ?? 0,
    );
  }
}
