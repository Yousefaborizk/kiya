import '../../../sales/models/customer_model.dart';

// ============================================
// Statement Line — سطر واحد في الكشف
// ============================================
enum StatementLineType { invoice, payment }

class CustomerStatementLine {
  final DateTime date;
  final StatementLineType type;
  final String documentNumber;
  final String? description;
  final double debit; // فاتورة → العميل مديون أكثر
  final double credit; // دفعة → العميل مديون أقل
  final double runningBalance;
  final String? referenceId;

  const CustomerStatementLine({
    required this.date,
    required this.type,
    required this.documentNumber,
    this.description,
    this.debit = 0,
    this.credit = 0,
    this.runningBalance = 0,
    this.referenceId,
  });

  bool get isDebit => debit > 0.001;
  bool get isCredit => credit > 0.001;
}

// ============================================
// Statement Model — الكشف الكامل
// ============================================
class CustomerStatementModel {
  final CustomerModel customer;
  final DateTime fromDate;
  final DateTime toDate;

  final double openingBalance;
  final double totalDebits;
  final double totalCredits;
  final double closingBalance;

  final int invoiceCount;
  final int paymentCount;

  final List<CustomerStatementLine> lines;

  const CustomerStatementModel({
    required this.customer,
    required this.fromDate,
    required this.toDate,
    this.openingBalance = 0,
    this.totalDebits = 0,
    this.totalCredits = 0,
    this.closingBalance = 0,
    this.invoiceCount = 0,
    this.paymentCount = 0,
    this.lines = const [],
  });

  bool get hasActivity => lines.isNotEmpty || openingBalance.abs() > 0.001;
}
