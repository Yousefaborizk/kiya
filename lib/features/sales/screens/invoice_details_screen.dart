import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/payment_model.dart';
import '../providers/sales_provider.dart';

class InvoiceDetailsScreen extends ConsumerStatefulWidget {
  final String invoiceId;

  const InvoiceDetailsScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoiceDetailsScreen> createState() =>
      _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends ConsumerState<InvoiceDetailsScreen> {
  Future<void> _showAddPaymentDialog() async {
    final invoice = ref.read(invoiceByIdProvider(widget.invoiceId)).valueOrNull;
    if (invoice == null) return;

    final remaining = invoice.total - invoice.paidAmount;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الفاتورة مسددة بالكامل')),
      );
      return;
    }

    final amountCtrl = TextEditingController();
    final referenceCtrl = TextEditingController();
    String? method;
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('add_payment'.tr()),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'المتبقي: ${remaining.toStringAsFixed(2)} EGP',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'amount'.tr(),
                    errorText: errorText,
                  ),
                  onChanged: (_) {
                    if (errorText != null) {
                      setDialogState(() => errorText = null);
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: InputDecoration(labelText: 'payment_method'.tr()),
                  items: [
                    DropdownMenuItem(value: 'cash', child: Text('cash'.tr())),
                    DropdownMenuItem(value: 'card', child: Text('card'.tr())),
                    DropdownMenuItem(
                      value: 'bank_transfer',
                      child: Text('bank_transfer'.tr()),
                    ),
                  ],
                  onChanged: (v) => method = v,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: referenceCtrl,
                  decoration: InputDecoration(labelText: 'reference'.tr()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel_btn'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) {
                  setDialogState(() => errorText = 'أدخل مبلغاً صحيحاً');
                  return;
                }
                if (amount > remaining) {
                  setDialogState(
                    () => errorText =
                        'المبلغ أكبر من المتبقي (${remaining.toStringAsFixed(2)})',
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text('save'.tr()),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      try {
        final payment = PaymentModel(
          id: '',
          invoiceId: widget.invoiceId,
          amount: double.parse(amountCtrl.text),
          paymentDate: DateTime.now(),
          paymentMethod: method,
          reference: referenceCtrl.text.trim().isEmpty
              ? null
              : referenceCtrl.text.trim(),
          createdAt: DateTime.now(),
        );
        await ref.read(salesServiceProvider).createPayment(payment);

        // تحديث كل الشاشات المتأثرة بعد الدفعة
        ref.invalidate(invoiceByIdProvider(widget.invoiceId));
        ref.invalidate(paymentsListProvider(widget.invoiceId));
        ref.invalidate(invoicesListProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('payment_added'.tr()),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final msg = e.toString().replaceAll('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceAsync = ref.watch(invoiceByIdProvider(widget.invoiceId));

    return Scaffold(
      appBar: AppBar(
        title: Text('invoice_details'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'refresh'.tr(),
            onPressed: () =>
                ref.invalidate(invoiceByIdProvider(widget.invoiceId)),
          ),
        ],
      ),
      body: invoiceAsync.when(
        data: (invoice) {
          if (invoice == null) {
            return Center(child: Text('invoice_not_found'.tr()));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invoice.invoiceNumber ?? '-',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  invoice.customerName ?? '-',
                                  style: const TextStyle(
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                            _StatusBadge(status: invoice.status),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Items
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'invoice_items'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(height: 24),
                            if (invoice.items != null)
                              ...invoice.items!.map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(item.productName ?? '-'),
                                        Text(
                                          '${item.quantity} x ${item.unitPrice} = ${item.total}',
                                        ),
                                      ],
                                    ),
                                  ))
                            else
                              Text('no_items'.tr()),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Totals
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _TotalRow(
                              label: 'subtotal'.tr(),
                              value: invoice.subtotal.toStringAsFixed(2),
                            ),
                            _TotalRow(
                              label: 'tax'.tr(),
                              value: invoice.tax.toStringAsFixed(2),
                            ),
                            const Divider(),
                            _TotalRow(
                              label: 'total'.tr(),
                              value: invoice.total.toStringAsFixed(2),
                              isBold: true,
                            ),
                            _TotalRow(
                              label: 'paid_amount'.tr(),
                              value: invoice.paidAmount.toStringAsFixed(2),
                            ),
                            _TotalRow(
                              label: 'remaining'.tr(),
                              value: (invoice.total - invoice.paidAmount)
                                  .toStringAsFixed(2),
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Payments
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'payments'.tr(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _showAddPaymentDialog,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: Text('add_payment'.tr()),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _PaymentsList(invoiceId: widget.invoiceId),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('error_label'.tr(args: [e.toString()]))),
      ),
    );
  }
}

class _PaymentsList extends ConsumerWidget {
  final String invoiceId;
  const _PaymentsList({required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsListProvider(invoiceId));

    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return Text('no_payments'.tr());
        }
        return Column(
          children: payments
              .map((p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(Icons.payment, color: AppColors.success),
                    title: Text('${p.amount.toStringAsFixed(2)} EGP'),
                    subtitle: Text(
                        '${p.paymentDate.toIso8601String().split('T').first} • ${p.paymentMethod ?? ''}'),
                  ))
              .toList(),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('error_label'.tr(args: [e.toString()])),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.tr(),
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _TotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: isBold ? 16 : 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: isBold ? 16 : 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: isBold ? AppColors.primary : null)),
        ],
      ),
    );
  }
}
