import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models/sales_by_customer_model.dart';

class SalesByCustomerPdf {
  SalesByCustomerPdf._();

  static Future<void> share(
    SalesByCustomerModel data, {
    required String langCode,
  }) async {
    final bytes = await _build(data, langCode: langCode);
    await Printing.sharePdf(
      bytes: bytes,
      filename: _fileName(data),
    );
  }

  static Future<void> print(
    SalesByCustomerModel data, {
    required String langCode,
  }) async {
    final bytes = await _build(data, langCode: langCode);
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: _fileName(data),
    );
  }

  // ============================================
  // BUILD
  // ============================================
  static Future<Uint8List> _build(
    SalesByCustomerModel data, {
    required String langCode,
  }) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final labels = _labelsFor(langCode);
    final dateFmt = DateFormat('yyyy-MM-dd');
    final numFmt = NumberFormat('#,##0.00');
    final isRtl = langCode == 'ar';
    final dir = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final doc = pw.Document(title: labels['sales_by_customer']!);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        textDirection: dir,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (ctx) => _header(labels, fontBold),
        footer: (ctx) => _footer(ctx, labels, data, dateFmt, font),
        build: (ctx) => [
          _periodInfo(data, labels, dateFmt),
          pw.SizedBox(height: 8),
          _summaryCards(data, labels, numFmt),
          pw.SizedBox(height: 10),
          _table(data, labels, numFmt),
          pw.SizedBox(height: 10),
          _totalsRow(data, labels, numFmt),
        ],
      ),
    );

    return doc.save();
  }

  // ============================================
  // HEADER
  // ============================================
  static pw.Widget _header(
    Map<String, String> labels,
    pw.Font fontBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 1)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'SI EXPORTER OS',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 18,
              color: PdfColors.blueGrey900,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            labels['sales_by_customer']!,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 14,
              color: PdfColors.blueGrey700,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============================================
  // FOOTER
  // ============================================
  static pw.Widget _footer(
    pw.Context ctx,
    Map<String, String> labels,
    SalesByCustomerModel data,
    DateFormat dateFmt,
    pw.Font font,
  ) {
    final now = DateTime.now();
    final genDate = '${dateFmt.format(now)} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${labels['period']}: '
            '${dateFmt.format(data.fromDate)} → '
            '${dateFmt.format(data.toDate)}',
            style: pw.TextStyle(
              font: font,
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            '${labels['generated_on']}: $genDate  ·  '
            '${labels['page']} ${ctx.pageNumber}/${ctx.pagesCount}',
            style: pw.TextStyle(
              font: font,
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // PERIOD INFO
  // ============================================
  static pw.Widget _periodInfo(
    SalesByCustomerModel data,
    Map<String, String> labels,
    DateFormat dateFmt,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${labels['period']}: '
            '${dateFmt.format(data.fromDate)} → '
            '${dateFmt.format(data.toDate)}',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            '${labels['customers_count']}: ${data.customerCount}  ·  '
            '${labels['invoices_count']}: ${data.totalInvoices}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  // ============================================
  // SUMMARY CARDS
  // ============================================
  static pw.Widget _summaryCards(
    SalesByCustomerModel data,
    Map<String, String> labels,
    NumberFormat numFmt,
  ) {
    final cards = <(String, String, PdfColor)>[
      (
        labels['customers_count']!,
        '${data.customerCount}',
        PdfColors.blue700,
      ),
      (
        labels['gross_sales']!,
        numFmt.format(data.totalGross),
        PdfColors.blueGrey700,
      ),
      (
        labels['discount_amount']!,
        numFmt.format(data.totalDiscount),
        PdfColors.orange700,
      ),
      (
        labels['net_sales']!,
        numFmt.format(data.totalNet),
        PdfColors.green700,
      ),
    ];

    return pw.Row(
      children: cards
          .map(
            (c) => pw.Expanded(
              child: pw.Container(
                margin: const pw.EdgeInsets.symmetric(horizontal: 3),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: c.$3, width: 0.6),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      c.$1,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      c.$2,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: c.$3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ============================================
  // TABLE
  // ============================================
  static pw.Widget _table(
    SalesByCustomerModel data,
    Map<String, String> labels,
    NumberFormat numFmt,
  ) {
    final headers = [
      '#',
      labels['customer']!,
      labels['phone']!,
      labels['invoices']!,
      labels['gross_sales']!,
      labels['discount']!,
      labels['net_sales']!,
      labels['avg_invoice']!,
    ];

    final rows = <List<String>>[];
    for (var i = 0; i < data.rows.length; i++) {
      final r = data.rows[i];
      final nameCode = r.customerCode != null
          ? '${r.customerCode} - ${r.customerName}'
          : r.customerName;
      rows.add([
        '${i + 1}',
        nameCode,
        r.phone ?? '-',
        '${r.invoiceCount}',
        numFmt.format(r.grossAmount),
        numFmt.format(r.discountAmount),
        numFmt.format(r.netAmount),
        numFmt.format(r.averageInvoiceValue),
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(80),
        3: const pw.FixedColumnWidth(45),
        4: const pw.FixedColumnWidth(70),
        5: const pw.FixedColumnWidth(60),
        6: const pw.FixedColumnWidth(75),
        7: const pw.FixedColumnWidth(75),
      },
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      cellPadding: const pw.EdgeInsets.symmetric(
        horizontal: 3,
        vertical: 2.5,
      ),
    );
  }

  // ============================================
  // TOTALS ROW
  // ============================================
  static pw.Widget _totalsRow(
    SalesByCustomerModel data,
    Map<String, String> labels,
    NumberFormat numFmt,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey100,
        border: pw.Border.all(color: PdfColors.blueGrey800, width: 0.8),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 60,
            child: pw.Text(
              labels['total']!,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              '${labels['customers_count']}: ${data.customerCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              '${labels['invoices_count']}: ${data.totalInvoices}',
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              numFmt.format(data.totalGross),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              numFmt.format(data.totalDiscount),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              numFmt.format(data.totalNet),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: PdfColors.green800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // HELPERS
  // ============================================
  static String _fileName(SalesByCustomerModel data) {
    final from = DateFormat('yyyyMMdd').format(data.fromDate);
    final to = DateFormat('yyyyMMdd').format(data.toDate);
    return 'sales_by_customer_${from}_$to.pdf';
  }

  static Map<String, String> _labelsFor(String lang) {
    switch (lang) {
      case 'en':
        return {
          'sales_by_customer': 'Sales by Customer',
          'period': 'Period',
          'generated_on': 'Generated',
          'page': 'Page',
          'customer': 'Customer',
          'phone': 'Phone',
          'invoices': 'Invoices',
          'gross_sales': 'Gross',
          'discount': 'Discount',
          'net_sales': 'Net',
          'avg_invoice': 'Avg Invoice',
          'total': 'Total',
          'customers_count': 'Customers',
          'invoices_count': 'Invoices',
          'discount_amount': 'Total Discount',
        };
      case 'zh':
        return {
          'sales_by_customer': '按客户销售',
          'period': '期间',
          'generated_on': '生成于',
          'page': '页',
          'customer': '客户',
          'phone': '电话',
          'invoices': '发票',
          'gross_sales': '总额',
          'discount': '折扣',
          'net_sales': '净额',
          'avg_invoice': '平均发票',
          'total': '合计',
          'customers_count': '客户数',
          'invoices_count': '发票数',
          'discount_amount': '折扣合计',
        };
      default:
        return {
          'sales_by_customer': 'المبيعات حسب العميل',
          'period': 'الفترة',
          'generated_on': 'تم الإنشاء',
          'page': 'صفحة',
          'customer': 'العميل',
          'phone': 'الهاتف',
          'invoices': 'فواتير',
          'gross_sales': 'الإجمالي',
          'discount': 'الخصم',
          'net_sales': 'الصافي',
          'avg_invoice': 'متوسط الفاتورة',
          'total': 'الإجمالي',
          'customers_count': 'عميل',
          'invoices_count': 'فاتورة',
          'discount_amount': 'إجمالي الخصم',
        };
    }
  }
}
