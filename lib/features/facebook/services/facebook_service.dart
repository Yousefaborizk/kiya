import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/api_config.dart';
import '../models/facebook_models.dart';

class FacebookService {
  final SupabaseClient _client = Supabase.instance.client;
  static const Duration _sendTimeout = Duration(seconds: 15);

  // ============================================
  // 1. CONVERSATIONS — REALTIME STREAM ✅
  // ============================================
  Stream<List<FacebookConversation>> streamConversations() {
    return _client
        .from('facebook_conversations')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .asyncMap((conversationsData) async {
          // جلب أسماء الموظفين مرة واحدة لكل emission
          Map<dynamic, dynamic> userMap = {};
          try {
            final users = await _client.from('users').select('id, full_name');
            userMap = {for (var u in users) u['id']: u['full_name']};
          } catch (e) {
            debugPrint('⚠️ Could not fetch users: $e');
          }

          return conversationsData.map((e) {
            e['assigned_agent_name'] =
                e['assigned_to'] != null ? userMap[e['assigned_to']] : null;
            return FacebookConversation.fromJson(e);
          }).toList();
        });
  }

  // ============================================
  // 1.b LEGACY: getConversations (One-shot)
  // ============================================
  Future<List<FacebookConversation>> getConversations() async {
    try {
      final response = await _client
          .from('facebook_conversations')
          .select()
          .order('last_message_at', ascending: false);

      Map<dynamic, dynamic> userMap = {};
      try {
        final users = await _client.from('users').select('id, full_name');
        userMap = {for (var u in users) u['id']: u['full_name']};
      } catch (e) {
        debugPrint('⚠️ Could not fetch users: $e');
      }

      return (response as List).map((e) {
        e['assigned_agent_name'] =
            e['assigned_to'] != null ? userMap[e['assigned_to']] : null;
        return FacebookConversation.fromJson(e);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching conversations: $e');
      throw Exception('فشل تحميل المحادثات: $e');
    }
  }

  // ============================================
  // 2. MESSAGES (Stream)
  // ============================================
  Stream<List<FacebookMessage>> streamMessages(String conversationId) {
    return _client
        .from('facebook_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('timestamp', ascending: true)
        .map((rows) => rows.map((e) => FacebookMessage.fromJson(e)).toList());
  }

  // ============================================
  // 3. SEND MESSAGE
  // ============================================
  Future<void> sendMessage(String psid, String text) async {
    if (psid.trim().isEmpty) throw Exception('PSID غير موجود');
    if (text.trim().isEmpty) throw Exception('نص الرسالة فارغ');

    final myId = _client.auth.currentUser?.id;

    try {
      final response = await http
          .post(
            ApiConfig.facebookSendUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': psid,
              'text': text,
              'agent_id': myId,
            }),
          )
          .timeout(_sendTimeout);

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(
            body['error']?.toString() ?? body['detail'] ?? 'فشل الإرسال');
      }
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال بالسيرفر');
    } on SocketException {
      throw Exception('تعذّر الاتصال بالسيرفر — تأكد من تشغيل السيرفر');
    } on http.ClientException catch (e) {
      throw Exception('خطأ في الشبكة: ${e.message}');
    }
  }

  // ============================================
  // 4. REPLY TO COMMENT
  // ============================================
  Future<void> replyToComment(String commentId, String text) async {
    if (commentId.trim().isEmpty || text.trim().isEmpty) return;
    final myId = _client.auth.currentUser?.id;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.facebookGateway}/reply-comment'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'comment_id': commentId,
              'text': text,
              'agent_id': myId,
            }),
          )
          .timeout(_sendTimeout);

      if (response.statusCode != 200) {
        throw Exception('فشل الرد على الكومنت (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال بالسيرفر');
    } on SocketException {
      throw Exception('تعذّر الاتصال بالسيرفر');
    } catch (e) {
      throw Exception('خطأ أثناء الرد: $e');
    }
  }

  // ============================================
  // 5. FETCH POSTS
  // ============================================
  Future<List<Map<String, dynamic>>> getPosts() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.facebookGateway}/posts'))
          .timeout(_sendTimeout);

      if (response.statusCode != 200) {
        throw Exception('فشل جلب البوستات (${response.statusCode})');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      return data.cast<Map<String, dynamic>>();
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال بالسيرفر');
    } on SocketException {
      throw Exception('تعذّر الاتصال بالسيرفر');
    } catch (e) {
      throw Exception('خطأ في جلب البوستات: $e');
    }
  }

  // ============================================
  // 6. ASSIGNMENT
  // ============================================
  Future<void> assignToMe(String conversationId, String myUserId) async {
    await _client
        .from('facebook_conversations')
        .update({'assigned_to': myUserId})
        .eq('id', conversationId)
        .isFilter('assigned_to', null);
  }
}
