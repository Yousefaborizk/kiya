import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class SideMenuItem {
  final String labelKey;
  final IconData icon;
  final String route;
  final List<SideMenuItem> children;

  const SideMenuItem({
    required this.labelKey,
    required this.icon,
    required this.route,
    this.children = const [],
  });
}

class SideMenu extends StatelessWidget {
  final String currentRoute;
  final VoidCallback? onLogout;
  final VoidCallback? onClose;

  const SideMenu({
    super.key,
    required this.currentRoute,
    this.onLogout,
    this.onClose,
  });

  static final List<SideMenuItem> menuItems = [
    const SideMenuItem(
      labelKey: 'dashboard',
      icon: Icons.dashboard_outlined,
      route: '/dashboard',
    ),
    const SideMenuItem(
      labelKey: 'employees',
      icon: Icons.people_outline,
      route: '/employees',
      children: [
        SideMenuItem(
          labelKey: 'employees_list',
          icon: Icons.list_alt,
          route: '/employees',
        ),
        SideMenuItem(
          labelKey: 'job_titles',
          icon: Icons.work_outline,
          route: '/job-titles',
        ),
      ],
    ),
    const SideMenuItem(
      labelKey: 'products',
      icon: Icons.inventory_2_outlined,
      route: '/products',
    ),
    // ── المخازن ──────────────────────────────────
    const SideMenuItem(
      labelKey: 'inventory',
      icon: Icons.warehouse_outlined,
      route: '/inventory',
      children: [
        SideMenuItem(
          labelKey: 'warehouses_title',
          icon: Icons.store_outlined,
          route: '/inventory',
        ),
        SideMenuItem(
          labelKey: 'stock',
          icon: Icons.inventory_outlined,
          route: '/inventory/stock',
        ),
        SideMenuItem(
          labelKey: 'transactions',
          icon: Icons.swap_horiz,
          route: '/inventory/transactions',
        ),
      ],
    ),
    // ── المبيعات ──────────────────────────────────
    const SideMenuItem(
      labelKey: 'sales',
      icon: Icons.point_of_sale_outlined,
      route: '/sales',
      children: [
        SideMenuItem(
          labelKey: 'invoices',
          icon: Icons.receipt_long,
          route: '/sales',
        ),
        SideMenuItem(
          labelKey: 'customers',
          icon: Icons.people_outline,
          route: '/sales/customers',
        ),
      ],
    ),
    const SideMenuItem(
      labelKey: 'accounting',
      icon: Icons.account_balance_wallet_outlined,
      route: '/accounting',
    ),
    const SideMenuItem(
      labelKey: 'reports',
      icon: Icons.analytics_outlined,
      route: '/reports',
    ),
    // ── AI Features ──────────────────────────────
    const SideMenuItem(
      labelKey: 'ai_business_hunter',
      icon: Icons.radar,
      route: '/ai-business-hunter',
    ),
    const SideMenuItem(
      labelKey: 'ai_assistant',
      icon: Icons.auto_awesome,
      route: '/ai-assistant',
    ),
    // ── Settings ─────────────────────────────────
    const SideMenuItem(
      labelKey: 'settings',
      icon: Icons.settings_outlined,
      route: '/settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: AppColors.primary,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.business_center,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'SI EXPORTER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: onClose,
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: menuItems
                    .map((item) => _MenuItemTile(
                          item: item,
                          currentRoute: currentRoute,
                          onClose: onClose,
                        ))
                    .toList(),
              ),
            ),
            if (onLogout != null) ...[
              const Divider(color: Colors.white24, height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white70),
                title: Text(
                  'logout'.tr(),
                  style: const TextStyle(color: Colors.white70),
                ),
                onTap: onLogout,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuItemTile extends StatefulWidget {
  final SideMenuItem item;
  final String currentRoute;
  final VoidCallback? onClose;

  const _MenuItemTile({
    required this.item,
    required this.currentRoute,
    this.onClose,
  });

  @override
  State<_MenuItemTile> createState() => _MenuItemTileState();
}

class _MenuItemTileState extends State<_MenuItemTile> {
  bool _expanded = false;

  bool get _isActive {
    if (widget.item.children.isNotEmpty) {
      return widget.item.children
          .any((c) => widget.currentRoute.startsWith(c.route));
    }
    return widget.currentRoute == widget.item.route ||
        widget.currentRoute.startsWith('${widget.item.route}/');
  }

  @override
  void initState() {
    super.initState();
    _expanded = _isActive;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item.children.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _isActive
              ? AppColors.secondary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Icon(
            widget.item.icon,
            color: _isActive ? AppColors.secondary : Colors.white70,
            size: 22,
          ),
          title: Text(
            widget.item.labelKey.tr(),
            style: TextStyle(
              color: _isActive ? AppColors.secondary : Colors.white70,
              fontWeight: _isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          onTap: () {
            context.go(widget.item.route);
            widget.onClose?.call();
          },
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _isActive
                ? AppColors.secondary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: Icon(
              widget.item.icon,
              color: _isActive ? AppColors.secondary : Colors.white70,
              size: 22,
            ),
            title: Text(
              widget.item.labelKey.tr(),
              style: TextStyle(
                color: _isActive ? AppColors.secondary : Colors.white70,
                fontWeight: _isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            trailing: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white70,
              size: 20,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: widget.item.children
                  .map((child) => _SubItemTile(
                        item: child,
                        currentRoute: widget.currentRoute,
                        onClose: widget.onClose,
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _SubItemTile extends StatelessWidget {
  final SideMenuItem item;
  final String currentRoute;
  final VoidCallback? onClose;

  const _SubItemTile({
    required this.item,
    required this.currentRoute,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentRoute == item.route;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.secondary.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          item.icon,
          color: isActive ? AppColors.secondary : Colors.white60,
          size: 18,
        ),
        title: Text(
          item.labelKey.tr(),
          style: TextStyle(
            color: isActive ? AppColors.secondary : Colors.white60,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        onTap: () {
          context.go(item.route);
          onClose?.call();
        },
      ),
    );
  }
}
