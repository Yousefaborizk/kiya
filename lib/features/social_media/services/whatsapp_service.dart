// ============================================
// WhatsApp Service
// ============================================

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/api_config.dart';
import '../models/whatsapp_models.dart';

class WhatsAppService {
  final SupabaseClient _client = Supabase.instance.client;

  static const Duration _sendTimeout = Duration(seconds: 15);

  // ============================================
  // CONVERSATIONS (with assigned agent name)
  // ============================================
  Stream<List<WhatsAppConversation>> streamConversations() {
    return _client
        .from('whatsapp_conversations')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .asyncMap((conversationsData) async {
          // Fetch all users once to map assigned_to → full_name
          Map<dynamic, dynamic> userMap = {};
          try {
            final usersData =
                await _client.from('users').select('id, full_name');
            userMap = {
              for (var u in usersData) u['id']: u['full_name'],
            };
          } catch (e) {
            debugPrint('⚠️ Could not fetch users for WA conversations: $e');
          }

          return conversationsData.map((e) {
            e['assigned_agent_name'] =
                e['assigned_to'] != null ? userMap[e['assigned_to']] : null;
            return WhatsAppConversation.fromJson(e);
          }).toList();
        });
  }

  // ============================================
  // MESSAGES
  // ============================================
  Stream<List<WhatsAppMessage>> streamMessages(String conversationId) {
    return _client
        .from('whatsapp_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('timestamp', ascending: true)
        .map((list) => list.map((e) => WhatsAppMessage.fromJson(e)).toList());
  }

  // ============================================
  // SEND MESSAGE (with agent_id tracking)
  // ============================================
  Future<void> sendMessage(String phone, String text) async {
    // ── Basic guards ──────────────────────────
    if (phone.trim().isEmpty) {
      throw Exception('رقم المستلم غير موجود');
    }
    if (text.trim().isEmpty) {
      throw Exception('نص الرسالة فارغ');
    }

    // ← بنجيب آي دي الموظف الحالي عشان الإحصائيات
    final myId = _client.auth.currentUser?.id;

    try {
      final response = await http
          .post(
            ApiConfig.whatsappSendUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phone,
              'text': text,
              'agent_id': myId, // ← تم إضافة الآي دي هنا
            }),
          )
          .timeout(_sendTimeout);

      // ── Parse JSON body safely ─────────────
      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        // Non-JSON response — ignore
      }

      if (response.statusCode != 200) {
        final serverMsg = body['error']?.toString() ?? response.body;
        throw Exception('فشل الإرسال من السيرفر: $serverMsg');
      }

      if (body['success'] != true) {
        throw Exception('السيرفر لم يؤكد الإرسال');
      }
    } on TimeoutException {
      throw Exception(
        'انتهت مهلة الاتصال بالسيرفر (${_sendTimeout.inSeconds}s) — '
        'تأكد من تشغيل WhatsApp Gateway',
      );
    } on SocketException catch (e) {
      throw Exception(
        'تعذّر الاتصال بالسيرفر على ${ApiConfig.whatsappGateway} — '
        'تأكد من تشغيل WhatsApp Gateway\n($e)',
      );
    } on http.ClientException catch (e) {
      throw Exception('خطأ في الشبكة: ${e.message}');
    }
  }

  // ============================================
  // ASSIGNMENT
  // ============================================
  Future<void> assignToMe(String conversationId, String myUserId) async {
    await _client
        .from('whatsapp_conversations')
        .update({'assigned_to': myUserId})
        .eq('id', conversationId)
        .isFilter('assigned_to', null); // only assign if empty
  }

  // ============================================
  // ADMIN DASHBOARD STATS
  // ============================================
  Future<List<dynamic>> getAdminStats() async {
    final response = await _client.rpc('get_agent_stats');
    return response as List<dynamic>;
  }
}
