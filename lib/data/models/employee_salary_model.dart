class EmployeeSalaryModel {
  final String id;
  final String employeeId;
  final double basicSalary;
  final double allowances;
  final double deductions;
  final String currency;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String? changeReason;
  final String? createdBy;
  final DateTime createdAt;

  const EmployeeSalaryModel({
    required this.id,
    required this.employeeId,
    required this.basicSalary,
    this.allowances = 0,
    this.deductions = 0,
    this.currency = 'EGP',
    required this.effectiveFrom,
    this.effectiveTo,
    this.changeReason,
    this.createdBy,
    required this.createdAt,
  });

  double get netSalary => basicSalary + allowances - deductions;
  bool get isCurrent => effectiveTo == null;

  factory EmployeeSalaryModel.fromJson(Map<String, dynamic> json) {
    return EmployeeSalaryModel(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      basicSalary: (json['basic_salary'] as num).toDouble(),
      allowances: (json['allowances'] as num?)?.toDouble() ?? 0,
      deductions: (json['deductions'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'EGP',
      effectiveFrom: DateTime.parse(json['effective_from'] as String),
      effectiveTo: json['effective_to'] != null
          ? DateTime.parse(json['effective_to'] as String)
          : null,
      changeReason: json['change_reason'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'basic_salary': basicSalary,
      'allowances': allowances,
      'deductions': deductions,
      'currency': currency,
      'effective_from': effectiveFrom.toIso8601String().split('T').first,
      'change_reason': changeReason,
    };
  }
}
