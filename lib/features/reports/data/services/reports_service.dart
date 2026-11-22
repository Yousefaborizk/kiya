import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../sales/models/customer_model.dart';
import '../models/ar_aging_model.dart';
import '../models/customer_statement_model.dart';
import '../models/invoice_register_model.dart';
import '../models/low_stock_model.dart';
import '../models/sales_by_customer_model.dart';
import '../models/sales_by_product_model.dart';
import '../models/stock_movement_model.dart';
import '../models/stock_valuation_model.dart';

class ReportsService {
  final SupabaseClient _client = Supabase.instance.client;

  // ============================================
  // CUSTOMER STATEMENT
  // ============================================
  Future<CustomerStatementModel> getCustomerStatement({
    required String customerId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final fromStr = _fmt(fromDate);
      final toStr = _fmt(toDate);

      final customerData = await _client
          .from('customers')
          .select()
          .eq('id', customerId)
          .single();
      final customer = CustomerModel.fromJson(customerData);

      final openingInvoices = await _client
          .from('invoices')
          .select('total')
          .eq('customer_id', customerId)
          .neq('status', 'cancelled')
          .lt('invoice_date', fromStr);

      final openingPayments = await _client
          .from('payments')
          .select('amount, invoices!inner(customer_id, status)')
          .eq('invoices.customer_id', customerId)
          .neq('invoices.status', 'cancelled')
          .lt('payment_date', fromStr);

      final openingInvoiceTotal = (openingInvoices as List).fold<double>(
        0,
        (s, e) => s + ((e['total'] as num?)?.toDouble() ?? 0),
      );
      final openingPaymentTotal = (openingPayments as List).fold<double>(
        0,
        (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0),
      );
      final openingBalance = openingInvoiceTotal - openingPaymentTotal;

      final invoicesData = await _client
          .from('invoices')
          .select()
          .eq('customer_id', customerId)
          .neq('status', 'cancelled')
          .gte('invoice_date', fromStr)
          .lte('invoice_date', toStr)
          .order('invoice_date');

      final paymentsData = await _client
          .from('payments')
          .select('*, invoices!inner(customer_id, invoice_number, status)')
          .eq('invoices.customer_id', customerId)
          .neq('invoices.status', 'cancelled')
          .gte('payment_date', fromStr)
          .lte('payment_date', toStr)
          .order('payment_date');

      final paymentsByInvoice = <String, double>{};
      for (final p in (paymentsData as List)) {
        final invId = p['invoice_id'] as String;
        paymentsByInvoice[invId] =
            (paymentsByInvoice[invId] ?? 0) + ((p['amount'] as num).toDouble());
      }

      final rawLines = <CustomerStatementLine>[];
      int invoiceCount = 0;

      for (final inv in (invoicesData as List)) {
        final invId = inv['id'] as String;
        final invNum = inv['invoice_number'] as String;
        final invDate = DateTime.parse(inv['invoice_date'] as String);
        final invTotal = (inv['total'] as num?)?.toDouble() ?? 0;
        final invPaid = (inv['paid_amount'] as num?)?.toDouble() ?? 0;
        final notes = inv['notes'] as String?;

        if (invTotal > 0.001) {
          rawLines.add(CustomerStatementLine(
            date: invDate,
            type: StatementLineType.invoice,
            documentNumber: invNum,
            description: notes,
            debit: invTotal,
            referenceId: invId,
          ));
          invoiceCount++;
        }

        final paidViaPayments = paymentsByInvoice[invId] ?? 0;
        final gap = invPaid - paidViaPayments;
        if (gap > 0.01) {
          rawLines.add(CustomerStatementLine(
            date: invDate,
            type: StatementLineType.payment,
            documentNumber: invNum,
            description: 'paid_at_creation',
            credit: gap,
            referenceId: invId,
          ));
        }
      }

      for (final p in (paymentsData as List)) {
        final amount = (p['amount'] as num).toDouble();
        if (amount <= 0.001) continue;
        final invData = p['invoices'] as Map<String, dynamic>?;
        rawLines.add(CustomerStatementLine(
          date: DateTime.parse(p['payment_date'] as String),
          type: StatementLineType.payment,
          documentNumber: p['reference'] as String? ??
              (invData?['invoice_number'] as String? ?? '-'),
          description: p['notes'] as String?,
          credit: amount,
          referenceId: p['id'] as String,
        ));
      }

      rawLines.sort((a, b) {
        final c = a.date.compareTo(b.date);
        if (c != 0) return c;
        if (a.type == StatementLineType.invoice &&
            b.type == StatementLineType.payment) {
          return -1;
        }
        if (a.type == StatementLineType.payment &&
            b.type == StatementLineType.invoice) {
          return 1;
        }
        return a.documentNumber.compareTo(b.documentNumber);
      });

      double running = openingBalance;
      final lines = <CustomerStatementLine>[];
      double totalDebits = 0;
      double totalCredits = 0;
      for (final l in rawLines) {
        running += l.debit - l.credit;
        totalDebits += l.debit;
        totalCredits += l.credit;
        lines.add(CustomerStatementLine(
          date: l.date,
          type: l.type,
          documentNumber: l.documentNumber,
          description: l.description,
          debit: l.debit,
          credit: l.credit,
          runningBalance: running,
          referenceId: l.referenceId,
        ));
      }

      return CustomerStatementModel(
        customer: customer,
        fromDate: fromDate,
        toDate: toDate,
        openingBalance: openingBalance,
        totalDebits: totalDebits,
        totalCredits: totalCredits,
        closingBalance: running,
        invoiceCount: invoiceCount,
        paymentCount: (paymentsData as List).length,
        lines: lines,
      );
    } on PostgrestException catch (e) {
      debugPrint('CUSTOMER STATEMENT PG ERROR: ${e.code} - ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('CUSTOMER STATEMENT ERROR: $e');
      rethrow;
    }
  }

  // ============================================
  // AR AGING
  // ============================================
  Future<ArAgingModel> getArAging({
    required DateTime asOfDate,
    String? customerId,
  }) async {
    try {
      final asOfStr = _fmt(asOfDate);

      var invQuery = _client
          .from('invoices')
          .select(
            'id, invoice_number, invoice_date, due_date, total, paid_amount, '
            'customer_id, customers(id, customer_code, name, phone)',
          )
          .inFilter('status', ['issued', 'paid', 'partially_paid']).lte(
              'invoice_date', asOfStr);

      if (customerId != null) {
        invQuery = invQuery.eq('customer_id', customerId);
      }

      final invoicesData = await invQuery.order('invoice_date');
      final invoices = List<Map<String, dynamic>>.from(invoicesData);

      if (invoices.isEmpty) {
        return ArAgingModel.fromRows(asOfDate, const []);
      }

      final invoiceIds = invoices.map((e) => e['id'] as String).toList();

      final paymentsData = await _client
          .from('payments')
          .select('invoice_id, amount, payment_date')
          .inFilter('invoice_id', invoiceIds);

      final paidAllMap = <String, double>{};
      final paidAsOfMap = <String, double>{};

      for (final p in (paymentsData as List)) {
        final invId = p['invoice_id'] as String;
        final amt = (p['amount'] as num?)?.toDouble() ?? 0;
        final pDate = DateTime.parse(p['payment_date'] as String);

        paidAllMap[invId] = (paidAllMap[invId] ?? 0) + amt;
        if (!pDate.isAfter(asOfDate)) {
          paidAsOfMap[invId] = (paidAsOfMap[invId] ?? 0) + amt;
        }
      }

      final Map<String, _ArAgingAccumulator> acc = {};

      for (final inv in invoices) {
        final invId = inv['id'] as String;
        final total = (inv['total'] as num?)?.toDouble() ?? 0;
        if (total <= 0.001) continue;

        final paidOnInvoice = (inv['paid_amount'] as num?)?.toDouble() ?? 0;
        final paidViaPaymentsAll = paidAllMap[invId] ?? 0;
        final paidViaPaymentsAsOf = paidAsOfMap[invId] ?? 0;

        final implicitGap =
            (paidOnInvoice - paidViaPaymentsAll).clamp(0.0, double.infinity);

        final paidAsOf = paidViaPaymentsAsOf + implicitGap;
        final outstanding = (total - paidAsOf).clamp(0.0, double.infinity);

        if (outstanding <= 0.001) continue;

        final dueStr = inv['due_date'] as String?;
        final refDate = dueStr != null
            ? DateTime.parse(dueStr)
            : DateTime.parse(inv['invoice_date'] as String);

        final daysOverdue = asOfDate.difference(refDate).inDays;

        final cust = inv['customers'] as Map<String, dynamic>?;
        if (cust == null) continue;
        final custId = cust['id'] as String;

        final accEntry = acc.putIfAbsent(
          custId,
          () => _ArAgingAccumulator(
            customerId: custId,
            customerCode: cust['customer_code'] as String?,
            customerName: cust['name'] as String,
            phone: cust['phone'] as String?,
          ),
        );
        accEntry.addInvoice(outstanding, daysOverdue, refDate);
      }

      final rows = acc.values.map((a) => a.build()).toList()
        ..sort((a, b) => b.totalOutstanding.compareTo(a.totalOutstanding));

      return ArAgingModel.fromRows(asOfDate, rows);
    } on PostgrestException catch (e) {
      debugPrint('AR AGING PG ERROR: ${e.code} - ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('AR AGING ERROR: $e');
      rethrow;
    }
  }

  // ============================================
  // SALES BY PRODUCT
  // ============================================
  Future<SalesByProductModel> getSalesByProduct({
    required DateTime fromDate,
    required DateTime toDate,
    String? categoryId,
  }) async {
    try {
      final fromStr = _fmt(fromDate);
      final toStr = _fmt(toDate);

      final invoicesData = await _client
          .from('invoices')
          .select('id')
          .inFilter('status', ['issued', 'paid', 'partially_paid'])
          .gte('invoice_date', fromStr)
          .lte('invoice_date', toStr);

      final invoiceIds =
          (invoicesData as List).map((e) => e['id'] as String).toList();

      if (invoiceIds.isEmpty) {
        return SalesByProductModel.fromRows(fromDate, toDate, const []);
      }

      final itemsData = await _client
          .from('invoice_items')
          .select(
            'invoice_id, product_id, quantity, unit_price, discount, total, '
            'products(id, name, product_code, unit, category_id)',
          )
          .inFilter('invoice_id', invoiceIds);

      final Map<String, _SalesProductAcc> acc = {};

      for (final item in (itemsData as List)) {
        final productData = item['products'] as Map<String, dynamic>?;
        if (productData == null) continue;

        if (categoryId != null && productData['category_id'] != categoryId) {
          continue;
        }

        final productId = productData['id'] as String;
        final invoiceId = item['invoice_id'] as String;
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
        final discount = (item['discount'] as num?)?.toDouble() ?? 0;
        final total = (item['total'] as num?)?.toDouble() ?? 0;
        final gross = unitPrice * qty;

        final entry = acc.putIfAbsent(
          productId,
          () => _SalesProductAcc(
            productId: productId,
            productCode: productData['product_code'] as String? ?? '-',
            productName: productData['name'] as String? ?? '-',
            unit: productData['unit'] as String? ?? 'قطعة',
          ),
        );
        entry.addItem(invoiceId, qty, gross, discount, total);
      }

      final rows = acc.values.map((e) => e.build()).toList();
      return SalesByProductModel.fromRows(fromDate, toDate, rows);
    } on PostgrestException catch (e) {
      debugPrint('SALES BY PRODUCT PG ERROR: ${e.code} - ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('SALES BY PRODUCT ERROR: $e');
      rethrow;
    }
  }

  // ============================================
  // SALES BY CUSTOMER
  // ============================================
  Future<SalesByCustomerModel> getSalesByCustomer({
    required DateTime fromDate,
    required DateTime toDate,
    String? customerId,
  }) async {
    try {
      final fromStr = _fmt(fromDate);
      final toStr = _fmt(toDate);

      var invQuery = _client
          .from('invoices')
          .select(
            'id, customer_id, subtotal, discount, total, '
            'customers(id, customer_code, name, phone)',
          )
          .inFilter('status', ['issued', 'paid', 'partially_paid'])
          .gte('invoice_date', fromStr)
          .lte('invoice_date', toStr);

      if (customerId != null) {
        invQuery = invQuery.eq('customer_id', customerId);
      }

      final invoicesData = await invQuery;

      if ((invoicesData as List).isEmpty) {
        return SalesByCustomerModel.fromRows(fromDate, toDate, const []);
      }

      final Map<String, _SalesCustomerAcc> acc = {};

      for (final inv in (invoicesData as List)) {
        final custData = inv['customers'] as Map<String, dynamic>?;
        if (custData == null) continue;

        final custId = custData['id'] as String;
        final subtotal = (inv['subtotal'] as num?)?.toDouble() ?? 0;
        final discount = (inv['discount'] as num?)?.toDouble() ?? 0;
        final total = (inv['total'] as num?)?.toDouble() ?? 0;

        final entry = acc.putIfAbsent(
          custId,
          () => _SalesCustomerAcc(
            customerId: custId,
            customerCode: custData['customer_code'] as String?,
            customerName: custData['name'] as String? ?? '-',
            phone: custData['phone'] as String?,
          ),
        );
        entry.addInvoice(subtotal, discount, total);
      }

      final rows = acc.values.map((e) => e.build()).toList();
      return SalesByCustomerModel.fromRows(fromDate, toDate, rows);
    } on PostgrestException catch (e) {
      debugPrint('SALES BY CUSTOMER PG ERROR: ${e.code} - ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('SALES BY CUSTOMER ERROR: $e');
      rethrow;
    }
  }

  // ============================================
  // LOW STOCK
  // ============================================
  Future<LowStockModel> getLowStock({
    DateTime? asOfDate,
    String? categoryId,
  }) async {
    try {
      final now = asOfDate ?? DateTime.now();

      var prodQuery = _client
          .from('products')
          .select('id, name, product_code, unit, min_stock_level, category_id')
          .eq('is_active', true)
          .gt('min_stock_level', 0);

      if (categoryId != null) {
        prodQuery = prodQuery.eq('category_id', categoryId);
      }

      final productsData = await prodQuery;
      final products = List<Map<String, dynamic>>.from(productsData);

      if (products.isEmpty) {
        return LowStockModel.fromRows(now, const []);
      }

      final productIds = products.map((p) => p['id'] as String).toList();

      final stockData = await _client
          .from('inventory_stock')
          .select('product_id, quantity, last_updated_at')
          .inFilter('product_id', productIds);

      final Map<String, double> totalQty = {};
      final Map<String, DateTime> lastUpdated = {};

      for (final s in (stockData as List)) {
        final pid = s['product_id'] as String;
        final qty = (s['quantity'] as num?)?.toDouble() ?? 0;
        totalQty[pid] = (totalQty[pid] ?? 0) + qty;

        final updatedAt = s['last_updated_at'] != null
            ? DateTime.parse(s['last_updated_at'] as String)
            : null;
        if (updatedAt != null) {
          final existing = lastUpdated[pid];
          if (existing == null || updatedAt.isAfter(existing)) {
            lastUpdated[pid] = updatedAt;
          }
        }
      }

      final rows = <LowStockRow>[];
      for (final p in products) {
        final pid = p['id'] as String;
        final minLevel = (p['min_stock_level'] as num?)?.toInt() ?? 0;
        if (minLevel <= 0) continue;

        final current = totalQty[pid] ?? 0;

        if (current >= minLevel) continue;

        final shortfall = minLevel - current;

        LowStockSeverity severity;
        if (current.abs() < 0.001) {
          severity = LowStockSeverity.outOfStock;
        } else if (current < minLevel * 0.5) {
          severity = LowStockSeverity.critical;
        } else {
          severity = LowStockSeverity.low;
        }

        rows.add(LowStockRow(
          productId: pid,
          productCode: p['product_code'] as String? ?? '-',
          productName: p['name'] as String? ?? '-',
          unit: p['unit'] as String? ?? 'قطعة',
          currentStock: current,
          minStockLevel: minLevel,
          shortfall: shortfall,
          severity: severity,
          lastUpdatedAt: lastUpdated[pid],
        ));
      }

      return LowStockModel.fromRows(now, rows);
    } on PostgrestException catch (e) {
      debugPrint('LOW STOCK PG ERROR: ${e.code} - ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('LOW STOCK ERROR: $e');
      rethrow;
    }
  }

  // ============================================
  // STOCK VALUATION
  // ============================================
  Future<StockValuationModel> getStockValuation({
    DateTime? asOfDate,
    String? warehouseId,
    String? categoryId,
    bool includeZeroStock = false,
  }) async {
    try {
      final now = asOfDate ?? DateTime.now();

      var stockQuery = _client.from('inventory_stock').select(
            'product_id, warehouse_id, quantity, last_updated_at, '
            'products(id, name, product_code, unit, purchase_price, '
            'selling_price, category_id, is_active), '
            'warehouses(id, name, is_active)',
          );

      if (warehouseId != null) {
        stockQuery = stockQuery.eq('warehouse_id', warehouseId);
      }

      final stockData = await stockQuery;
      final stockList = List<Map<String, dynamic>>.from(stockData);

      if (stockList.isEmpty) {
        return StockValuationModel.fromRows(now, const []);
      }

      final rows = <StockValuationRow>[];

      for (final s in stockList) {
        final productData = s['products'] as Map<String, dynamic>?;
        final warehouseData = s['warehouses'] as Map<String, dynamic>?;
        if (productData == null || warehouseData == null) continue;

        final isActive = productData['is_active'] as bool? ?? true;
        if (!isActive) continue;

        if (categoryId != null && productData['category_id'] != categoryId) {
          continue;
        }

        final whActive = warehouseData['is_active'] as bool? ?? true;
        if (!whActive) continue;

        final qty = (s['quantity'] as num?)?.toDouble() ?? 0;

        if (!includeZeroStock && qty.abs() < 0.001) continue;

        final purchasePrice =
            (productData['purchase_price'] as num?)?.toDouble() ?? 0;
        final sellingPrice =
            (productData['selling_price'] as num?)?.toDouble() ?? 0;

        rows.add(StockValuationRow(
          productId: productData['id'] as String,
          productCode: productData['product_code'] as String? ?? '-',
          productName: productData['name'] as String? ?? '-',
          unit: productData['unit'] as String? ?? 'قطعة',
          warehouseId: warehouseData['id'] as String,
          warehouseName: warehouseData['name'] as String? ?? '-',
          quantity: qty,
          purchasePrice: purchasePrice,
          sellingPrice: sellingPrice,
        ));
      }

      return StockValuationModel.fromRows(now, rows);
    } on PostgrestException catch (e) {
      debugPrint('STOCK VALUATION PG ERROR: ${e.code} - ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('STOCK VALUATION ERROR: $e');
      rethrow;
    }
  }

  // ============================================
  // STOCK MOVEMENT
  // ============================================
  Future<StockMovementModel> getStockMovement({
    required DateTime fromDate,
    required DateTime toDate,
    String? warehouseId,
    String? productId,
    StockMovementType? type,
  }) async {
    try {
      final fromStr = '${_fmt(fromDate)}T00:00:00';
      final toStr = '${_fmt(toDate)}T23:59:59';

      var query = _client
          .from('inventory_transactions')
          .select(
            'id, product_id, warehouse_id, transaction_type, quantity, '
            'unit_price, reference_type, notes, created_at, '
            'products(id, name, product_code, unit), '
            'warehouses(id, name)',
          )
          .gte('created_at', fromStr)
          .lte('created_at', toStr);

      if (warehouseId != null) query = query.eq('warehouse_id', warehouseId);
      if (productId != null) query = query.eq('product_id', productId);
      if (type != null) query = query.eq('transaction_type', type.dbValue);

      final data = await query.order('created_at', ascending: false);

      final rows = <StockMovementRow>[];
      for (final t in (data as List)) {
        final productData = t['products'] as Map<String, dynamic>?;
        final warehouseData = t['warehouses'] as Map<String, dynamic>?;
        if (productData == null || warehouseData == null) continue;

        final qty = (t['quantity'] as num?)?.toDouble() ?? 0;
        final unitPrice = (t['unit_price'] as num?)?.toDouble() ?? 0;

        rows.add(StockMovementRow(
          id: t['id'] as String,
          date: DateTime.parse(t['created_at'] as String),
          productId: productData['id'] as String,
          productCode: productData['product_code'] as String? ?? '-',
          productName: productData['name'] as String? ?? '-',
          unit: productData['unit'] as String? ?? 'قطعة',
          warehouseId: warehouseData['id'] as String,
          warehouseName: warehouseData['name'] as String? ?? '-',
          type: StockMovementTypeX.fromDb(t['transaction_type'] as String),
          quantity: qty,
          unitPrice: unitPrice,
          totalValue: qty * unitPrice,
          referenceType: t['reference_type'] as String?,
          notes: t['notes'] as String?,
        ));
      }

      return StockMovementModel.fromRows(fromDate, toDate, rows);
    } on PostgrestException catch (e) {
      debugPrint('STOCK MOVEMENT PG ERROR: ${e.code} - ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('STOCK MOVEMENT ERROR: $e');
      rethrow;
    }
  }

  // ============================================
  // INVOICE REGISTER
  // ============================================
  Future<InvoiceRegisterModel> getInvoiceRegister({
    required DateTime fromDate,
    required DateTime toDate,
    InvoiceRegisterStatus? status,
  }) async {
    try {
      final fromStr = _fmt(fromDate);
      final toStr = _fmt(toDate);

      var query = _client
          .from('invoices')
          .select(
            'id, invoice_number, invoice_date, due_date, status, '
            'subtotal, discount, tax, total, paid_amount, '
            'customer_id, customers(id, customer_code, name)',
          )
          .gte('invoice_date', fromStr)
          .lte('invoice_date', toStr);

      if (status != null && status != InvoiceRegisterStatus.all) {
        query = query.eq('status', status.dbValue);
      }

      final data = await query.order('invoice_date', ascending: false);

      final rows = <InvoiceRegisterRow>[];
      for (final inv in (data as List)) {
        final custData = inv['customers'] as Map<String, dynamic>?;

        rows.add(InvoiceRegisterRow(
          id: inv['id'] as String,
          invoiceNumber: inv['invoice_number'] as String? ?? '-',
          invoiceDate: DateTime.parse(inv['invoice_date'] as String),
          dueDate: inv['due_date'] != null
              ? DateTime.parse(inv['due_date'] as String)
              : null,
          customerId: custData?['id'] as String?,
          customerCode: custData?['customer_code'] as String?,
          customerName: custData?['name'] as String?,
          status: inv['status'] as String? ?? 'draft',
          subtotal: (inv['subtotal'] as num?)?.toDouble() ?? 0,
          discount: (inv['discount'] as num?)?.toDouble() ?? 0,
          tax: (inv['tax'] as num?)?.toDouble() ?? 0,
          total: (inv['total'] as num?)?.toDouble() ?? 0,
          paidAmount: (inv['paid_amount'] as num?)?.toDouble() ?? 0,
        ));
      }

      return InvoiceRegisterModel.fromRows(fromDate, toDate, rows);
    } on PostgrestException catch (e) {
      debugPrint('INVOICE REGISTER PG ERROR: ${e.code} - ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('INVOICE REGISTER ERROR: $e');
      rethrow;
    }
  }

  // ============================================
  // HELPERS
  // ============================================
  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ============================================
// Accumulators (internal)
// ============================================
class _ArAgingAccumulator {
  final String customerId;
  final String? customerCode;
  final String customerName;
  final String? phone;

  double current = 0;
  double days1To30 = 0;
  double days31To60 = 0;
  double days61To90 = 0;
  double over90 = 0;
  int invoiceCount = 0;
  DateTime? oldestDueDate;

  _ArAgingAccumulator({
    required this.customerId,
    this.customerCode,
    required this.customerName,
    this.phone,
  });

  void addInvoice(double outstanding, int daysOverdue, DateTime refDate) {
    invoiceCount++;
    if (oldestDueDate == null || refDate.isBefore(oldestDueDate!)) {
      oldestDueDate = refDate;
    }

    if (daysOverdue < 0) {
      current += outstanding;
    } else if (daysOverdue <= 30) {
      days1To30 += outstanding;
    } else if (daysOverdue <= 60) {
      days31To60 += outstanding;
    } else if (daysOverdue <= 90) {
      days61To90 += outstanding;
    } else {
      over90 += outstanding;
    }
  }

  ArAgingCustomerRow build() => ArAgingCustomerRow(
        customerId: customerId,
        customerCode: customerCode,
        customerName: customerName,
        phone: phone,
        current: current,
        days1To30: days1To30,
        days31To60: days31To60,
        days61To90: days61To90,
        over90: over90,
        invoiceCount: invoiceCount,
        oldestDueDate: oldestDueDate,
      );
}

class _SalesProductAcc {
  final String productId;
  final String productCode;
  final String productName;
  final String unit;

  double quantitySold = 0;
  double grossAmount = 0;
  double discountAmount = 0;
  double netAmount = 0;
  final Set<String> _invoiceIds = {};

  _SalesProductAcc({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unit,
  });

  void addItem(
    String invoiceId,
    double qty,
    double gross,
    double discount,
    double net,
  ) {
    quantitySold += qty;
    grossAmount += gross;
    discountAmount += discount;
    netAmount += net;
    _invoiceIds.add(invoiceId);
  }

  SalesByProductRow build() => SalesByProductRow(
        productId: productId,
        productCode: productCode,
        productName: productName,
        unit: unit,
        quantitySold: quantitySold,
        grossAmount: grossAmount,
        discountAmount: discountAmount,
        netAmount: netAmount,
        invoiceCount: _invoiceIds.length,
      );
}

class _SalesCustomerAcc {
  final String customerId;
  final String? customerCode;
  final String customerName;
  final String? phone;

  int invoiceCount = 0;
  double grossAmount = 0;
  double discountAmount = 0;
  double netAmount = 0;

  _SalesCustomerAcc({
    required this.customerId,
    this.customerCode,
    required this.customerName,
    this.phone,
  });

  void addInvoice(double gross, double discount, double net) {
    invoiceCount++;
    grossAmount += gross;
    discountAmount += discount;
    netAmount += net;
  }

  SalesByCustomerRow build() => SalesByCustomerRow(
        customerId: customerId,
        customerCode: customerCode,
        customerName: customerName,
        phone: phone,
        invoiceCount: invoiceCount,
        grossAmount: grossAmount,
        discountAmount: discountAmount,
        netAmount: netAmount,
      );
}
