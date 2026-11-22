import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/sales_service.dart';
import '../models/customer_model.dart';
import '../models/invoice_model.dart';
import '../models/payment_model.dart';

// ============================================
// SERVICE PROVIDER
// ============================================
final salesServiceProvider = Provider<SalesService>((ref) {
  return SalesService();
});

// ============================================
// CUSTOMERS
// ============================================
class CustomerFilter {
  final String search;

  const CustomerFilter({this.search = ''});

  CustomerFilter copyWith({String? search}) {
    return CustomerFilter(search: search ?? this.search);
  }
}

final customerFilterProvider =
    StateProvider<CustomerFilter>((ref) => const CustomerFilter());

/// قائمة كل العملاء (مع فلترة البحث)
final customersListProvider =
    FutureProvider.autoDispose<List<CustomerModel>>((ref) async {
  final filter = ref.watch(customerFilterProvider);
  final service = ref.watch(salesServiceProvider);
  return service.getCustomers(
    search: filter.search.isEmpty ? null : filter.search,
  );
});

/// عميل واحد بالـ id (للـ profile / edit)
final customerByIdProvider =
    FutureProvider.autoDispose.family<CustomerModel?, String>((ref, id) async {
  final service = ref.watch(salesServiceProvider);
  return service.getCustomerById(id);
});

// ============================================
// INVOICES
// ============================================
final invoicesListProvider =
    FutureProvider.autoDispose<List<InvoiceModel>>((ref) async {
  final service = ref.watch(salesServiceProvider);
  return service.getInvoices();
});

final invoiceByIdProvider =
    FutureProvider.autoDispose.family<InvoiceModel?, String>((ref, id) async {
  final service = ref.watch(salesServiceProvider);
  return service.getInvoiceById(id);
});

// ============================================
// PAYMENTS
// ============================================
final paymentsListProvider = FutureProvider.autoDispose
    .family<List<PaymentModel>, String>((ref, invoiceId) async {
  final service = ref.watch(salesServiceProvider);
  return service.getPayments(invoiceId);
});
