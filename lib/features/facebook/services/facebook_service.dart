// ============================================
// Facebook Service
// ============================================

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
  // 1. CONVERSATIONS (رسايل)
  // ============================================
  Stream<List<FacebookConversation>> streamConversations() {
    return _client
        .from('facebook_conversations')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .asyncMap((rows) async {
          Map<dynamic, dynamic> userMap = {};
          try {
            final users = await _client.from('users').select('id, full_name');
            userMap = {for (var u in users) u['id']: u['full_name']};
          } catch (e) {
            debugPrint('⚠️ Could not fetch users: $e');
          }
          return rows.map((e) {
            e['assigned_agent_name'] =
                e['assigned_to'] != null ? userMap[e['assigned_to']] : null;
            return FacebookConversation.fromJson(e);
          }).toList();
        });
  }

  Stream<List<FacebookMessage>> streamMessages(String conversationId) {
    return _client
        .from('facebook_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('timestamp', ascending: true)
        .map((rows) => rows.map((e) => FacebookMessage.fromJson(e)).toList());
  }

  // ============================================
  // 2. SEND MESSAGE (إرسال رسالة)
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
            body: jsonEncode({'psid': psid, 'text': text, 'agent_id': myId}),
          )
          .timeout(_sendTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['error'] ?? 'فشل الإرسال');
      }
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال بالسيرفر');
    } on SocketException {
      throw Exception('تعذّر الاتصال بالسيرفر — تأكد من تشغيل Gateway');
    }
  }

  // ============================================
  // 3. REPLY TO COMMENT (الرد على كومنت)
  // ============================================
  Future<void> replyToComment(String commentId, String text) async {
    if (commentId.trim().isEmpty || text.trim().isEmpty) return;

    final myId = _client.auth.currentUser?.id;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.facebookGateway}/reply-comment'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(
                {'comment_id': commentId, 'text': text, 'agent_id': myId}),
          )
          .timeout(_sendTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['error'] ?? 'فشل الرد على الكومنت');
      }
    } catch (e) {
      throw Exception('خطأ أثناء الرد: $e');
    }
  }

  // ============================================
  // 4. FETCH POSTS (جلب البوستات)
  // ============================================
  Future<List<Map<String, dynamic>>> getPosts() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.facebookGateway}/posts'),
          )
          .timeout(_sendTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['error'] ?? 'فشل جلب البوستات');
      }
      return List<Map<String, dynamic>>.from(body['posts'] ?? []);
    } catch (e) {
      throw Exception('خطأ في جلب البوستات: $e');
    }
  }

  // ============================================
  // 5. ASSIGNMENT (إسناد المحادثة للموظف)
  // ============================================
  Future<void> assignToMe(String conversationId, String myUserId) async {
    await _client
        .from('facebook_conversations')
        .update({'assigned_to': myUserId})
        .eq('id', conversationId)
        .isFilter('assigned_to', null);
  }
}
