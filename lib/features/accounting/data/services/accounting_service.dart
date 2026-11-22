import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_model.dart';
import '../models/financial_statement_model.dart';
import '../models/journal_entry_model.dart';
import '../models/trial_balance_model.dart';

class AccountingService {
  final SupabaseClient _client = Supabase.instance.client;

  // ============================================
  // ACCOUNTS (Chart of Accounts)
  // ============================================
  Future<List<AccountModel>> getAccounts({bool? isActive}) async {
    var query = _client.from('accounts').select();
    if (isActive != null) query = query.eq('is_active', isActive);
    final data = await query.order('code');
    return (data as List)
        .map((e) => AccountModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AccountModel?> getAccountById(String id) async {
    final data =
        await _client.from('accounts').select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return AccountModel.fromJson(data);
  }

  Future<AccountModel> createAccount(AccountModel account) async {
    try {
      final payload = account.toJson();
      debugPrint('CREATE ACCOUNT: $payload');
      final data =
          await _client.from('accounts').insert(payload).select().single();
      return AccountModel.fromJson(data);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('كود الحساب مستخدم بالفعل. اختر كوداً آخر.');
      }
      rethrow;
    }
  }

  Future<AccountModel> updateAccount(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final data = await _client
        .from('accounts')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return AccountModel.fromJson(data);
  }

  /// Soft delete — لا نحذف لأن ممكن يكون له قيود
  Future<void> deleteAccount(String id) async {
    await _client.from('accounts').update({'is_active': false}).eq('id', id);
  }

  /// استرجاع الحساب
  Future<void> restoreAccount(String id) async {
    await _client.from('accounts').update({'is_active': true}).eq('id', id);
  }

  // ============================================
  // JOURNAL ENTRIES
  // ============================================
  Future<List<JournalEntryModel>> getJournalEntries({
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var query = _client.from('journal_entries').select();
    if (status != null) query = query.eq('status', status);
    if (fromDate != null) {
      query =
          query.gte('entry_date', fromDate.toIso8601String().split('T').first);
    }
    if (toDate != null) {
      query =
          query.lte('entry_date', toDate.toIso8601String().split('T').first);
    }
    final data = await query
        .order('entry_date', ascending: false)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => JournalEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<JournalEntryModel?> getJournalEntryById(String id) async {
    final data = await _client
        .from('journal_entries')
        .select('*, journal_entry_lines(*, accounts(code, name))')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return JournalEntryModel.fromJson(data);
  }

  /// إنشاء قيد كامل (header + lines) في transaction واحدة
  Future<String> createJournalEntry(
    JournalEntryModel header,
    List<JournalEntryLineModel> lines,
  ) async {
    try {
      final headerPayload = header.toJson();
      final linesPayload = lines.map((l) => l.toJson()).toList();

      debugPrint('JE HEADER: $headerPayload');
      debugPrint('JE LINES: ${linesPayload.length} lines');

      final result = await _client.rpc('create_journal_entry', params: {
        'p_header': headerPayload,
        'p_lines': linesPayload,
      });
      return result as String;
    } on PostgrestException catch (e) {
      debugPrint('CREATE JE ERROR: ${e.code} - ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('CREATE JE UNKNOWN ERROR: $e');
      rethrow;
    }
  }

  /// ترحيل القيد (draft → posted)
  Future<void> postJournalEntry(String id) async {
    try {
      await _client.rpc('post_journal_entry', params: {'p_entry_id': id});
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// إلغاء القيد (posted → voided)
  Future<void> voidJournalEntry(String id) async {
    try {
      await _client.rpc('void_journal_entry', params: {'p_entry_id': id});
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// حذف قيد (draft فقط)
  Future<void> deleteDraftJournalEntry(String id) async {
    await _client
        .from('journal_entries')
        .delete()
        .eq('id', id)
        .eq('status', 'draft');
  }

  // ============================================
  // REPORTS
  // ============================================
  Future<List<TrialBalanceRow>> getTrialBalance({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final result = await _client.rpc('get_trial_balance', params: {
        'p_from_date': fromDate?.toIso8601String().split('T').first,
        'p_to_date': toDate?.toIso8601String().split('T').first,
      });
      return (result as List)
          .map((e) => TrialBalanceRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('TRIAL BALANCE ERROR: ${e.code} - ${e.message}');
      throw Exception(e.message);
    }
  }

  Future<List<LedgerRow>> getGeneralLedger(
    String accountId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final result = await _client.rpc('get_general_ledger', params: {
        'p_account_id': accountId,
        'p_from_date': fromDate?.toIso8601String().split('T').first,
        'p_to_date': toDate?.toIso8601String().split('T').first,
      });
      return (result as List)
          .map((e) => LedgerRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('GENERAL LEDGER ERROR: ${e.code} - ${e.message}');
      throw Exception(e.message);
    }
  }

  // ============================================
  // FINANCIAL STATEMENTS
  // ============================================
  Future<IncomeStatementModel> getIncomeStatement({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final result = await _client.rpc('get_income_statement', params: {
        'p_from_date': fromDate?.toIso8601String().split('T').first,
        'p_to_date': toDate?.toIso8601String().split('T').first,
      });
      final rows = (result as List)
          .map((e) => StatementRow.fromJson(e as Map<String, dynamic>))
          .toList();
      return IncomeStatementModel.fromRows(rows);
    } on PostgrestException catch (e) {
      debugPrint('INCOME STATEMENT ERROR: ${e.code} - ${e.message}');
      throw Exception(e.message);
    }
  }

  Future<BalanceSheetModel> getBalanceSheet({
    DateTime? asOfDate,
  }) async {
    try {
      // 1) بيانات الميزانية
      final result = await _client.rpc('get_balance_sheet', params: {
        'p_as_of_date': asOfDate?.toIso8601String().split('T').first,
      });
      final rows = (result as List)
          .map((e) => StatementRow.fromJson(e as Map<String, dynamic>))
          .toList();

      // 2) صافي الربح (يدخل حقوق الملكية)
      final profitResult = await _client.rpc('get_net_profit', params: {
        'p_from_date': null,
        'p_to_date': asOfDate?.toIso8601String().split('T').first,
      });
      final netProfit = profitResult is num ? profitResult.toDouble() : 0.0;

      return BalanceSheetModel.fromRows(rows, netProfit: netProfit);
    } on PostgrestException catch (e) {
      debugPrint('BALANCE SHEET ERROR: ${e.code} - ${e.message}');
      throw Exception(e.message);
    }
  }
}
