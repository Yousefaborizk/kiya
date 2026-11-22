import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/employee_salary_model.dart';
import 'service_providers.dart';

/// Current salary (effective_to = null) for an employee.
final currentSalaryProvider = FutureProvider.autoDispose
    .family<EmployeeSalaryModel?, String>((ref, employeeId) async {
  final service = ref.watch(employeeServiceProvider);
  return service.getCurrentSalary(employeeId);
});

/// Full salary history for an employee (newest first).
final salaryHistoryProvider = FutureProvider.autoDispose
    .family<List<EmployeeSalaryModel>, String>((ref, employeeId) async {
  final service = ref.watch(employeeServiceProvider);
  return service.getEmployeeSalaries(employeeId);
});
