import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../models/notification_model.dart';
import '../providers/notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('notifications'.tr()),
        actions: [
          TextButton.icon(
            onPressed: () =>
                ref.read(notificationServiceProvider).markAllAsRead(),
            icon: const Icon(Icons.done_all, color: Colors.white, size: 18),
            label: Text(
              'mark_all_read'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Error: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'no_notifications'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _NotificationTile(item: items[i]),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SINGLE TILE
// ═══════════════════════════════════════════════════════════
class _NotificationTile extends ConsumerWidget {
  final AppNotification item;

  const _NotificationTile({required this.item});

  IconData _iconFor() {
    switch (item.icon) {
      case 'whatsapp':
        return Icons.chat;
      case 'facebook':
        return Icons.facebook;
      case 'invoice':
        return Icons.receipt_long;
      case 'stock':
        return Icons.inventory_2;
      case 'lead':
        return Icons.person_search;
      default:
        return Icons.notifications;
    }
  }

  Color _colorFor() {
    switch (item.icon) {
      case 'whatsapp':
        return const Color(0xFF25D366);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'invoice':
        return AppColors.primary;
      case 'stock':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    // Mark as read first
    await ref.read(notificationServiceProvider).markAsRead(item.id);

    if (!context.mounted) return;

    // Route based on reference type
    switch (item.referenceType) {
      case 'whatsapp_conversation':
        context.push('/whatsapp-inbox');
        break;
      case 'facebook_conversation':
        context.push('/facebook-inbox');
        break;
      case 'invoice':
        if (item.referenceId != null) {
          context.push('/sales/${item.referenceId}');
        }
        break;
      case 'lead':
        context.push('/ai-business-hunter');
        break;
      default:
        // Nothing to navigate to — just mark as read
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onTap: () => _onTap(context, ref),
      leading: CircleAvatar(
        backgroundColor: _colorFor().withValues(alpha: 0.15),
        child: Icon(_iconFor(), color: _colorFor()),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            item.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('dd/MM/yyyy  hh:mm a').format(item.createdAt.toLocal()),
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      trailing: !item.isRead
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.info,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
