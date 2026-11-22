class WhatsAppConversation {
  final String id;
  final String customerPhone;
  final String? customerName;
  final String? lastMessagePreview;
  final DateTime lastMessageAt;
  final String? assignedTo;
  final String? assignedAgentName; // ✅ اسم الموظف المسؤول
  final String status;

  WhatsAppConversation({
    required this.id,
    required this.customerPhone,
    this.customerName,
    this.lastMessagePreview,
    required this.lastMessageAt,
    this.assignedTo,
    this.assignedAgentName,
    required this.status,
  });

  factory WhatsAppConversation.fromJson(Map<String, dynamic> json) {
    return WhatsAppConversation(
      id: json['id'],
      customerPhone: json['customer_phone'] ?? '',
      customerName: json['customer_name'],
      lastMessagePreview: json['last_message_preview'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : DateTime.now(),
      assignedTo: json['assigned_to'],
      assignedAgentName: json['assigned_agent_name'], // بييجي من الـ Service
      status: json['status'] ?? 'open',
    );
  }
}

class WhatsAppMessage {
  final String id;
  final String conversationId;
  final bool fromMe;
  final String? senderName;
  final String? content;
  final DateTime timestamp;

  WhatsAppMessage({
    required this.id,
    required this.conversationId,
    required this.fromMe,
    this.senderName,
    this.content,
    required this.timestamp,
  });

  factory WhatsAppMessage.fromJson(Map<String, dynamic> json) {
    return WhatsAppMessage(
      id: json['id'],
      conversationId: json['conversation_id'],
      fromMe: json['from_me'] ?? false,
      senderName: json['sender_name'],
      content: json['content'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}
