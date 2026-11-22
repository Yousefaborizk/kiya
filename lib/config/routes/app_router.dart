import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════
// EXISTING IMPORTS
// ═══════════════════════════════════════════════════════════
import '../../features/accounting/screens/chart_of_accounts_screen.dart';
import '../../features/accounting/screens/journal_entries_list_screen.dart';
import '../../features/accounting/screens/journal_entry_details_screen.dart';
import '../../features/accounting/screens/journal_entry_form_screen.dart';
import '../../features/accounting/screens/reports/balance_sheet_screen.dart';
import '../../features/accounting/screens/reports/income_statement_screen.dart';
import '../../features/accounting/screens/reports/trial_balance_screen.dart';
import '../../features/ai_assistant/screens/ai_assistant_screen.dart';
import '../../features/ai_business_hunter/screens/ai_business_hunter_screen.dart';
import '../../features/inventory/screens/inventory_stock_screen.dart';
import '../../features/inventory/screens/inventory_transaction_form_screen.dart';
import '../../features/inventory/screens/inventory_transactions_screen.dart';
import '../../features/inventory/screens/warehouses_screen.dart';
import '../../features/products/screens/product_details_screen.dart';
import '../../features/products/screens/product_form_screen.dart';
import '../../features/products/screens/products_list_screen.dart';
import '../../features/reports/screens/inventory/low_stock_screen.dart';
import '../../features/reports/screens/inventory/stock_movement_report_screen.dart';
import '../../features/reports/screens/inventory/stock_valuation_screen.dart';
import '../../features/reports/screens/receivables/ar_aging_screen.dart';
import '../../features/reports/screens/receivables/customer_statement_screen.dart';
import '../../features/reports/screens/reports_hub_screen.dart';
import '../../features/reports/screens/sales/invoice_register_screen.dart';
import '../../features/reports/screens/sales/sales_by_customer_screen.dart';
import '../../features/reports/screens/sales/sales_by_product_screen.dart';
import '../../features/sales/screens/customer_form_screen.dart';
import '../../features/sales/screens/customer_profile_screen.dart';
import '../../features/sales/screens/customers_screen.dart';
import '../../features/sales/screens/invoice_details_screen.dart';
import '../../features/sales/screens/invoice_form_screen.dart';
import '../../features/sales/screens/invoices_list_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/employees/employee_form_screen.dart';
import '../../screens/employees/employee_profile_screen.dart';
import '../../screens/employees/employees_list_screen.dart';
import '../../screens/employees/job_titles_screen.dart';

// ✅ Social Media Imports
import '../../features/social_media/screens/social_media_screen.dart';
import '../../features/social_media/screens/whatsapp_inbox_screen.dart';
import '../../features/social_media/screens/admin_dashboard_screen.dart';

// ✅ NEW: Notifications
import '../../features/notifications/screens/notifications_screen.dart';

// ✅ NEW: Facebook
import '../../features/facebook/screens/facebook_inbox_screen.dart';

// ✅ NEW: Activity Tracking
import '../../features/activity/screens/activity_dashboard_screen.dart';

// ═══════════════════════════════════════════════════════════
// SHARED
// ═══════════════════════════════════════════════════════════
import '../../widgets/shared/app_bar_actions.dart';
import '../../widgets/shared/app_shell.dart';
import '../../core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════
// ROUTER PROVIDER
// ═══════════════════════════════════════════════════════════
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<AuthState>(
    AuthState(
      AuthChangeEvent.initialSession,
      Supabase.instance.client.auth.currentSession,
    ),
  );

  final authSubscription =
      Supabase.instance.client.auth.onAuthStateChange.listen((state) {
    authNotifier.value = state;
  });

  ref.onDispose(() {
    authSubscription.cancel();
    authNotifier.dispose();
  });

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;

      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' || location == '/splash';

      // 1. لو مش مسجل دخول ومش في شاشة اللوجين أو السبلاش -> روح للوجين
      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // 2. لو مسجل دخول وعمال يفتح اللوجين أو السبلاش -> روح للداشبورد
      if (isLoggedIn && isAuthRoute) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      // ════════════════════════════════════════════
      // AUTH
      // ════════════════════════════════════════════
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ════════════════════════════════════════════
      // DASHBOARD & ANALYTICS
      // ════════════════════════════════════════════
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/activity-dashboard',
        name: 'activity-dashboard',
        builder: (context, state) => const AppShell(
          currentRoute: '/activity-dashboard',
          child: ActivityDashboardScreen(),
        ),
      ),

      // ════════════════════════════════════════════
      // PROFILE
      // ════════════════════════════════════════════
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const _ComingSoonScreen(
          titleKey: 'nav_profile',
          route: '/profile',
          icon: Icons.person_outline,
        ),
      ),

      // ════════════════════════════════════════════
      // AI FEATURES
      // ════════════════════════════════════════════
      GoRoute(
        path: '/ai-business-hunter',
        name: 'ai-business-hunter',
        builder: (context, state) => const AiBusinessHunterScreen(),
      ),
      GoRoute(
        path: '/ai-assistant',
        name: 'ai-assistant',
        builder: (context, state) => const AiAssistantScreen(),
      ),

      // ════════════════════════════════════════════
      // EMPLOYEES
      // ════════════════════════════════════════════
      GoRoute(
        path: '/employees',
        name: 'employees',
        builder: (context, state) => const EmployeesListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'employee-new',
            builder: (context, state) => const EmployeeFormScreen(),
          ),
          GoRoute(
            path: ':id/edit',
            name: 'employee-edit',
            builder: (context, state) => EmployeeFormScreen(
              employeeId: state.pathParameters['id'],
            ),
          ),
          GoRoute(
            path: ':id',
            name: 'employee-details',
            builder: (context, state) => EmployeeProfileScreen(
              employeeId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: ':id/documents',
            name: 'employee-documents',
            builder: (context, state) => _ComingSoonScreen(
              titleKey: 'nav_employee_documents',
              route: '/employees/${state.pathParameters['id']}/documents',
              icon: Icons.folder_outlined,
            ),
          ),
          GoRoute(
            path: ':id/salaries',
            name: 'employee-salaries',
            builder: (context, state) => _ComingSoonScreen(
              titleKey: 'nav_employee_salaries',
              route: '/employees/${state.pathParameters['id']}/salaries',
              icon: Icons.account_balance_wallet_outlined,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/job-titles',
        name: 'job-titles',
        builder: (context, state) => const JobTitlesScreen(),
      ),

      // ════════════════════════════════════════════
      // DEPARTMENTS & BRANCHES
      // ════════════════════════════════════════════
      GoRoute(
        path: '/departments',
        name: 'departments',
        builder: (context, state) => const _ComingSoonScreen(
          titleKey: 'nav_departments',
          route: '/departments',
          icon: Icons.account_tree_outlined,
        ),
        routes: [
          GoRoute(
            path: 'new',
            name: 'department-new',
            builder: (context, state) => const _ComingSoonScreen(
              titleKey: 'nav_department_new',
              route: '/departments/new',
              icon: Icons.add_business_outlined,
            ),
          ),
          GoRoute(
            path: ':id/edit',
            name: 'department-edit',
            builder: (context, state) => _ComingSoonScreen(
              titleKey: 'nav_department_edit',
              route: '/departments/${state.pathParameters['id']}/edit',
              icon: Icons.edit_outlined,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/branches',
        name: 'branches',
        builder: (context, state) => const _ComingSoonScreen(
          titleKey: 'nav_branches',
          route: '/branches',
          icon: Icons.store_outlined,
        ),
        routes: [
          GoRoute(
            path: 'new',
            name: 'branch-new',
            builder: (context, state) => const _ComingSoonScreen(
              titleKey: 'nav_branch_new',
              route: '/branches/new',
              icon: Icons.add_business_outlined,
            ),
          ),
          GoRoute(
            path: ':id/edit',
            name: 'branch-edit',
            builder: (context, state) => _ComingSoonScreen(
              titleKey: 'nav_branch_edit',
              route: '/branches/${state.pathParameters['id']}/edit',
              icon: Icons.edit_outlined,
            ),
          ),
        ],
      ),

      // ════════════════════════════════════════════
      // PRODUCTS
      // ════════════════════════════════════════════
      GoRoute(
        path: '/products',
        name: 'products',
        builder: (context, state) => const ProductsListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'product-new',
            builder: (context, state) => const ProductFormScreen(),
          ),
          GoRoute(
            path: ':id/edit',
            name: 'product-edit',
            builder: (context, state) => ProductFormScreen(
              productId: state.pathParameters['id'],
            ),
          ),
          GoRoute(
            path: ':id',
            name: 'product-details',
            builder: (context, state) => ProductDetailsScreen(
              productId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'categories',
            name: 'product-categories',
            builder: (context, state) => const _ComingSoonScreen(
              titleKey: 'nav_categories',
              route: '/products/categories',
              icon: Icons.category_outlined,
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'product-category-new',
                builder: (context, state) => const _ComingSoonScreen(
                  titleKey: 'nav_category_new',
                  route: '/products/categories/new',
                  icon: Icons.add_box_outlined,
                ),
              ),
              GoRoute(
                path: ':id/edit',
                name: 'product-category-edit',
                builder: (context, state) => _ComingSoonScreen(
                  titleKey: 'nav_category_edit',
                  route:
                      '/products/categories/${state.pathParameters['id']}/edit',
                  icon: Icons.edit_outlined,
                ),
              ),
            ],
          ),
        ],
      ),

      // ════════════════════════════════════════════
      // INVENTORY
      // ════════════════════════════════════════════
      GoRoute(
        path: '/inventory',
        name: 'inventory',
        builder: (context, state) => const WarehousesScreen(),
      ),
      GoRoute(
        path: '/inventory/stock',
        name: 'inventory-stock',
        builder: (context, state) => const InventoryStockScreen(),
      ),
      GoRoute(
        path: '/inventory/transactions',
        name: 'inventory-transactions',
        builder: (context, state) => const InventoryTransactionsScreen(),
      ),
      GoRoute(
        path: '/inventory/transactions/new',
        name: 'inventory-transaction-new',
        builder: (context, state) => const InventoryTransactionFormScreen(),
      ),

      // ════════════════════════════════════════════
      // SALES
      // ════════════════════════════════════════════
      GoRoute(
        path: '/sales',
        name: 'sales',
        builder: (context, state) => const InvoicesListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'invoice-new',
            builder: (context, state) => const InvoiceFormScreen(),
          ),
          GoRoute(
            path: 'customers',
            name: 'customers',
            builder: (context, state) => const CustomersScreen(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'customer-new',
                builder: (context, state) => const CustomerFormScreen(),
              ),
              GoRoute(
                path: ':id/edit',
                name: 'customer-edit',
                builder: (context, state) => CustomerFormScreen(
                  customerId: state.pathParameters['id'],
                ),
              ),
              GoRoute(
                path: ':id',
                name: 'customer-details',
                builder: (context, state) => CustomerProfileScreen(
                  customerId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: ':id',
            name: 'invoice-details',
            builder: (context, state) => InvoiceDetailsScreen(
              invoiceId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),

      // ════════════════════════════════════════════
      // PAYMENTS & EXPENSES
      // ════════════════════════════════════════════
      GoRoute(
        path: '/payments',
        name: 'payments',
        builder: (context, state) => const _ComingSoonScreen(
          titleKey: 'nav_payments',
          route: '/payments',
          icon: Icons.payments_outlined,
        ),
      ),
      GoRoute(
        path: '/expenses',
        name: 'expenses',
        builder: (context, state) => const _ComingSoonScreen(
          titleKey: 'nav_expenses',
          route: '/expenses',
          icon: Icons.receipt_outlined,
        ),
        routes: [
          GoRoute(
            path: 'new',
            name: 'expense-new',
            builder: (context, state) => const _ComingSoonScreen(
              titleKey: 'nav_expense_new',
              route: '/expenses/new',
              icon: Icons.add_card_outlined,
            ),
          ),
          GoRoute(
            path: ':id/edit',
            name: 'expense-edit',
            builder: (context, state) => _ComingSoonScreen(
              titleKey: 'nav_expense_edit',
              route: '/expenses/${state.pathParameters['id']}/edit',
              icon: Icons.edit_outlined,
            ),
          ),
        ],
      ),

      // ════════════════════════════════════════════
      // ACCOUNTING
      // ════════════════════════════════════════════
      GoRoute(
        path: '/accounting',
        name: 'accounting',
        builder: (context, state) => const ChartOfAccountsScreen(),
        routes: [
          GoRoute(
            path: 'journal',
            name: 'journal',
            builder: (context, state) => const JournalEntriesListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'journal-new',
                builder: (context, state) => const JournalEntryFormScreen(),
              ),
              GoRoute(
                path: ':id',
                name: 'journal-details',
                builder: (context, state) => JournalEntryDetailsScreen(
                  entryId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'reports/trial-balance',
            name: 'trial-balance',
            builder: (context, state) => const TrialBalanceScreen(),
          ),
          GoRoute(
            path: 'reports/income-statement',
            name: 'income-statement',
            builder: (context, state) => const IncomeStatementScreen(),
          ),
          GoRoute(
            path: 'reports/balance-sheet',
            name: 'balance-sheet',
            builder: (context, state) => const BalanceSheetScreen(),
          ),
        ],
      ),

      // ════════════════════════════════════════════
      // REPORTS HUB
      // ════════════════════════════════════════════
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsHubScreen(),
        routes: [
          GoRoute(
            path: 'receivables/ar-aging',
            name: 'ar-aging',
            builder: (context, state) => const ArAgingScreen(),
          ),
          GoRoute(
            path: 'receivables/customer-statement',
            name: 'customer-statement',
            builder: (context, state) => const CustomerStatementScreen(),
          ),
          GoRoute(
            path: 'sales/by-product',
            name: 'sales-by-product',
            builder: (context, state) => const SalesByProductScreen(),
          ),
          GoRoute(
            path: 'sales/by-customer',
            name: 'sales-by-customer',
            builder: (context, state) => const SalesByCustomerScreen(),
          ),
          GoRoute(
            path: 'sales/invoice-register',
            name: 'invoice-register',
            builder: (context, state) => const InvoiceRegisterScreen(),
          ),
          GoRoute(
            path: 'inventory/low-stock',
            name: 'low-stock',
            builder: (context, state) => const LowStockScreen(),
          ),
          GoRoute(
            path: 'inventory/valuation',
            name: 'stock-valuation',
            builder: (context, state) => const StockValuationScreen(),
          ),
          GoRoute(
            path: 'inventory/movement',
            name: 'stock-movement',
            builder: (context, state) => const StockMovementReportScreen(),
          ),
        ],
      ),

      // ════════════════════════════════════════════
      // ✅ SOCIAL MEDIA & WHATSAPP & FACEBOOK
      // ════════════════════════════════════════════
      GoRoute(
        path: '/social-media',
        name: 'social-media',
        builder: (context, state) => const SocialMediaScreen(),
      ),
      GoRoute(
        path: '/whatsapp-inbox',
        name: 'whatsapp-inbox',
        builder: (context, state) => const AppShell(
          currentRoute: '/whatsapp-inbox',
          child: WhatsAppInboxScreen(),
        ),
      ),
      GoRoute(
        path: '/facebook-inbox',
        name: 'facebook-inbox',
        builder: (context, state) => const AppShell(
          currentRoute: '/facebook-inbox',
          child: FacebookInboxScreen(),
        ),
      ),
      GoRoute(
        path: '/whatsapp-admin',
        name: 'whatsapp-admin',
        builder: (context, state) => const AppShell(
          currentRoute: '/whatsapp-admin',
          child: AdminDashboardScreen(),
        ),
      ),

      // ════════════════════════════════════════════
      // ➕ ADMIN / SETTINGS
      // ════════════════════════════════════════════
      GoRoute(
        path: '/users',
        name: 'users',
        builder: (context, state) => const _ComingSoonScreen(
          titleKey: 'nav_users',
          route: '/users',
          icon: Icons.manage_accounts_outlined,
        ),
        routes: [
          GoRoute(
            path: 'new',
            name: 'user-new',
            builder: (context, state) => const _ComingSoonScreen(
              titleKey: 'nav_user_new',
              route: '/users/new',
              icon: Icons.person_add_outlined,
            ),
          ),
          GoRoute(
            path: ':id/edit',
            name: 'user-edit',
            builder: (context, state) => _ComingSoonScreen(
              titleKey: 'nav_user_edit',
              route: '/users/${state.pathParameters['id']}/edit',
              icon: Icons.manage_accounts_outlined,
            ),
          ),
          GoRoute(
            path: ':id',
            name: 'user-details',
            builder: (context, state) => _ComingSoonScreen(
              titleKey: 'nav_user_details',
              route: '/users/${state.pathParameters['id']}',
              icon: Icons.person_outline,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/roles',
        name: 'roles',
        builder: (context, state) => const _ComingSoonScreen(
          titleKey: 'nav_roles',
          route: '/roles',
          icon: Icons.security_outlined,
        ),
        routes: [
          GoRoute(
            path: ':id/permissions',
            name: 'role-permissions',
            builder: (context, state) => _ComingSoonScreen(
              titleKey: 'nav_role_permissions',
              route: '/roles/${state.pathParameters['id']}/permissions',
              icon: Icons.lock_outline,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const _ComingSoonScreen(
          titleKey: 'nav_settings',
          route: '/settings',
          icon: Icons.settings_outlined,
        ),
      ),
      GoRoute(
        path: '/audit-logs',
        name: 'audit-logs',
        builder: (context, state) => const _ComingSoonScreen(
          titleKey: 'nav_audit_logs',
          route: '/audit-logs',
          icon: Icons.history,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'page_not_found'.tr(args: [state.matchedLocation]),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );
});

// ═══════════════════════════════════════════════════════════
// PLACEHOLDER SCREEN (Coming Soon)
// ═══════════════════════════════════════════════════════════
class _ComingSoonScreen extends StatelessWidget {
  final String titleKey;
  final String route;
  final IconData icon;

  const _ComingSoonScreen({
    required this.titleKey,
    required this.route,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return AppShell(
      currentRoute: route,
      child: Scaffold(
        appBar: AppBar(
          title: Text(titleKey.tr()),
          automaticallyImplyLeading: false,
          leading: isMobile
              ? Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                )
              : null,
          actions: const [AppBarActions()],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 64, color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                Text(
                  titleKey.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'coming_soon_message'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => context.go('/dashboard'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: Text('nav_dashboard'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
