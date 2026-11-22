import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/shared/app_bar_actions.dart';
import '../../../widgets/shared/app_shell.dart';
import '../widgets/report_card.dart';

class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      currentRoute: '/reports',
      child: Scaffold(
        appBar: AppBar(
          title: Text('reports'.tr()),
          automaticallyImplyLeading: false,
          leading: MediaQuery.of(context).size.width < 900
              ? Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                )
              : null,
          actions: const [AppBarActions()],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Welcome banner ─────────────────────
                  Card(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.analytics_outlined,
                            color: Colors.white,
                            size: 40,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'reports_hub_title'.tr(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'reports_hub_subtitle'.tr(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Sections ──────────────────────────
                  ..._sections.map((s) => _Section(
                        title: s.title.tr(),
                        icon: s.icon,
                        color: s.color,
                        items: s.items,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// Data
// ============================================
class _ReportItem {
  final String titleKey;
  final String descKey;
  final IconData icon;
  final Color color;
  final String route;
  final bool isNew;
  final bool isDisabled;

  const _ReportItem({
    required this.titleKey,
    required this.descKey,
    required this.icon,
    required this.color,
    required this.route,
    this.isNew = false,
    this.isDisabled = false,
  });
}

class _ReportSectionData {
  final String title;
  final IconData icon;
  final Color color;
  final List<_ReportItem> items;

  const _ReportSectionData({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
}

final List<_ReportSectionData> _sections = [
  // ── Financial ─────────────────────────────
  const _ReportSectionData(
    title: 'financial_reports',
    icon: Icons.account_balance_wallet_outlined,
    color: AppColors.primary,
    items: [
      _ReportItem(
        titleKey: 'trial_balance',
        descKey: 'trial_balance_desc',
        icon: Icons.table_chart,
        color: AppColors.info,
        route: '/accounting/reports/trial-balance',
      ),
      _ReportItem(
        titleKey: 'income_statement',
        descKey: 'income_statement_desc',
        icon: Icons.trending_up,
        color: AppColors.success,
        route: '/accounting/reports/income-statement',
      ),
      _ReportItem(
        titleKey: 'balance_sheet',
        descKey: 'balance_sheet_desc',
        icon: Icons.account_balance,
        color: AppColors.warning,
        route: '/accounting/reports/balance-sheet',
      ),
      _ReportItem(
        titleKey: 'cash_flow',
        descKey: 'cash_flow_desc',
        icon: Icons.water_drop_outlined,
        color: AppColors.info,
        route: '/reports/financial/cash-flow',
        isDisabled: true, // ⏸️ بيحتاج إصلاح الأساس
      ),
      _ReportItem(
        titleKey: 'changes_in_equity',
        descKey: 'changes_in_equity_desc',
        icon: Icons.pie_chart_outline,
        color: AppColors.secondary,
        route: '/reports/financial/changes-in-equity',
        isDisabled: true,
      ),
    ],
  ),

  // ── Receivables & Payables ────────────────
  const _ReportSectionData(
    title: 'receivables_payables',
    icon: Icons.receipt_long_outlined,
    color: AppColors.warning,
    items: [
      _ReportItem(
        titleKey: 'ar_aging',
        descKey: 'ar_aging_desc',
        icon: Icons.schedule,
        color: AppColors.error,
        route: '/reports/receivables/ar-aging',
        isNew: true,
      ),
      _ReportItem(
        titleKey: 'customer_statement',
        descKey: 'customer_statement_desc',
        icon: Icons.receipt,
        color: AppColors.info,
        route: '/reports/receivables/customer-statement',
        isNew: true,
      ),
    ],
  ),

  // ── Sales ─────────────────────────────────
  const _ReportSectionData(
    title: 'sales_reports',
    icon: Icons.point_of_sale_outlined,
    color: AppColors.success,
    items: [
      _ReportItem(
        titleKey: 'sales_by_product',
        descKey: 'sales_by_product_desc',
        icon: Icons.inventory_2_outlined,
        color: AppColors.success,
        route: '/reports/sales/by-product',
        isNew: true,
      ),
      _ReportItem(
        titleKey: 'sales_by_customer',
        descKey: 'sales_by_customer_desc',
        icon: Icons.people_outline,
        color: AppColors.info,
        route: '/reports/sales/by-customer',
        isNew: true,
      ),
      _ReportItem(
        titleKey: 'invoice_register',
        descKey: 'invoice_register_desc',
        icon: Icons.list_alt,
        color: AppColors.primary,
        route: '/reports/sales/invoice-register',
        isNew: true,
      ),
    ],
  ),

  // ── Inventory ─────────────────────────────
  const _ReportSectionData(
    title: 'inventory_reports',
    icon: Icons.warehouse_outlined,
    color: AppColors.info,
    items: [
      _ReportItem(
        titleKey: 'stock_valuation',
        descKey: 'stock_valuation_desc',
        icon: Icons.price_change_outlined,
        color: AppColors.success,
        route: '/reports/inventory/valuation',
        isNew: true,
      ),
      _ReportItem(
        titleKey: 'stock_movement',
        descKey: 'stock_movement_desc',
        icon: Icons.swap_horiz,
        color: AppColors.warning,
        route: '/reports/inventory/movement',
        isNew: true,
      ),
      _ReportItem(
        titleKey: 'low_stock',
        descKey: 'low_stock_desc',
        icon: Icons.warning_amber,
        color: AppColors.error,
        route: '/reports/inventory/low-stock',
        isNew: true,
      ),
    ],
  ),
];

// ============================================
// Section widget
// ============================================
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_ReportItem> items;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 1000
                  ? 4
                  : constraints.maxWidth > 700
                      ? 3
                      : constraints.maxWidth > 450
                          ? 2
                          : 1;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final r = items[i];
                  return ReportCard(
                    title: r.titleKey.tr(),
                    description: r.descKey.tr(),
                    icon: r.icon,
                    color: r.color,
                    isNew: r.isNew,
                    isDisabled: r.isDisabled,
                    onTap: r.isDisabled ? null : () => context.push(r.route),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
