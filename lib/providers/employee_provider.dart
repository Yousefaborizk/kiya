import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/employee_model.dart';
import 'service_providers.dart';

class EmployeeFilter {
  final String? departmentId;
  final String? jobTitleId;
  final String? status;
  final String search;

  const EmployeeFilter({
    this.departmentId,
    this.jobTitleId,
    this.status,
    this.search = '',
  });

  EmployeeFilter copyWith({
    String? departmentId,
    String? jobTitleId,
    String? status,
    String? search,
    bool clearDepartment = false,
    bool clearJobTitle = false,
    bool clearStatus = false,
  }) {
    return EmployeeFilter(
      departmentId:
          clearDepartment ? null : (departmentId ?? this.departmentId),
      jobTitleId: clearJobTitle ? null : (jobTitleId ?? this.jobTitleId),
      status: clearStatus ? null : (status ?? this.status),
      search: search ?? this.search,
    );
  }
}

final employeeFilterProvider =
    StateProvider<EmployeeFilter>((ref) => const EmployeeFilter());

final employeesListProvider =
    FutureProvider.autoDispose<List<EmployeeModel>>((ref) async {
  final filter = ref.watch(employeeFilterProvider);
  final service = ref.watch(employeeServiceProvider);

  return service.getEmployees(
    departmentId: filter.departmentId,
    jobTitleId: filter.jobTitleId,
    status: filter.status,
    search: filter.search.isEmpty ? null : filter.search,
  );
});

final employeeByIdProvider =
    FutureProvider.autoDispose.family<EmployeeModel?, String>((ref, id) async {
  final service = ref.watch(employeeServiceProvider);
  return service.getEmployeeById(id);
});
