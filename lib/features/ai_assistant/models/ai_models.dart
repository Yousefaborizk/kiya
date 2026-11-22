import 'package:flutter/foundation.dart';

@immutable
class AiConversation {
  final String id;
  final String userId;
  final String title;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiConversation({
    required this.id,
    required this.userId,
    required this.title,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiConversation.fromJson(Map<String, dynamic> j) => AiConversation(
        id: j['id'] as String,
        userId: j['user_id'] as String? ?? '',
        title: j['title'] as String? ?? 'New Chat',
        lastMessageAt: _dt(j['last_message_at']),
        createdAt: _dt(j['created_at']) ?? DateTime.now().toUtc(),
        updatedAt: _dt(j['updated_at']) ?? DateTime.now().toUtc(),
      );
}

@immutable
class AiMessage {
  final String id;
  final String conversationId;
  final String userId;
  final String role;
  final String content;
  final int tokensUsed;
  final String? model;
  final DateTime createdAt;

  const AiMessage({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.role,
    required this.content,
    required this.tokensUsed,
    this.model,
    required this.createdAt,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  factory AiMessage.fromJson(Map<String, dynamic> j) => AiMessage(
        id: j['id'] as String,
        conversationId: j['conversation_id'] as String? ?? '',
        userId: j['user_id'] as String? ?? '',
        role: j['role'] as String? ?? 'user',
        content: j['content'] as String? ?? '',
        tokensUsed: (j['tokens_used'] as num?)?.toInt() ?? 0,
        model: j['model'] as String?,
        createdAt: _dt(j['created_at']) ?? DateTime.now().toUtc(),
      );
}

DateTime? _dt(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}
