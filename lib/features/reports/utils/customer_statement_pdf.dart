import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models/customer_statement_model.dart';

class CustomerStatementPdf {
  CustomerStatementPdf._();

  // ============================================
  // PUBLIC API
  // ============================================
  static Future<void> share(
    CustomerStatementModel data, {
    required String langCode,
  }) async {
    final bytes = await _build(data, langCode: langCode);
    await Printing.sharePdf(
      bytes: bytes,
      filename: _fileName(data),
    );
  }

  static Future<void> print(
    CustomerStatementModel data, {
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
    CustomerStatementModel data, {
    required String langCode,
  }) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final labels = _labelsFor(langCode);
    final dateFmt = DateFormat('yyyy-MM-dd');
    final numFmt = NumberFormat('#,##0.00');
    final isRtl = langCode == 'ar';
    final dir = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final doc = pw.Document(
      title: '${labels['statement_for']} ${data.customer.name}',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        textDirection: dir,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _header(context, labels, fontBold),
        footer: (context) => _footer(context, labels, data, dateFmt, font),
        build: (context) => [
          _customerInfo(data, labels, dateFmt),
          pw.SizedBox(height: 12),
          _summaryBar(data, labels, numFmt),
          pw.SizedBox(height: 12),
          _table(data, labels, dateFmt, numFmt, dir),
          pw.SizedBox(height: 12),
          _totalsBox(data, labels, numFmt),
        ],
      ),
    );

    return doc.save();
  }

  // ============================================
  // HEADER
  // ============================================
  static pw.Widget _header(
    pw.Context ctx,
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
            labels['customer_statement']!,
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
    CustomerStatementModel data,
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
            '${labels['generated_on']}: $genDate',
            style: pw.TextStyle(
              font: font,
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            '${labels['page']} ${ctx.pageNumber} / ${ctx.pagesCount}',
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
  // CUSTOMER INFO
  // ============================================
  static pw.Widget _customerInfo(
    CustomerStatementModel data,
    Map<String, String> labels,
    DateFormat dateFmt,
  ) {
    final c = data.customer;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _kv(labels['customer']!, c.name),
          if (c.customerCode != null)
            _kv(labels['customer_code']!, c.customerCode!),
          if (c.phone != null) _kv(labels['phone']!, c.phone!),
          if (c.email != null) _kv(labels['email']!, c.email!),
          if (c.address != null) _kv(labels['address']!, c.address!),
          pw.Divider(thickness: 0.3),
          _kv(
            labels['report_period']!,
            '${dateFmt.format(data.fromDate)}  →  '
            '${dateFmt.format(data.toDate)}',
            bold: true,
          ),
        ],
      ),
    );
  }

  static pw.Widget _kv(String k, String v, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              '$k:',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : null,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              v,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // SUMMARY BAR
  // ============================================
  static pw.Widget _summaryBar(
    CustomerStatementModel data,
    Map<String, String> labels,
    NumberFormat numFmt,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      color: PdfColors.blueGrey50,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _stat(
            labels['opening_balance']!,
            numFmt.format(data.openingBalance),
          ),
          _stat(
            labels['total_debit']!,
            numFmt.format(data.totalDebits),
          ),
          _stat(
            labels['total_credit']!,
            numFmt.format(data.totalCredits),
          ),
          _stat(
            labels['closing_balance']!,
            numFmt.format(data.closingBalance),
            bold: true,
            color: data.closingBalance >= 0
                ? PdfColors.red800
                : PdfColors.green800,
          ),
        ],
      ),
    );
  }

  static pw.Widget _stat(
    String label,
    String value, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: bold ? 12 : 11,
            fontWeight: bold ? pw.FontWeight.bold : null,
            color: color,
          ),
        ),
      ],
    );
  }

  // ============================================
  // TABLE
  // ============================================
  static pw.Widget _table(
    CustomerStatementModel data,
    Map<String, String> labels,
    DateFormat dateFmt,
    NumberFormat numFmt,
    pw.TextDirection dir,
  ) {
    final headers = [
      '#',
      labels['date']!,
      labels['document_type']!,
      labels['description']!,
      labels['debit']!,
      labels['credit']!,
      labels['running_balance']!,
    ];

    final rows = <List<String>>[];
    for (var i = 0; i < data.lines.length; i++) {
      final l = data.lines[i];
      rows.add([
        '${i + 1}',
        dateFmt.format(l.date),
        l.type == StatementLineType.invoice
            ? labels['invoice']!
            : labels['payment']!,
        l.description ?? l.documentNumber,
        l.debit > 0.001 ? numFmt.format(l.debit) : '-',
        l.credit > 0.001 ? numFmt.format(l.credit) : '-',
        numFmt.format(l.runningBalance),
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        1: const pw.FixedColumnWidth(60),
        2: const pw.FixedColumnWidth(55),
        3: const pw.FlexColumnWidth(3),
        4: const pw.FixedColumnWidth(65),
        5: const pw.FixedColumnWidth(65),
        6: const pw.FixedColumnWidth(70),
      },
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      cellPadding: const pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 3,
      ),
    );
  }

  // ============================================
  // TOTALS BOX
  // ============================================
  static pw.Widget _totalsBox(
    CustomerStatementModel data,
    Map<String, String> labels,
    NumberFormat numFmt,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _totalRow(
            labels['opening_balance']!,
            numFmt.format(data.openingBalance),
          ),
          _totalRow(
            labels['total_debit']!,
            numFmt.format(data.totalDebits),
          ),
          _totalRow(
            labels['total_credit']!,
            numFmt.format(data.totalCredits),
          ),
          pw.Divider(thickness: 0.5),
          _totalRow(
            labels['closing_balance']!,
            numFmt.format(data.closingBalance),
            bold: true,
            color: data.closingBalance >= 0
                ? PdfColors.red800
                : PdfColors.green800,
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: bold ? 11 : 10,
              fontWeight: bold ? pw.FontWeight.bold : null,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: bold ? 11 : 10,
              fontWeight: bold ? pw.FontWeight.bold : null,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // HELPERS
  // ============================================
  static String _fileName(CustomerStatementModel data) {
    final code = data.customer.customerCode ?? 'customer';
    final from = DateFormat('yyyyMMdd').format(data.fromDate);
    final to = DateFormat('yyyyMMdd').format(data.toDate);
    return 'statement_${code}_${from}_$to.pdf';
  }

  static Map<String, String> _labelsFor(String lang) {
    switch (lang) {
      case 'en':
        return {
          'customer_statement': 'Customer Statement',
          'statement_for': 'Statement for',
          'customer': 'Customer',
          'customer_code': 'Customer Code',
          'phone': 'Phone',
          'email': 'Email',
          'address': 'Address',
          'report_period': 'Period',
          'generated_on': 'Generated on',
          'page': 'Page',
          'opening_balance': 'Opening Balance',
          'closing_balance': 'Closing Balance',
          'total_debit': 'Total Debit',
          'total_credit': 'Total Credit',
          'running_balance': 'Balance',
          'date': 'Date',
          'document_type': 'Type',
          'description': 'Description',
          'debit': 'Debit',
          'credit': 'Credit',
          'invoice': 'Invoice',
          'payment': 'Payment',
        };
      case 'zh':
        return {
          'customer_statement': '客户对账单',
          'statement_for': '对账单 -',
          'customer': '客户',
          'customer_code': '客户编号',
          'phone': '电话',
          'email': '邮箱',
          'address': '地址',
          'report_period': '期间',
          'generated_on': '生成于',
          'page': '页',
          'opening_balance': '期初余额',
          'closing_balance': '期末余额',
          'total_debit': '借方合计',
          'total_credit': '贷方合计',
          'running_balance': '余额',
          'date': '日期',
          'document_type': '类型',
          'description': '描述',
          'debit': '借方',
          'credit': '贷方',
          'invoice': '发票',
          'payment': '付款',
        };
      default:
        return {
          'customer_statement': 'كشف حساب عميل',
          'statement_for': 'كشف حساب -',
          'customer': 'العميل',
          'customer_code': 'كود العميل',
          'phone': 'الهاتف',
          'email': 'البريد',
          'address': 'العنوان',
          'report_period': 'الفترة',
          'generated_on': 'تم الإنشاء في',
          'page': 'صفحة',
          'opening_balance': 'الرصيد الافتتاحي',
          'closing_balance': 'الرصيد الختامي',
          'total_debit': 'إجمالي المدين',
          'total_credit': 'إجمالي الدائن',
          'running_balance': 'الرصيد',
          'date': 'التاريخ',
          'document_type': 'النوع',
          'description': 'البيان',
          'debit': 'مدين',
          'credit': 'دائن',
          'invoice': 'فاتورة',
          'payment': 'دفعة',
        };
    }
  }
}
