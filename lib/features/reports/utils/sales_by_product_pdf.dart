import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models/sales_by_product_model.dart';

class SalesByProductPdf {
  SalesByProductPdf._();

  static Future<void> share(
    SalesByProductModel data, {
    required String langCode,
  }) async {
    final bytes = await _build(data, langCode: langCode);
    await Printing.sharePdf(
      bytes: bytes,
      filename: _fileName(data),
    );
  }

  static Future<void> print(
    SalesByProductModel data, {
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
    SalesByProductModel data, {
    required String langCode,
  }) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final labels = _labelsFor(langCode);
    final dateFmt = DateFormat('yyyy-MM-dd');
    final numFmt = NumberFormat('#,##0.00');
    final isRtl = langCode == 'ar';
    final dir = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final doc = pw.Document(title: labels['sales_by_product']!);

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
            labels['sales_by_product']!,
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
    SalesByProductModel data,
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
    SalesByProductModel data,
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
            '${labels['products_count']}: ${data.productCount}  ·  '
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
    SalesByProductModel data,
    Map<String, String> labels,
    NumberFormat numFmt,
  ) {
    final cards = <(String, String, PdfColor)>[
      (
        labels['total_quantity']!,
        numFmt.format(data.totalQuantity),
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
    SalesByProductModel data,
    Map<String, String> labels,
    NumberFormat numFmt,
  ) {
    final headers = [
      '#',
      labels['product']!,
      labels['unit']!,
      labels['quantity']!,
      labels['gross_sales']!,
      labels['discount']!,
      labels['net_sales']!,
      labels['avg_price']!,
      labels['invoices']!,
    ];

    final rows = <List<String>>[];
    for (var i = 0; i < data.rows.length; i++) {
      final r = data.rows[i];
      rows.add([
        '${i + 1}',
        '${r.productCode} - ${r.productName}',
        r.unit,
        numFmt.format(r.quantitySold),
        numFmt.format(r.grossAmount),
        numFmt.format(r.discountAmount),
        numFmt.format(r.netAmount),
        numFmt.format(r.averagePrice),
        '${r.invoiceCount}',
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
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
        8: pw.Alignment.center,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(40),
        3: const pw.FixedColumnWidth(55),
        4: const pw.FixedColumnWidth(65),
        5: const pw.FixedColumnWidth(60),
        6: const pw.FixedColumnWidth(70),
        7: const pw.FixedColumnWidth(60),
        8: const pw.FixedColumnWidth(45),
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
    SalesByProductModel data,
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
              '${labels['products_count']}: ${data.productCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              numFmt.format(data.totalQuantity),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
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
          pw.Expanded(
            child: pw.Text(
              '${labels['invoices_count']}: ${data.totalInvoices}',
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // HELPERS
  // ============================================
  static String _fileName(SalesByProductModel data) {
    final from = DateFormat('yyyyMMdd').format(data.fromDate);
    final to = DateFormat('yyyyMMdd').format(data.toDate);
    return 'sales_by_product_${from}_$to.pdf';
  }

  static Map<String, String> _labelsFor(String lang) {
    switch (lang) {
      case 'en':
        return {
          'sales_by_product': 'Sales by Product',
          'period': 'Period',
          'generated_on': 'Generated',
          'page': 'Page',
          'product': 'Product',
          'unit': 'Unit',
          'quantity': 'Quantity',
          'gross_sales': 'Gross',
          'discount': 'Discount',
          'net_sales': 'Net',
          'avg_price': 'Avg Price',
          'invoices': 'Invoices',
          'total': 'Total',
          'products_count': 'Products',
          'invoices_count': 'Invoices',
          'total_quantity': 'Total Qty',
          'discount_amount': 'Total Discount',
        };
      case 'zh':
        return {
          'sales_by_product': '按产品销售',
          'period': '期间',
          'generated_on': '生成于',
          'page': '页',
          'product': '产品',
          'unit': '单位',
          'quantity': '数量',
          'gross_sales': '总额',
          'discount': '折扣',
          'net_sales': '净额',
          'avg_price': '均价',
          'invoices': '发票',
          'total': '合计',
          'products_count': '产品数',
          'invoices_count': '发票数',
          'total_quantity': '总数量',
          'discount_amount': '折扣合计',
        };
      default:
        return {
          'sales_by_product': 'المبيعات حسب المنتج',
          'period': 'الفترة',
          'generated_on': 'تم الإنشاء',
          'page': 'صفحة',
          'product': 'المنتج',
          'unit': 'الوحدة',
          'quantity': 'الكمية',
          'gross_sales': 'الإجمالي',
          'discount': 'الخصم',
          'net_sales': 'الصافي',
          'avg_price': 'متوسط السعر',
          'invoices': 'فواتير',
          'total': 'الإجمالي',
          'products_count': 'منتج',
          'invoices_count': 'فاتورة',
          'total_quantity': 'إجمالي الكمية',
          'discount_amount': 'إجمالي الخصم',
        };
    }
  }
}
