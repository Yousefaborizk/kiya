import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_models.dart';

class AiAssistantRepository {
  final SupabaseClient _supabase;

  AiAssistantRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  String get _uid {
    final u = _supabase.auth.currentUser;
    if (u == null) throw AiException('ai_err_not_signed_in'.tr());
    return u.id;
  }

  // ── جلب المحادثات (Realtime) ──────────────────────────
  Stream<List<AiConversation>> watchConversations() {
    return _supabase
        .from('ai_conversations')
        .stream(primaryKey: ['id'])
        .eq('user_id', _uid)
        .order('updated_at', ascending: false)
        .map((rows) =>
            rows.map(AiConversation.fromJson).toList(growable: false));
  }

  // ── إنشاء محادثة جديدة ─────────────────────────────────
  Future<AiConversation> createConversation({String? title}) async {
    final defaultTitle = title ?? 'ai_new_chat'.tr();
    final row = await _supabase
        .from('ai_conversations')
        .insert({'user_id': _uid, 'title': defaultTitle})
        .select()
        .single();
    return AiConversation.fromJson(row);
  }

  // ── حذف محادثة ─────────────────────────────────────────
  Future<void> deleteConversation(String id) async {
    await _supabase.from('ai_conversations').delete().eq('id', id);
  }

  // ── جلب الرسائل (Realtime) ─────────────────────────────
  Stream<List<AiMessage>> watchMessages(String conversationId) {
    return _supabase
        .from('ai_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(AiMessage.fromJson).toList(growable: false));
  }

  // ── إرسال رسالة جديدة ──────────────────────────────────
  Future<void> sendMessage({
    required String conversationId,
    required String content,
    String? autoTitle,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) throw AiException('ai_err_empty_message'.tr());

    // 1. حفظ رسالة المستخدم
    await _supabase.from('ai_messages').insert({
      'conversation_id': conversationId,
      'user_id': _uid,
      'role': 'user',
      'content': trimmed,
    });

    // 2. تحديث عنوان المحادثة لو كانت جديدة
    if (autoTitle != null && autoTitle.trim().isNotEmpty) {
      await _supabase
          .from('ai_conversations')
          .update({'title': autoTitle.trim()}).eq('id', conversationId);
    }

    // 3. استدعاء الـ Edge Function في الخلفية
    unawaited(_triggerAiResponse(conversationId));
  }

  // ── إعادة توليد الرد (Regenerate) ──────────────────────
  Future<void> regenerateResponse(String conversationId) async {
    // بنستدعي الـ Edge Function تاني بدون إضافة رسالة جديدة
    // الـ AI هيقرأ الـ Context ويعيد التوليد
    unawaited(_triggerAiResponse(conversationId));
  }

  // ── استدعاء الـ Edge Function ──────────────────────────
  Future<void> _triggerAiResponse(String conversationId) async {
    try {
      final res = await _supabase.functions.invoke(
        'ai-assistant',
        body: {'conversation_id': conversationId},
      );
      final data = res.data;
      if (data is Map && data['success'] == true) {
        debugPrint('✅ AI replied (${data['tokens_used']} tokens)');
      } else {
        debugPrint('⚠️ AI unexpected response: $data');
      }
    } catch (e) {
      debugPrint('⚠️ AI invocation failed: $e');
      rethrow;
    }
  }
}
