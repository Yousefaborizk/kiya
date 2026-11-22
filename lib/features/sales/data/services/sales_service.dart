import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../models/customer_model.dart';
import '../../models/invoice_item_model.dart';
import '../../models/invoice_model.dart';
import '../../models/payment_model.dart';

class SalesService {
  final SupabaseClient _client = Supabase.instance.client;

  // ============================================
  // CUSTOMERS
  // ============================================
  Future<List<CustomerModel>> getCustomers({String? search}) async {
    var query = _client.from(AppConstants.tableCustomers).select();
    if (search != null && search.isNotEmpty) {
      query = query.or(
        'name.ilike.%$search%,customer_code.ilike.%$search%,'
        'phone.ilike.%$search%,email.ilike.%$search%,'
        'legal_name.ilike.%$search%',
      );
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List)
        .map((e) => CustomerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerModel?> getCustomerById(String id) async {
    final data = await _client
        .from(AppConstants.tableCustomers)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return CustomerModel.fromJson(data);
  }

  Future<CustomerModel> createCustomer(CustomerModel customer) async {
    try {
      final payload = customer.toJson();
      debugPrint('INSERT CUSTOMER PAYLOAD: $payload');

      final data = await _client
          .from(AppConstants.tableCustomers)
          .insert(payload)
          .select()
          .single();
      return CustomerModel.fromJson(data);
    } catch (e) {
      debugPrint('CREATE CUSTOMER ERROR: $e');
      rethrow;
    }
  }

  Future<CustomerModel> updateCustomer(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final data = await _client
        .from(AppConstants.tableCustomers)
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return CustomerModel.fromJson(data);
  }

  Future<void> deleteCustomer(String id) async {
    await _client
        .from(AppConstants.tableCustomers)
        .update({'is_active': false}).eq('id', id);
  }

  // ============================================
  // INVOICES
  // ============================================
  Future<List<InvoiceModel>> getInvoices() async {
    final data = await _client
        .from(AppConstants.tableInvoices)
        .select('*, customers(name)')
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => InvoiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InvoiceModel?> getInvoiceById(String id) async {
    final data = await _client
        .from(AppConstants.tableInvoices)
        .select(
            '*, customers(name), invoice_items(*, products(name), warehouses(name))')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return InvoiceModel.fromJson(data);
  }

  /// إنشاء فاتورة + بنودها في transaction واحدة على مستوى الداتابيز.
  /// لو أي بند فشل (مثلاً المخزون غير كافٍ) → الفاتورة والبنود كلها هتترجع.
  /// الإخصام من المخزون بيحصل تلقائياً عن طريق الـ trigger.
  Future<void> createInvoice(
    InvoiceModel invoice,
    List<InvoiceItemModel> items,
  ) async {
    try {
      final invoicePayload = invoice.toJson();
      debugPrint('INVOICE PAYLOAD: $invoicePayload');

      final itemsPayload = items
          .map((item) => {
                'product_id': item.productId,
                'warehouse_id': item.warehouseId,
                'quantity': item.quantity,
                'unit_price': item.unitPrice,
                'discount': item.discount,
                'total': item.total,
              })
          .toList();

      await _client.rpc('create_invoice_with_items', params: {
        'p_invoice': invoicePayload,
        'p_items': itemsPayload,
      });

      debugPrint('INVOICE CREATED SUCCESSFULLY');
    } on PostgrestException catch (e) {
      debugPrint('========================================');
      debugPrint('POSTGRES ERROR CODE: ${e.code}');
      debugPrint('POSTGRES ERROR MESSAGE: ${e.message}');
      debugPrint('POSTGRES ERROR DETAILS: ${e.details}');
      debugPrint('POSTGRES ERROR HINT: ${e.hint}');
      debugPrint('========================================');

      // P0001 = RAISE EXCEPTION من trigger الداتابيز
      if (e.code == 'P0001' || e.message.contains('الكمية غير كافية')) {
        throw Exception(e.message);
      }

      // 23514 = check constraint (quantity >= 0)
      if (e.code == '23514') {
        throw Exception(
          'المخزون غير كافٍ لهذا المنتج في المخزن المختار. '
          'راجع الرصيد أو أضف حركة وارد (in) أولاً.',
        );
      }

      // 23505 = unique violation
      if (e.code == '23505') {
        if (e.message.contains('invoice_number')) {
          throw Exception('رقم الفاتورة مستخدم بالفعل. أعد المحاولة.');
        }
        throw Exception('بيانات مكررة: ${e.details ?? e.message}');
      }

      // 23503 = foreign key
      if (e.code == '23503') {
        throw Exception('مرجع غير موجود (منتج أو مخزن أو عميل).');
      }

      // 23502 = not null
      if (e.code == '23502') {
        throw Exception('حقل مطلوب ناقص: ${e.details ?? e.message}');
      }

      // 42883 = function not found (لو نسيت تعمل RPC)
      if (e.code == '42883') {
        throw Exception(
          'دالة create_invoice_with_items غير موجودة. راجع إعدادات الداتابيز.',
        );
      }

      throw Exception(e.message);
    } catch (e) {
      debugPrint('CREATE INVOICE ERROR: $e');
      rethrow;
    }
  }

  Future<void> updateInvoiceStatus(
    String id,
    String status, {
    double? paidAmount,
  }) async {
    final updates = <String, dynamic>{'status': status};
    if (paidAmount != null) {
      updates['paid_amount'] = paidAmount;
    }
    await _client.from(AppConstants.tableInvoices).update(updates).eq('id', id);
  }

  // ============================================
  // PAYMENTS
  // ============================================
  Future<List<PaymentModel>> getPayments(String invoiceId) async {
    final data = await _client
        .from(AppConstants.tablePayments)
        .select()
        .eq('invoice_id', invoiceId)
        .order('payment_date', ascending: false);
    return (data as List)
        .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createPayment(PaymentModel payment) async {
    if (payment.amount <= 0) {
      throw Exception('قيمة الدفعة يجب أن تكون أكبر من صفر');
    }

    try {
      await _client.rpc(
        'create_payment_atomic',
        params: {
          'p_invoice_id': payment.invoiceId,
          'p_amount': payment.amount,
          'p_payment_method': payment.paymentMethod,
          'p_reference': payment.reference,
          'p_notes': payment.notes,
        },
      );
      debugPrint('PAYMENT CREATED SUCCESSFULLY');
    } on PostgrestException catch (e) {
      debugPrint('CREATE PAYMENT PG ERROR: ${e.code} - ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('CREATE PAYMENT ERROR: $e');
      rethrow;
    }
  }
}
