import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

final notificationServiceProvider =
    Provider<NotificationService>((_) => NotificationService());

final notificationsStreamProvider =
    StreamProvider<List<AppNotification>>((ref) {
  return ref.watch(notificationServiceProvider).streamNotifications();
});

final unreadCountProvider = StreamProvider<int>((ref) {
  return ref.watch(notificationServiceProvider).streamUnreadCount();
});
