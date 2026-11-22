import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/employee_activity.dart';
import '../providers/activity_providers.dart';

class ActivityDashboardScreen extends ConsumerWidget {
  const ActivityDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('activity_dashboard'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('team_leaderboard'.tr(),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ref.watch(leaderboardProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (list) => Column(
                  children: list.map((s) => _LeaderboardCard(stat: s)).toList(),
                ),
              ),
          const SizedBox(height: 24),
          Text('my_recent_activity'.tr(),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ref.watch(myActivitiesProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (items) => Column(
                  children: items
                      .take(20)
                      .map((a) => _ActivityTile(activity: a))
                      .toList(),
                ),
              ),
        ],
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final EmployeeStat stat;
  const _LeaderboardCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage:
                  stat.avatarUrl != null ? NetworkImage(stat.avatarUrl!) : null,
              child: stat.avatarUrl == null
                  ? Text(stat.fullName.isNotEmpty
                      ? stat.fullName[0].toUpperCase()
                      : '?')
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stat.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${stat.totalActions} ${'actions'.tr()}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            _Chip(label: 'invoices'.tr(), value: stat.invoicesCreated),
            const SizedBox(width: 6),
            _Chip(label: 'messages'.tr(), value: stat.messagesSent),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int value;
  const _Chip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text('$value',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final EmployeeActivity activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.info.withValues(alpha: 0.15),
        child: Icon(_iconFor(activity.action), size: 16, color: AppColors.info),
      ),
      title: Text('${activity.action} · ${activity.module}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(
        activity.description ??
            activity.metadata['operation']?.toString() ??
            '',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Text(
        DateFormat('hh:mm a').format(activity.createdAt.toLocal()),
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
    );
  }

  IconData _iconFor(String action) {
    switch (action) {
      case 'create':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline;
      case 'view':
        return Icons.visibility_outlined;
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'send_message':
        return Icons.send;
      default:
        return Icons.circle_outlined;
    }
  }
}
