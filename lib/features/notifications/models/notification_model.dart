class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final String? icon;
  final String? referenceType;
  final String? referenceId;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.icon,
    this.referenceType,
    this.referenceId,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'] ?? 'system',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      icon: json['icon'],
      referenceType: json['reference_type'],
      referenceId: json['reference_id'],
      isRead: json['is_read'] ?? false,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
