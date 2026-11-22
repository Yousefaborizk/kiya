import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employee_activity.dart';
import '../services/activity_service.dart';

final activityServiceProvider = Provider((_) => ActivityService());

final leaderboardProvider =
    FutureProvider.autoDispose<List<EmployeeStat>>((ref) async {
  return ref.watch(activityServiceProvider).getLeaderboard();
});

final myActivitiesProvider =
    StreamProvider.autoDispose<List<EmployeeActivity>>((ref) {
  return ref.watch(activityServiceProvider).streamRecentActivities(limit: 50);
});
