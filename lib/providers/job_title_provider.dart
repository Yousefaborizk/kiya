import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/job_title_model.dart';
import 'service_providers.dart';

/// All active job titles.
final jobTitlesListProvider =
    FutureProvider.autoDispose<List<JobTitleModel>>((ref) async {
  final service = ref.watch(employeeServiceProvider);
  return service.getJobTitles();
});

/// Job titles filtered by a specific department.
/// If [departmentId] is null, returns all job titles.
final jobTitlesByDepartmentProvider = FutureProvider.autoDispose
    .family<List<JobTitleModel>, String?>((ref, departmentId) async {
  final all = await ref.watch(jobTitlesListProvider.future);
  if (departmentId == null) return all;
  return all.where((t) => t.departmentId == departmentId).toList();
});

/// Job titles grouped by department (for selectors).
final jobTitlesGroupedProvider =
    FutureProvider.autoDispose<Map<String, List<JobTitleModel>>>((ref) async {
  final all = await ref.watch(jobTitlesListProvider.future);
  final grouped = <String, List<JobTitleModel>>{};
  for (final title in all) {
    final key = title.departmentId ?? 'unassigned';
    grouped.putIfAbsent(key, () => []).add(title);
  }
  return grouped;
});
