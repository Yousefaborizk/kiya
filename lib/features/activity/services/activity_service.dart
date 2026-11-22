import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee_activity.dart';

/// Centralized activity tracker.
///
/// - **Postgres triggers** handle CUD on business tables automatically
///   (see `20250102000000_notifications_facebook_activity.sql`).
/// - **This service** handles *manual* events: navigation, login, message sends.
/// - **Reads**: streams the current user's activities + calls the
///   `get_employee_leaderboard` RPC for team-wide stats.
class ActivityService {
  final SupabaseClient _client = Supabase.instance.client;

  // ═══════════════════════════════════════════════
  // WRITE
  // ═══════════════════════════════════════════════

  /// Generic tracker — fire-and-forget, never blocks UX.
  Future<void> track({
    required String action,
    required String module,
    String? entityType,
    String? entityId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client.from('employee_activities').insert({
        'user_id': userId,
        'action': action,
        'module': module,
        'entity_type': entityType,
        'entity_id': entityId,
        'description': description,
        'metadata': metadata ?? <String, dynamic>{},
      });
    } catch (e) {
      // Never throw — activity tracking must not break user flows.
      debugPrint('⚠️ activity track failed: $e');
    }
  }

  Future<void> trackLogin() => track(
        action: 'login',
        module: 'auth',
        description: 'تسجيل دخول',
      );

  Future<void> trackLogout() => track(
        action: 'logout',
        module: 'auth',
        description: 'تسجيل خروج',
      );

  Future<void> trackView(String module, {String? description}) => track(
        action: 'view',
        module: module,
        description: description,
      );

  Future<void> trackMessageSent(String platform, String conversationId) =>
      track(
        action: 'send_message',
        module: platform, // 'whatsapp' | 'facebook'
        entityType: 'conversation',
        entityId: conversationId,
        description: 'أرسل رسالة عبر $platform',
      );

  // ═══════════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════════

  /// Stream recent activities for a specific user (defaults to current user).
  ///
  /// ⚠️ `SupabaseStreamBuilder` in some supabase_flutter versions doesn't
  /// expose `.eq()` — we filter in Dart for full compatibility. We over-fetch
  /// (`limit * 5`) to compensate for rows that will be discarded.
  Stream<List<EmployeeActivity>> streamRecentActivities({
    String? userId,
    int limit = 100,
  }) {
    final uid = userId ?? _client.auth.currentUser?.id;
    if (uid == null) return Stream.value(const <EmployeeActivity>[]);

    return _client
        .from('employee_activities')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit * 5)
        .map((rows) {
          final filtered = rows
              .where((row) => row['user_id'] == uid)
              .take(limit)
              .map((e) => EmployeeActivity.fromJson(e))
              .toList();
          return filtered;
        });
  }

  /// Team-wide leaderboard for the last N days (default 7).
  /// Uses `get_employee_leaderboard` RPC — fully server-side.
  Future<List<EmployeeStat>> getLeaderboard({
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _client.rpc(
      'get_employee_leaderboard',
      params: {
        'p_from': (from ?? DateTime.now().subtract(const Duration(days: 7)))
            .toIso8601String(),
        'p_to': (to ?? DateTime.now()).toIso8601String(),
      },
    );

    return (data as List)
        .map((e) => EmployeeStat.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
