import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/shared/app_bar_actions.dart';
import '../../../widgets/shared/app_shell.dart';
import '../models/invoice_model.dart';
import '../providers/sales_provider.dart';

class InvoicesListScreen extends ConsumerWidget {
  const InvoicesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesListProvider);

    return AppShell(
      currentRoute: '/sales',
      child: Scaffold(
        appBar: AppBar(
          title: Text('invoices'.tr()),
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
              icon: const Icon(Icons.refresh),
              tooltip: 'refresh'.tr(),
              onPressed: () => ref.invalidate(invoicesListProvider),
            ),
            const AppBarActions(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/sales/new'),
          icon: const Icon(Icons.add),
          label: Text('add_invoice'.tr()),
        ),
        body: invoicesAsync.when(
          data: (invoices) {
            if (invoices.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.receipt_long_outlined,
                title: 'no_invoices'.tr(),
                subtitle: 'no_invoices_subtitle'.tr(),
                actionLabel: 'add_invoice'.tr(),
                onAction: () => context.push('/sales/new'),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: invoices.length,
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                return _InvoiceCard(invoice: invoice);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('error_label'.tr(args: [e.toString()]))),
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  const _InvoiceCard({required this.invoice});

  Color _statusColor() {
    switch (invoice.status) {
      case 'paid':
        return AppColors.success;
      case 'partially_paid':
        return AppColors.warning;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  String _statusLabel() {
    switch (invoice.status) {
      case 'draft':
        return 'status_draft'.tr();
      case 'issued':
        return 'status_issued'.tr();
      case 'paid':
        return 'status_paid'.tr();
      case 'partially_paid':
        return 'status_partially_paid'.tr();
      case 'cancelled':
        return 'status_cancelled'.tr();
      default:
        return invoice.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _statusColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.receipt_long, color: _statusColor()),
        ),
        title: Text(
          invoice.invoiceNumber ?? '-',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (invoice.customerName != null) Text(invoice.customerName!),
            Text(
              '${invoice.total.toStringAsFixed(2)} EGP',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _statusLabel(),
            style: TextStyle(
              color: _statusColor(),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => context.push('/sales/${invoice.id}'),
      ),
    );
  }
}
