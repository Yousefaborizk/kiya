import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/shared/app_bar_actions.dart';
import '../../../widgets/shared/app_shell.dart';
import '../models/customer_model.dart';
import '../providers/sales_provider.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersListProvider);

    return AppShell(
      currentRoute: '/sales/customers',
      child: Scaffold(
        appBar: AppBar(
          title: _showSearch
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'search_customer_hint'.tr(),
                    hintStyle: const TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    ref.read(customerFilterProvider.notifier).state = ref
                        .read(customerFilterProvider)
                        .copyWith(search: value);
                  },
                )
              : Text('customers'.tr()),
          automaticallyImplyLeading: false,
          leading: MediaQuery.of(context).size.width < 900
              ? Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                )
              : null,
          actions: [
            IconButton(
              icon: Icon(_showSearch ? Icons.close : Icons.search),
              tooltip: 'search'.tr(),
              onPressed: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchController.clear();
                    ref.read(customerFilterProvider.notifier).state =
                        ref.read(customerFilterProvider).copyWith(search: '');
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'refresh'.tr(),
              onPressed: () => ref.invalidate(customersListProvider),
            ),
            const AppBarActions(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/sales/customers/new'),
          icon: const Icon(Icons.person_add),
          label: Text('add_customer'.tr()),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(customersListProvider);
          },
          child: customersAsync.when(
            data: (customers) {
              if (customers.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.people_outline,
                  title: 'no_customers'.tr(),
                  subtitle: 'no_customers_subtitle'.tr(),
                  actionLabel: 'add_customer'.tr(),
                  onAction: () => context.push('/sales/customers/new'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: customers.length,
                itemBuilder: (context, index) {
                  final customer = customers[index];
                  return _CustomerCard(
                    customer: customer,
                    onTap: () =>
                        context.push('/sales/customers/${customer.id}'),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 12),
                  // هنا حطينا الإيرور الحقيقي بدل ما نستخدم الترجمة عشان نعرف إيه المشكلة
                  Text('خطأ: $e'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(customersListProvider),
                    child: Text('retry'.tr()),
                  ),
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
// Customer Card
// ============================================
class _CustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onTap;

  const _CustomerCard({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String? primaryPhone;
    if (customer.phones.isNotEmpty) {
      final primary = customer.phones.firstWhere(
        (p) => p.isPrimary,
        orElse: () => customer.phones.first,
      );
      if (primary.number.isNotEmpty) primaryPhone = primary.number;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _TypeBadge(type: customer.customerType),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.customerCode ?? '-',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    if (primaryPhone != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            size: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            primaryPhone,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (customer.rating > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < customer.rating
                                ? Icons.star
                                : Icons.star_border,
                            color: AppColors.secondary,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// Type Badge
// ============================================
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  Color get _color {
    switch (type) {
      case 'company':
        return AppColors.info;
      case 'distributor':
        return AppColors.secondary;
      case 'agent':
        return AppColors.warning;
      case 'government':
        return AppColors.primary;
      default:
        return AppColors.textSecondaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'type_$type'.tr(),
        style: TextStyle(
          color: _color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
