class EmployeeActivity {
  final String id;
  final String userId;
  final String action;
  final String module;
  final String? entityType;
  final String? entityId;
  final String? description;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  EmployeeActivity({
    required this.id,
    required this.userId,
    required this.action,
    required this.module,
    this.entityType,
    this.entityId,
    this.description,
    required this.metadata,
    required this.createdAt,
  });

  factory EmployeeActivity.fromJson(Map<String, dynamic> json) {
    return EmployeeActivity(
      id: json['id'],
      userId: json['user_id'],
      action: json['action'],
      module: json['module'],
      entityType: json['entity_type'],
      entityId: json['entity_id'],
      description: json['description'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class EmployeeStat {
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final int totalActions;
  final int invoicesCreated;
  final int messagesSent;

  EmployeeStat({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.totalActions,
    required this.invoicesCreated,
    required this.messagesSent,
  });

  factory EmployeeStat.fromJson(Map<String, dynamic> json) {
    return EmployeeStat(
      userId: json['user_id'],
      fullName: json['full_name'] ?? 'Unknown',
      avatarUrl: json['avatar_url'],
      totalActions: (json['total_actions'] ?? 0) as int,
      invoicesCreated: (json['invoices_created'] ?? 0) as int,
      messagesSent: (json['messages_sent'] ?? 0) as int,
    );
  }
}
