import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/employee_model.dart';
import '../models/employee_salary_model.dart';
import '../models/job_title_model.dart';

class EmployeeService {
  final SupabaseClient _client = Supabase.instance.client;

  // ============================================
  // DEPARTMENTS
  // ============================================
  Future<List<Map<String, dynamic>>> getDepartments() async {
    final data = await _client
        .from(AppConstants.tableDepartments)
        .select('id, name')
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(data as List);
  }

  // ============================================
  // JOB TITLES
  // ============================================
  Future<List<JobTitleModel>> getJobTitles() async {
    // بنجيب كل الأعمدة عشان name_en و name_zh ييجوا معانا
    final data = await _client
        .from(AppConstants.tableJobTitles)
        .select()
        .eq('is_active', true)
        .order('name');

    debugPrint('GET JOB TITLES: ${data.length} rows');
    return (data as List)
        .map((e) => JobTitleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<JobTitleModel> createJobTitle(JobTitleModel title) async {
    await _client.from(AppConstants.tableJobTitles).insert(title.toJson());
    return title;
  }

  Future<void> updateJobTitle(String id, Map<String, dynamic> updates) async {
    await _client
        .from(AppConstants.tableJobTitles)
        .update(updates)
        .eq('id', id);
  }

  Future<void> deleteJobTitle(String id) async {
    await _client
        .from(AppConstants.tableJobTitles)
        .update({'is_active': false}).eq('id', id);
  }

  // ============================================
  // EMPLOYEES
  // ============================================
  Future<List<EmployeeModel>> getEmployees({
    String? departmentId,
    String? jobTitleId,
    String? status,
    String? search,
  }) async {
    try {
      var query = _client.from(AppConstants.tableEmployees).select();

      if (departmentId != null) query = query.eq('department_id', departmentId);
      if (jobTitleId != null) query = query.eq('job_title_id', jobTitleId);
      if (status != null) query = query.eq('status', status);
      if (search != null && search.isNotEmpty) {
        query = query.or(
          'full_name.ilike.%$search%,employee_code.ilike.%$search%,phone.ilike.%$search%',
        );
      }

      final data = await query.order('created_at', ascending: false);
      debugPrint('GET EMPLOYEES: ${data.length} rows');
      return (data as List)
          .map((e) => EmployeeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('GET EMPLOYEES ERROR: $e');
      rethrow;
    }
  }

  Future<EmployeeModel?> getEmployeeById(String id) async {
    final data = await _client
        .from(AppConstants.tableEmployees)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return EmployeeModel.fromJson(data);
  }

  Future<EmployeeModel> createEmployee(EmployeeModel employee) async {
    try {
      final payload = employee.toJson();
      debugPrint('INSERT PAYLOAD: $payload');

      final data = await _client
          .from(AppConstants.tableEmployees)
          .insert(payload)
          .select()
          .single();

      debugPrint('INSERT SUCCESS: $data');
      return EmployeeModel.fromJson(data);
    } catch (e) {
      debugPrint('CREATE EMPLOYEE ERROR: $e');
      rethrow;
    }
  }

  Future<EmployeeModel> updateEmployee(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final data = await _client
        .from(AppConstants.tableEmployees)
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return EmployeeModel.fromJson(data);
  }

  Future<void> deleteEmployee(String id) async {
    await _client
        .from(AppConstants.tableEmployees)
        .update({'status': 'terminated'}).eq('id', id);
  }

  // ============================================
  // EMPLOYEE SALARIES
  // ============================================
  Future<List<EmployeeSalaryModel>> getEmployeeSalaries(
    String employeeId,
  ) async {
    final data = await _client
        .from(AppConstants.tableEmployeeSalaries)
        .select()
        .eq('employee_id', employeeId)
        .order('effective_from', ascending: false);
    return (data as List)
        .map((e) => EmployeeSalaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EmployeeSalaryModel?> getCurrentSalary(String employeeId) async {
    final data = await _client
        .from(AppConstants.tableEmployeeSalaries)
        .select()
        .eq('employee_id', employeeId)
        .isFilter('effective_to', null)
        .maybeSingle();
    if (data == null) return null;
    return EmployeeSalaryModel.fromJson(data);
  }

  Future<EmployeeSalaryModel> createSalary(EmployeeSalaryModel salary) async {
    await _client
        .from(AppConstants.tableEmployeeSalaries)
        .insert(salary.toJson());
    return salary;
  }

  // ============================================
  // EMPLOYEE DOCUMENTS
  // ============================================
  Future<List<Map<String, dynamic>>> getEmployeeDocuments(
    String employeeId,
  ) async {
    final data = await _client
        .from(AppConstants.tableEmployeeDocuments)
        .select()
        .eq('employee_id', employeeId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<String> uploadDocument({
    required String employeeId,
    required String filePath,
    required List<int> bytes,
    required String fileName,
    required String documentType,
    required String title,
    DateTime? expiryDate,
  }) async {
    final storagePath = 'employees/$employeeId/$fileName';
    await _client.storage
        .from(AppConstants.bucketEmployeeDocs)
        .uploadBinary(storagePath, Uint8List.fromList(bytes));

    final fileUrl = _client.storage
        .from(AppConstants.bucketEmployeeDocs)
        .getPublicUrl(storagePath);

    await _client.from(AppConstants.tableEmployeeDocuments).insert({
      'employee_id': employeeId,
      'document_type': documentType,
      'title': title,
      'file_url': fileUrl,
      'file_size': bytes.length,
      'expiry_date': expiryDate?.toIso8601String().split('T').first,
      'uploaded_by': _client.auth.currentUser?.id,
    });

    return fileUrl;
  }

  Future<void> deleteDocument(String documentId, String fileUrl) async {
    await _client
        .from(AppConstants.tableEmployeeDocuments)
        .delete()
        .eq('id', documentId);
  }
}
