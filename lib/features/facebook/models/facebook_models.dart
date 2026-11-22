class FacebookConversation {
  final String id;
  final String pageId;
  final String psid;
  final String? customerName;
  final String? customerProfilePic;
  final String? lastMessagePreview;
  final DateTime lastMessageAt;
  final String? assignedTo;
  final String? assignedAgentName;
  final String status;

  FacebookConversation({
    required this.id,
    required this.pageId,
    required this.psid,
    this.customerName,
    this.customerProfilePic,
    this.lastMessagePreview,
    required this.lastMessageAt,
    this.assignedTo,
    this.assignedAgentName,
    required this.status,
  });

  factory FacebookConversation.fromJson(Map<String, dynamic> json) {
    return FacebookConversation(
      id: json['id'],
      pageId: json['page_id'] ?? '',
      psid: json['psid'] ?? '',
      customerName: json['customer_name'],
      customerProfilePic: json['customer_profile_pic'],
      lastMessagePreview: json['last_message_preview'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : DateTime.now(),
      assignedTo: json['assigned_to'],
      assignedAgentName: json['assigned_agent_name'],
      status: json['status'] ?? 'open',
    );
  }
}

class FacebookMessage {
  final String id;
  final String conversationId;
  final bool fromMe;
  final String? senderName;
  final String? content;
  final DateTime timestamp;

  FacebookMessage({
    required this.id,
    required this.conversationId,
    required this.fromMe,
    this.senderName,
    this.content,
    required this.timestamp,
  });

  factory FacebookMessage.fromJson(Map<String, dynamic> json) {
    return FacebookMessage(
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
