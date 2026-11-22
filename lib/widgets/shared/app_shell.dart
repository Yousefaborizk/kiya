import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final String currentRoute;

  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    if (isMobile) {
      return Scaffold(
        drawer: Drawer(
          child: AppSidebar(currentRoute: currentRoute, isMobile: true),
        ),
        body: child,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // في الـ RTL هيتحط على اليمين تلقائيًا
          AppSidebar(currentRoute: currentRoute, isMobile: false),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class AppSidebar extends StatelessWidget {
  final String currentRoute;
  final bool isMobile;

  const AppSidebar({
    super.key,
    required this.currentRoute,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: AppColors.primary, // كحلي غامق
      child: Column(
        children: [
          // ── الهيدر (الشعار) ─────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary, // ذهبي
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.work_outline,
                          color: Colors.black, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'SI EXPORTER',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                if (isMobile)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // ── عناصر القائمة ─────────────────────────
          Expanded(
            child: Scrollbar(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _NavItem(
                    titleKey: 'nav_dashboard',
                    icon: Icons.dashboard_outlined,
                    route: '/dashboard',
                    currentRoute: currentRoute,
                    isMobile: isMobile,
                  ),
                  _ExpandableNavItem(
                    titleKey: 'nav_employees',
                    icon: Icons.people_outline,
                    currentRoute: currentRoute,
                    isMobile: isMobile,
                    subItems: const [
                      _SubItem(
                          titleKey: 'nav_employees_list', route: '/employees'),
                      _SubItem(
                          titleKey: 'nav_job_titles', route: '/job-titles'),
                    ],
                  ),
                  _NavItem(
                    titleKey: 'nav_products',
                    icon: Icons.inventory_2_outlined,
                    route: '/products',
                    currentRoute: currentRoute,
                    isMobile: isMobile,
                  ),
                  _ExpandableNavItem(
                    titleKey: 'nav_inventory',
                    icon: Icons.warehouse_outlined,
                    currentRoute: currentRoute,
                    isMobile: isMobile,
                    subItems: const [
                      _SubItem(titleKey: 'nav_warehouses', route: '/inventory'),
                      _SubItem(
                          titleKey: 'nav_stock', route: '/inventory/stock'),
                      _SubItem(
                          titleKey: 'nav_transactions',
                          route: '/inventory/transactions'),
                    ],
                  ),
                  _ExpandableNavItem(
                    titleKey: 'nav_sales',
                    icon: Icons.point_of_sale_outlined,
                    currentRoute: currentRoute,
                    isMobile: isMobile,
                    subItems: const [
                      _SubItem(titleKey: 'nav_invoices', route: '/sales'),
                      _SubItem(
                          titleKey: 'nav_customers', route: '/sales/customers'),
                    ],
                  ),
                  _NavItem(
                    titleKey: 'nav_accounting',
                    icon: Icons.calculate_outlined,
                    route: '/accounting',
                    currentRoute: currentRoute,
                    isMobile: isMobile,
                  ),
                  _NavItem(
                    titleKey: 'nav_reports',
                    icon: Icons.bar_chart_outlined,
                    route: '/reports',
                    currentRoute: currentRoute,
                    isMobile: isMobile,
                  ),
                  _NavItem(
                    titleKey: 'ai_business_hunter',
                    icon: Icons.track_changes,
                    route: '/ai-business-hunter',
                    currentRoute: currentRoute,
                    isMobile: isMobile,
                  ),
                  _NavItem(
                    titleKey: 'ai_assistant',
                    icon: Icons.auto_awesome,
                    route: '/ai-assistant',
                    currentRoute: currentRoute,
                    isMobile: isMobile,
                  ),

                  // ✅ Social Media Item
                  _NavItem(
                    titleKey: 'nav_social_media',
                    icon: Icons.forum_outlined,
                    route: '/social-media',
                    currentRoute: currentRoute,
                    isMobile: isMobile,
                  ),

                  // ✅ WhatsApp Admin Item
                  _NavItem(
                    titleKey: 'whatsapp_admin',
                    icon: Icons.admin_panel_settings_outlined,
                    route: '/whatsapp-admin',
                    currentRoute: currentRoute,
                    isMobile: isMobile,
                  ),

                  _NavItem(
                    titleKey: 'nav_settings',
                    icon: Icons.settings_outlined,
                    route: '/settings',
                    currentRoute: currentRoute,
                    isMobile: isMobile,
                  ),
                ],
              ),
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // ── تسجيل الخروج ─────────────────────────
          InkWell(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('logout'.tr()),
                  content: Text('logout_confirm'.tr()),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('cancel'.tr()),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('logout'.tr(),
                          style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await Supabase.instance.client.auth.signOut();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  const Icon(Icons.logout, color: Colors.white70, size: 20),
                  const SizedBox(width: 16),
                  Text(
                    'logout'.tr(),
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Custom Widgets
// ═══════════════════════════════════════════════════════════

class _NavItem extends StatelessWidget {
  final String titleKey;
  final IconData icon;
  final String route;
  final String currentRoute;
  final bool isMobile;

  const _NavItem({
    required this.titleKey,
    required this.icon,
    required this.route,
    required this.currentRoute,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentRoute == route || currentRoute == '$route/';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isMobile) Navigator.pop(context);
            context.go(route);
          },
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? const Border(
                      right: BorderSide(color: AppColors.secondary, width: 3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? AppColors.secondary : Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    titleKey.tr(),
                    style: TextStyle(
                      color: isActive ? AppColors.secondary : Colors.white70,
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubItem {
  final String titleKey;
  final String route;
  const _SubItem({required this.titleKey, required this.route});
}

class _ExpandableNavItem extends StatefulWidget {
  final String titleKey;
  final IconData icon;
  final String currentRoute;
  final bool isMobile;
  final List<_SubItem> subItems;

  const _ExpandableNavItem({
    required this.titleKey,
    required this.icon,
    required this.currentRoute,
    required this.isMobile,
    required this.subItems,
  });

  @override
  State<_ExpandableNavItem> createState() => _ExpandableNavItemState();
}

class _ExpandableNavItemState extends State<_ExpandableNavItem> {
  bool _isExpanded = false;

  bool get _hasActiveChild => widget.subItems.any(
        (sub) =>
            widget.currentRoute == sub.route ||
            widget.currentRoute.startsWith('${sub.route}/'),
      );

  @override
  void initState() {
    super.initState();
    _isExpanded = _hasActiveChild;
  }

  @override
  void didUpdateWidget(covariant _ExpandableNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentRoute != oldWidget.currentRoute && _hasActiveChild) {
      setState(() => _isExpanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnyChildActive = _hasActiveChild;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(8),
              hoverColor: Colors.white.withValues(alpha: 0.05),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      color: isAnyChildActive
                          ? AppColors.secondary
                          : Colors.white70,
                      size: 22,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.titleKey.tr(),
                        style: TextStyle(
                          color: isAnyChildActive
                              ? AppColors.secondary
                              : Colors.white70,
                          fontSize: 14,
                          fontWeight: isAnyChildActive
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _isExpanded
              ? Padding(
                  padding:
                      const EdgeInsets.only(right: 36, left: 12, bottom: 8),
                  child: Column(
                    children: widget.subItems.map((sub) {
                      final isSubActive = widget.currentRoute == sub.route;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (widget.isMobile) Navigator.pop(context);
                            context.go(sub.route);
                          },
                          borderRadius: BorderRadius.circular(8),
                          hoverColor: Colors.white.withValues(alpha: 0.05),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Text(
                              sub.titleKey.tr(),
                              style: TextStyle(
                                color: isSubActive
                                    ? AppColors.secondary
                                    : Colors.white54,
                                fontSize: 13,
                                fontWeight: isSubActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
