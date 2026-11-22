import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/employee_service.dart';

final employeeServiceProvider = Provider<EmployeeService>((ref) {
  return EmployeeService();
});
