import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models/invoice_register_model.dart';

class InvoiceRegisterPdf {
  InvoiceRegisterPdf._();

  static Future<void> share(InvoiceRegisterModel data,
      {required String langCode}) async {
    final bytes = await _build(data, langCode: langCode);
    await Printing.sharePdf(bytes: bytes, filename: _fileName(data));
  }

  static Future<void> print(InvoiceRegisterModel data,
      {required String langCode}) async {
    final bytes = await _build(data, langCode: langCode);
    await Printing.layoutPdf(onLayout: (_) => bytes, name: _fileName(data));
  }

  static Future<Uint8List> _build(InvoiceRegisterModel data,
      {required String langCode}) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final labels = _labelsFor(langCode);
    final dateFmt = DateFormat('yyyy-MM-dd');
    final numFmt = NumberFormat('#,##0.00');
    final isRtl = langCode == 'ar';
    final dir = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final doc = pw.Document(title: labels['invoice_register']!);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        textDirection: dir,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (ctx) => _header(labels, fontBold),
        footer: (ctx) => _footer(ctx, labels, data, dateFmt, font),
        build: (ctx) => [
          _summaryCards(data, labels, numFmt),
          pw.SizedBox(height: 10),
          _table(data, labels, dateFmt, numFmt),
          pw.SizedBox(height: 10),
          _totalsRow(data, labels, numFmt),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(Map<String, String> labels, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 1))),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text('SI EXPORTER OS',
              style: pw.TextStyle(
                  font: fontBold, fontSize: 18, color: PdfColors.blueGrey900),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 4),
          pw.Text(labels['invoice_register']!,
              style: pw.TextStyle(
                  font: fontBold, fontSize: 14, color: PdfColors.blueGrey700),
              textAlign: pw.TextAlign.center),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context ctx, Map<String, String> labels,
      InvoiceRegisterModel data, DateFormat dateFmt, pw.Font font) {
    final now = DateTime.now();
    final genDate =
        '${dateFmt.format(now)} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
              '${labels['period']}: ${dateFmt.format(data.fromDate)} → ${dateFmt.format(data.toDate)}',
              style: pw.TextStyle(
                  font: font, fontSize: 8, color: PdfColors.grey700)),
          pw.Text(
              '${labels['generated_on']}: $genDate  ·  ${labels['page']} ${ctx.pageNumber}/${ctx.pagesCount}',
              style: pw.TextStyle(
                  font: font, fontSize: 8, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  static pw.Widget _summaryCards(InvoiceRegisterModel data,
      Map<String, String> labels, NumberFormat numFmt) {
    final cards = <(String, String, PdfColor)>[
      (labels['invoices_count']!, '${data.invoiceCount}', PdfColors.blue700),
      (
        labels['total_amount']!,
        numFmt.format(data.totalAmount),
        PdfColors.blueGrey800
      ),
      (
        labels['total_paid']!,
        numFmt.format(data.totalPaid),
        PdfColors.green700
      ),
      (
        labels['total_remaining']!,
        numFmt.format(data.totalRemaining),
        PdfColors.red700
      ),
    ];

    return pw.Row(
      children: cards
          .map((c) => pw.Expanded(
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
                      pw.Text(c.$1,
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey700)),
                      pw.SizedBox(height: 3),
                      pw.Text(c.$2,
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: c.$3)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  static pw.Widget _table(InvoiceRegisterModel data, Map<String, String> labels,
      DateFormat dateFmt, NumberFormat numFmt) {
    final headers = [
      '#',
      labels['invoice_number']!,
      labels['date']!,
      labels['customer']!,
      labels['status']!,
      labels['subtotal']!,
      labels['discount']!,
      labels['tax']!,
      labels['total']!,
      labels['paid']!,
      labels['remaining']!,
    ];

    final rows = <List<String>>[];
    for (var i = 0; i < data.rows.length; i++) {
      final r = data.rows[i];
      rows.add([
        '${i + 1}',
        r.invoiceNumber,
        dateFmt.format(r.invoiceDate),
        r.customerName ?? '-',
        _statusLabel(r, labels),
        numFmt.format(r.subtotal),
        numFmt.format(r.discount),
        numFmt.format(r.tax),
        numFmt.format(r.total),
        numFmt.format(r.paidAmount),
        numFmt.format(r.remaining),
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.center,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
        8: pw.Alignment.centerRight,
        9: pw.Alignment.centerRight,
        10: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(18),
        1: const pw.FixedColumnWidth(60),
        2: const pw.FixedColumnWidth(55),
        3: const pw.FlexColumnWidth(3),
        4: const pw.FixedColumnWidth(50),
        5: const pw.FixedColumnWidth(55),
        6: const pw.FixedColumnWidth(50),
        7: const pw.FixedColumnWidth(50),
        8: const pw.FixedColumnWidth(60),
        9: const pw.FixedColumnWidth(60),
        10: const pw.FixedColumnWidth(65),
      },
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
    );
  }

  static String _statusLabel(InvoiceRegisterRow r, Map<String, String> labels) {
    if (r.isCancelled) return labels['status_cancelled']!;
    if (r.isPaid) return labels['status_paid']!;
    if (r.isOverdue) return labels['overdue']!;
    return labels[r.status] ?? r.status;
  }

  static pw.Widget _totalsRow(InvoiceRegisterModel data,
      Map<String, String> labels, NumberFormat numFmt) {
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
              child: pw.Text(labels['total']!,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 9))),
          pw.Expanded(
              flex: 3,
              child: pw.Text(
                  '${labels['invoices_count']}: ${data.invoiceCount}',
                  style: const pw.TextStyle(fontSize: 9))),
          pw.Expanded(
              child: pw.Text(numFmt.format(data.totalDiscount),
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 9))),
          pw.Expanded(
              child: pw.Text(numFmt.format(data.totalTax),
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 9))),
          pw.Expanded(
              child: pw.Text(numFmt.format(data.totalAmount),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                      color: PdfColors.blueGrey800))),
          pw.Expanded(
              child: pw.Text(numFmt.format(data.totalPaid),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                      color: PdfColors.green700))),
          pw.Expanded(
              child: pw.Text(numFmt.format(data.totalRemaining),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                      color: PdfColors.red800))),
        ],
      ),
    );
  }

  static String _fileName(InvoiceRegisterModel data) {
    final from = DateFormat('yyyyMMdd').format(data.fromDate);
    final to = DateFormat('yyyyMMdd').format(data.toDate);
    return 'invoice_register_${from}_$to.pdf';
  }

  static Map<String, String> _labelsFor(String lang) {
    switch (lang) {
      case 'en':
        return {
          'invoice_register': 'Invoice Register',
          'period': 'Period',
          'generated_on': 'Generated',
          'page': 'Page',
          'invoice_number': 'Invoice #',
          'date': 'Date',
          'customer': 'Customer',
          'status': 'Status',
          'subtotal': 'Subtotal',
          'discount': 'Discount',
          'tax': 'Tax',
          'total': 'Total',
          'paid': 'Paid',
          'remaining': 'Remaining',
          'total_amount': 'Total Amount',
          'total_paid': 'Total Paid',
          'total_remaining': 'Total Remaining',
          'invoices_count': 'Invoices',
          'status_draft': 'Draft',
          'status_issued': 'Issued',
          'status_partially_paid': 'Partially Paid',
          'status_paid': 'Paid',
          'status_cancelled': 'Cancelled',
          'overdue': 'Overdue',
        };
      case 'zh':
        return {
          'invoice_register': '发票登记',
          'period': '期间',
          'generated_on': '生成于',
          'page': '页',
          'invoice_number': '发票号',
          'date': '日期',
          'customer': '客户',
          'status': '状态',
          'subtotal': '小计',
          'discount': '折扣',
          'tax': '税额',
          'total': '总计',
          'paid': '已付',
          'remaining': '剩余',
          'total_amount': '总金额',
          'total_paid': '总已付',
          'total_remaining': '总剩余',
          'invoices_count': '发票数',
          'status_draft': '草稿',
          'status_issued': '已开具',
          'status_partially_paid': '部分付款',
          'status_paid': '已付款',
          'status_cancelled': '已取消',
          'overdue': '逾期',
        };
      default:
        return {
          'invoice_register': 'سجل الفواتير',
          'period': 'الفترة',
          'generated_on': 'تم الإنشاء',
          'page': 'صفحة',
          'invoice_number': 'رقم الفاتورة',
          'date': 'التاريخ',
          'customer': 'العميل',
          'status': 'الحالة',
          'subtotal': 'المجموع الفرعي',
          'discount': 'الخصم',
          'tax': 'الضريبة',
          'total': 'الإجمالي',
          'paid': 'المدفوع',
          'remaining': 'المتبقي',
          'total_amount': 'إجمالي المبالغ',
          'total_paid': 'إجمالي المدفوع',
          'total_remaining': 'إجمالي المتبقي',
          'invoices_count': 'فاتورة',
          'status_draft': 'مسودة',
          'status_issued': 'صادرة',
          'status_partially_paid': 'مدفوعة جزئياً',
          'status_paid': 'مدفوعة',
          'status_cancelled': 'ملغاة',
          'overdue': 'متأخرة',
        };
    }
  }
}
