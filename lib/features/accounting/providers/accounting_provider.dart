import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/account_model.dart';
import '../data/models/financial_statement_model.dart';
import '../data/models/journal_entry_model.dart';
import '../data/models/trial_balance_model.dart';
import '../data/services/accounting_service.dart';

final accountingServiceProvider = Provider<AccountingService>((ref) {
  return AccountingService();
});

// ============================================
// ACCOUNTS
// ============================================
final accountsListProvider =
    FutureProvider.autoDispose<List<AccountModel>>((ref) async {
  final service = ref.watch(accountingServiceProvider);
  return service.getAccounts();
});

// ============================================
// JOURNAL ENTRIES
// ============================================
class JournalFilter {
  final String? status;
  final DateTime? fromDate;
  final DateTime? toDate;

  const JournalFilter({this.status, this.fromDate, this.toDate});

  JournalFilter copyWith({
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearStatus = false,
    bool clearDates = false,
  }) {
    return JournalFilter(
      status: clearStatus ? null : (status ?? this.status),
      fromDate: clearDates ? null : (fromDate ?? this.fromDate),
      toDate: clearDates ? null : (toDate ?? this.toDate),
    );
  }
}

final journalFilterProvider =
    StateProvider<JournalFilter>((ref) => const JournalFilter());

final journalEntriesListProvider =
    FutureProvider.autoDispose<List<JournalEntryModel>>((ref) async {
  final filter = ref.watch(journalFilterProvider);
  final service = ref.watch(accountingServiceProvider);
  return service.getJournalEntries(
    status: filter.status,
    fromDate: filter.fromDate,
    toDate: filter.toDate,
  );
});

final journalEntryByIdProvider = FutureProvider.autoDispose
    .family<JournalEntryModel?, String>((ref, id) async {
  final service = ref.watch(accountingServiceProvider);
  return service.getJournalEntryById(id);
});

// ============================================
// REPORTS FILTER
// ============================================
class ReportFilter {
  final DateTime? fromDate;
  final DateTime? toDate;

  const ReportFilter({this.fromDate, this.toDate});

  ReportFilter copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    bool clearDates = false,
  }) {
    return ReportFilter(
      fromDate: clearDates ? null : (fromDate ?? this.fromDate),
      toDate: clearDates ? null : (toDate ?? this.toDate),
    );
  }
}

final reportFilterProvider =
    StateProvider<ReportFilter>((ref) => const ReportFilter());

// ============================================
// TRIAL BALANCE + GENERAL LEDGER
// ============================================
final trialBalanceProvider =
    FutureProvider.autoDispose<List<TrialBalanceRow>>((ref) async {
  final filter = ref.watch(reportFilterProvider);
  final service = ref.watch(accountingServiceProvider);
  return service.getTrialBalance(
    fromDate: filter.fromDate,
    toDate: filter.toDate,
  );
});

final ledgerRowsProvider = FutureProvider.autoDispose
    .family<List<LedgerRow>, String>((ref, accountId) async {
  final filter = ref.watch(reportFilterProvider);
  final service = ref.watch(accountingServiceProvider);
  return service.getGeneralLedger(
    accountId,
    fromDate: filter.fromDate,
    toDate: filter.toDate,
  );
});

// ============================================
// FINANCIAL STATEMENTS
// ============================================
final incomeStatementProvider =
    FutureProvider.autoDispose<IncomeStatementModel>((ref) async {
  final filter = ref.watch(reportFilterProvider);
  final service = ref.watch(accountingServiceProvider);
  return service.getIncomeStatement(
    fromDate: filter.fromDate,
    toDate: filter.toDate,
  );
});

final balanceSheetProvider =
    FutureProvider.autoDispose<BalanceSheetModel>((ref) async {
  final filter = ref.watch(reportFilterProvider);
  final service = ref.watch(accountingServiceProvider);
  return service.getBalanceSheet(asOfDate: filter.toDate);
});
