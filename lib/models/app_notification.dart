class AppNotification {
  final int id;
  final String title;
  final String message;
  final String notificationType;
  final String targetAudience;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.targetAudience,
    required this.createdAt,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      title: (json['title'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      notificationType: (json['notification_type'] as String?) ?? 'BROADCAST',
      targetAudience: (json['target_audience'] as String?) ?? 'ALL',
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.now(),
    );
  }

  bool get isBroadcast => notificationType == 'BROADCAST';
}
