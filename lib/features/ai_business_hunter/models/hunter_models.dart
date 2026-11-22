import 'package:flutter/foundation.dart';

// =====================================================
// HunterJob — mirrors public.hunter_jobs
// =====================================================
@immutable
class HunterJob {
  final String id;
  final String userId;
  final String industry;
  final List<String> products;
  final List<String> targetCountries;
  final String? notes;
  final String status; // pending|searching|scoring|drafting|completed|failed
  final int progress; // 0..100
  final String? errorMessage;
  final List<String> queriesGenerated;
  final int rawResultsCount;
  final int leadsCount;
  final String? providerUsed;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HunterJob({
    required this.id,
    required this.userId,
    required this.industry,
    required this.products,
    required this.targetCountries,
    this.notes,
    required this.status,
    required this.progress,
    this.errorMessage,
    required this.queriesGenerated,
    required this.rawResultsCount,
    required this.leadsCount,
    this.providerUsed,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Convenience getters ────────────────────────────
  bool get isActive =>
      status == 'pending' ||
      status == 'searching' ||
      status == 'scoring' ||
      status == 'drafting';

  bool get isCompleted => status == 'completed';
  bool get hasFailed => status == 'failed';
  bool get isTerminal => isCompleted || hasFailed;

  /// Human-friendly stage label
  String get stageLabel {
    switch (status) {
      case 'pending':
        return 'Preparing';
      case 'searching':
        return 'Searching the web';
      case 'scoring':
        return 'Scoring leads';
      case 'drafting':
        return 'Writing outreach';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  factory HunterJob.fromJson(Map<String, dynamic> json) {
    return HunterJob(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      industry: json['industry'] as String? ?? '',
      products: _asStringList(json['products']),
      targetCountries: _asStringList(json['target_countries']),
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      errorMessage: json['error_message'] as String?,
      queriesGenerated: _asStringList(json['queries_generated']),
      rawResultsCount: (json['raw_results_count'] as num?)?.toInt() ?? 0,
      leadsCount: (json['leads_count'] as num?)?.toInt() ?? 0,
      providerUsed: json['provider_used'] as String?,
      startedAt: _asDateTime(json['started_at']),
      completedAt: _asDateTime(json['completed_at']),
      createdAt: _asDateTime(json['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: _asDateTime(json['updated_at']) ?? DateTime.now().toUtc(),
    );
  }
}

// =====================================================
// HunterLead — mirrors public.hunter_leads
// =====================================================
@immutable
class HunterLead {
  final String id;
  final String jobId;
  final String userId;
  final String companyName;
  final String? website;
  final String? country;
  final String? industry;
  final String? description;
  final String? contactUrl;
  final String sourceUrl;
  final String? sourceTitle;
  final String? sourceSnippet;
  final int score;
  final Map<String, int> scoreBreakdown;
  final List<String> scoreReasons;
  final String? outreachMessage;
  final String status; // new|saved|ignored|contacted
  final DateTime createdAt;
  final DateTime updatedAt;

  const HunterLead({
    required this.id,
    required this.jobId,
    required this.userId,
    required this.companyName,
    this.website,
    this.country,
    this.industry,
    this.description,
    this.contactUrl,
    required this.sourceUrl,
    this.sourceTitle,
    this.sourceSnippet,
    required this.score,
    required this.scoreBreakdown,
    required this.scoreReasons,
    this.outreachMessage,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Convenience ────────────────────────────────────
  bool get hasMessage =>
      outreachMessage != null && outreachMessage!.trim().isNotEmpty;

  bool get isHighScore => score >= 60;

  String get scoreTier {
    if (score >= 80) return 'hot';
    if (score >= 60) return 'warm';
    if (score >= 40) return 'cold';
    return 'low';
  }

  factory HunterLead.fromJson(Map<String, dynamic> json) {
    return HunterLead(
      id: json['id'] as String,
      jobId: json['job_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      companyName: json['company_name'] as String? ?? 'Unknown',
      website: _asNullableString(json['website']),
      country: _asNullableString(json['country']),
      industry: _asNullableString(json['industry']),
      description: _asNullableString(json['description']),
      contactUrl: _asNullableString(json['contact_url']),
      sourceUrl: json['source_url'] as String? ?? '',
      sourceTitle: _asNullableString(json['source_title']),
      sourceSnippet: _asNullableString(json['source_snippet']),
      score: (json['score'] as num?)?.toInt() ?? 0,
      scoreBreakdown: _asIntMap(json['score_breakdown']),
      scoreReasons: _asStringList(json['score_reasons']),
      outreachMessage: _asNullableString(json['outreach_message']),
      status: json['status'] as String? ?? 'new',
      createdAt: _asDateTime(json['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: _asDateTime(json['updated_at']) ?? DateTime.now().toUtc(),
    );
  }
}

// =====================================================
// Helpers
// =====================================================

List<String> _asStringList(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value
        .whereType<Object?>()
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

String? _asNullableString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _asDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

Map<String, int> _asIntMap(dynamic v) {
  if (v is! Map) return const {};
  final out = <String, int>{};
  v.forEach((k, val) {
    final n = val is num ? val.toInt() : int.tryParse(val?.toString() ?? '');
    if (n != null) out[k.toString()] = n;
  });
  return Map.unmodifiable(out);
}

// =====================================================
// Exception type
// =====================================================
class HunterException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final bool isRetryable;

  const HunterException(
    this.message, {
    this.code,
    this.statusCode,
    this.isRetryable = false,
  });

  @override
  String toString() => message;
}
