class AppConstants {
  AppConstants._();

  // ============================================
  // APP INFO
  // ============================================
  static const String appName = 'SI EXPORTER OS';
  static const String appVersion = '1.0.0';

  // ============================================
  // SUPABASE
  // ============================================
  static const String supabaseUrl = 'https://lqaiataygwlnyyvaoofb.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxxYWlhdGF5Z3dsbnl5dmFvb2ZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMyODg0NDEsImV4cCI6MjEwODg2NDQ0MX0.8j3F3wnPEiT2_t8uD1eA63rYD_DhEr2-iami1Iri_pM';

  // ============================================
  // TABLES (المرحلة 0: الإعدادات الأساسية)
  // ============================================
  static const String tableBranches = 'branches';
  static const String tableDepartments = 'departments';
  static const String tableRoles = 'roles';
  static const String tableUsers = 'users';
  static const String tablePermissions = 'permissions';
  static const String tableSettings = 'settings';
  static const String tableAuditLogs = 'audit_logs';

  // ============================================
  // TABLES (المرحلة 1: الموظفين)
  // ============================================
  static const String tableEmployees = 'employees';
  static const String tableEmployeeDocuments = 'employee_documents';
  static const String tableJobTitles = 'job_titles';
  static const String tableEmployeeSalaries = 'employee_salaries';

  // ============================================
  // TABLES (المرحلة 2: المنتجات)
  // ============================================
  static const String tableProducts = 'products';
  static const String tableProductCategories = 'product_categories';
  static const String tableProductImages = 'product_images';

  // ============================================
  // TABLES (المرحلة 3: المخازن)
  // ============================================
  static const String tableWarehouses = 'warehouses';
  static const String tableInventoryStock = 'inventory_stock';
  static const String tableInventoryTransactions = 'inventory_transactions';

  // ============================================
  // TABLES (المرحلة 4: المبيعات - جاهزة للمستقبل)
  // ============================================
  static const String tableCustomers = 'customers';
  static const String tableInvoices = 'invoices';
  static const String tableInvoiceItems = 'invoice_items';
  static const String tablePayments = 'payments';

  // ============================================
  // STORAGE BUCKETS
  // ============================================
  static const String bucketAvatars = 'avatars';
  static const String bucketEmployeeDocs = 'employee-documents';
  static const String bucketProductImages = 'product-images';

  // ============================================
  // ROLES
  // ============================================
  static const String roleSuperAdmin = 'super_admin';
  static const String roleAdmin = 'admin';
  static const String roleManager = 'manager';
  static const String roleAccountant = 'accountant';
  static const String roleEmployee = 'employee';
  static const String roleViewer = 'viewer';

  // ============================================
  // PAGINATION
  // ============================================
  static const int defaultPageSize = 20;

  // ============================================
  // DATE FORMATS
  // ============================================
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm';

  // ============================================
  // BRANCH DEFAULTS
  // ============================================
  static const String defaultBranchId = '00000000-0000-0000-0000-000000000001';

  // ============================================
  // ROLES UUIDs (Seed Data)
  // ============================================
  static const String roleSuperAdminId = '00000000-0000-0000-0000-000000000101';
  static const String roleAdminId = '00000000-0000-0000-0000-000000000102';
  static const String roleManagerId = '00000000-0000-0000-0000-000000000103';
  static const String roleAccountantId = '00000000-0000-0000-0000-000000000104';
  static const String roleEmployeeId = '00000000-0000-0000-0000-000000000105';
  static const String roleViewerId = '00000000-0000-0000-0000-000000000106';
}
