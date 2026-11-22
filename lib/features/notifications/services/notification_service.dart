import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationService {
  final SupabaseClient _client = Supabase.instance.client;

  Stream<List<AppNotification>> streamNotifications({int limit = 50}) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit)
        .map((rows) => rows.map((e) => AppNotification.fromJson(e)).toList());
  }

  Stream<int> streamUnreadCount() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return Stream.value(0);

    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows.where((r) => r['is_read'] == false).length);
  }

  Future<void> markAsRead(String id) async {
    await _client.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String()
    }).eq('id', id);
  }

  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<void> delete(String id) async {
    await _client.from('notifications').delete().eq('id', id);
  }
}
