import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hunter_models.dart';

class HunterRepository {
  final SupabaseClient _supabase;

  HunterRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  Future<String> startHunt({
    required String industry,
    required List<String> products,
    required List<String> countries,
    String? notes,
    String language = 'en', // ← إضافة اللغة
  }) async {
    final cleanIndustry = industry.trim();
    final cleanProducts = _cleanList(products);
    final cleanCountries = _cleanList(countries);
    final cleanNotes = notes?.trim();

    if (cleanIndustry.length < 3) {
      throw const HunterException(
        'Industry must be at least 3 characters',
        code: 'VALIDATION',
      );
    }
    if (cleanProducts.isEmpty) {
      throw const HunterException(
        'Add at least one product',
        code: 'VALIDATION',
      );
    }
    if (cleanCountries.isEmpty) {
      throw const HunterException(
        'Add at least one target country',
        code: 'VALIDATION',
      );
    }

    final jobId = await _invokeForJobId(
      'hunter-search',
      {
        'industry': cleanIndustry,
        'products': cleanProducts,
        'target_countries': cleanCountries,
        if (cleanNotes != null && cleanNotes.isNotEmpty) 'notes': cleanNotes,
        'language': language, // ← تمرير اللغة للـ Edge Function
      },
    );

    debugPrint('✅ hunter-search returned job_id=$jobId');

    unawaited(_startExtract(jobId));
    return jobId;
  }

  Future<void> _startExtract(String jobId) async {
    try {
      final res = await _supabase.functions.invoke(
        'hunter-extract',
        body: {'job_id': jobId},
      );
      final data = res.data;
      if (data is Map && data['success'] == true) {
        debugPrint('✅ hunter-extract started: ${data['status']}');
      } else {
        debugPrint('⚠️ hunter-extract unexpected response: $data');
      }
    } catch (e) {
      debugPrint(
          '⚠️ hunter-extract invocation failed (job continues via bg): $e');
    }
  }

  Stream<HunterJob> watchJob(String jobId) {
    return _supabase
        .from('hunter_jobs')
        .stream(primaryKey: ['id'])
        .eq('id', jobId)
        .map((rows) {
          if (rows.isEmpty) {
            throw const HunterException('Job not found', code: 'NOT_FOUND');
          }
          return HunterJob.fromJson(rows.first);
        });
  }

  Stream<List<HunterLead>> watchLeads(String jobId) {
    return _supabase
        .from('hunter_leads')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .order('score', ascending: false)
        .map((rows) =>
            rows.map((e) => HunterLead.fromJson(e)).toList(growable: false));
  }

  Future<void> retryJob(String jobId) async {
    await _invokeForJobId('hunter-extract', {'job_id': jobId});
  }

  Future<void> updateLeadStatus(String leadId, String status) async {
    assert(
      const ['new', 'saved', 'ignored', 'contacted'].contains(status),
      'Invalid lead status: $status',
    );
    await _supabase
        .from('hunter_leads')
        .update({'status': status}).eq('id', leadId);
  }

  Future<String> _invokeForJobId(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _supabase.functions.invoke(functionName, body: body);
      final data = res.data;

      if (data is! Map) {
        throw HunterException(
          'Unexpected response from $functionName',
          code: 'INVALID_RESPONSE',
        );
      }

      if (data['success'] != true) {
        throw HunterException(
          (data['error'] ?? 'Request failed').toString(),
          code: 'SERVER_ERROR',
          isRetryable: true,
        );
      }

      final id = data['job_id'];
      if (id is! String || id.isEmpty) {
        throw const HunterException(
          'Server did not return a job_id',
          code: 'MISSING_JOB_ID',
        );
      }

      return id;
    } on FunctionException catch (e) {
      throw HunterException(
        _extractFunctionError(e),
        code: 'FUNCTION_ERROR',
        statusCode: e.status,
        isRetryable: e.status >= 500 || e.status == 429,
      );
    } on HunterException {
      rethrow;
    } catch (e) {
      throw HunterException(
        'Failed to start hunt: $e',
        code: 'UNKNOWN',
        isRetryable: true,
      );
    }
  }

  String _extractFunctionError(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      final msg = details['error'] ?? details['message'];
      if (msg != null) return msg.toString();
    }
    if (e.status == 401 || e.status == 403) {
      return 'Session expired. Please sign in again.';
    }
    if (e.status == 404) {
      return 'Service not available. Please try again later.';
    }
    if (e.status == 429) {
      return 'Too many requests. Please wait a moment and retry.';
    }
    if (e.status >= 500) {
      return 'Server error (${e.status}). Please retry.';
    }
    return 'Request failed (${e.status}).';
  }

  List<String> _cleanList(List<String> items) =>
      items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}
