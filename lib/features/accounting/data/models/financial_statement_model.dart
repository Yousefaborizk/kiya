class StatementRow {
  final String accountId;
  final String accountCode;
  final String accountName;
  final String accountType;
  final double amount;

  const StatementRow({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    this.amount = 0,
  });

  factory StatementRow.fromJson(Map<String, dynamic> json) {
    return StatementRow(
      accountId: json['account_id'] as String,
      accountCode: json['account_code'] as String,
      accountName: json['account_name'] as String,
      accountType: json['account_type'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  bool get hasActivity => amount.abs() > 0.001;
}

class IncomeStatementModel {
  final List<StatementRow> rows;
  final double totalRevenue;
  final double totalExpenses;
  final double netProfit;

  const IncomeStatementModel({
    this.rows = const [],
    this.totalRevenue = 0,
    this.totalExpenses = 0,
    this.netProfit = 0,
  });

  factory IncomeStatementModel.fromRows(List<StatementRow> rows) {
    double revenue = 0;
    double expenses = 0;
    for (final r in rows) {
      if (r.accountType == 'revenue') revenue += r.amount;
      if (r.accountType == 'expense') expenses += r.amount;
    }
    return IncomeStatementModel(
      rows: rows,
      totalRevenue: revenue,
      totalExpenses: expenses,
      netProfit: revenue - expenses,
    );
  }

  List<StatementRow> get revenueRows =>
      rows.where((r) => r.accountType == 'revenue').toList();

  List<StatementRow> get expenseRows =>
      rows.where((r) => r.accountType == 'expense').toList();
}

class BalanceSheetModel {
  final List<StatementRow> rows;
  final double totalAssets;
  final double totalLiabilities;
  final double totalEquity;
  final double netProfit;

  const BalanceSheetModel({
    this.rows = const [],
    this.totalAssets = 0,
    this.totalLiabilities = 0,
    this.totalEquity = 0,
    this.netProfit = 0,
  });

  factory BalanceSheetModel.fromRows(
    List<StatementRow> rows, {
    double netProfit = 0,
  }) {
    double assets = 0;
    double liabilities = 0;
    double equity = 0;
    for (final r in rows) {
      switch (r.accountType) {
        case 'asset':
          assets += r.amount;
          break;
        case 'liability':
          liabilities += r.amount;
          break;
        case 'equity':
          equity += r.amount;
          break;
      }
    }
    return BalanceSheetModel(
      rows: rows,
      totalAssets: assets,
      totalLiabilities: liabilities,
      totalEquity: equity + netProfit, // صافي الربح يدخل حقوق الملكية
      netProfit: netProfit,
    );
  }

  List<StatementRow> get assetRows =>
      rows.where((r) => r.accountType == 'asset').toList();

  List<StatementRow> get liabilityRows =>
      rows.where((r) => r.accountType == 'liability').toList();

  List<StatementRow> get equityRows =>
      rows.where((r) => r.accountType == 'equity').toList();

  double get totalLiabilitiesAndEquity => totalLiabilities + totalEquity;
  double get difference => totalAssets - totalLiabilitiesAndEquity;
  bool get isBalanced => difference.abs() < 0.01;
}
