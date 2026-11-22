import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models/ar_aging_model.dart';

class ArAgingPdf {
  ArAgingPdf._();

  // ============================================
  // PUBLIC API
  // ============================================
  static Future<void> share(
    ArAgingModel data, {
    required String langCode,
  }) async {
    final bytes = await _build(data, langCode: langCode);
    await Printing.sharePdf(
      bytes: bytes,
      filename: _fileName(data),
    );
  }

  static Future<void> print(
    ArAgingModel data, {
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
    ArAgingModel data, {
    required String langCode,
  }) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final labels = _labelsFor(langCode);
    final dateFmt = DateFormat('yyyy-MM-dd');
    final numFmt = NumberFormat('#,##0.00');
    final isRtl = langCode == 'ar';
    final dir = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final doc = pw.Document(title: labels['ar_aging']!);

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
          _table(data, labels, dateFmt, numFmt, dir),
          pw.SizedBox(height: 10),
          _totalsRow(data, labels, numFmt, dir),
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
            labels['ar_aging']!,
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
    ArAgingModel data,
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
            '${labels['as_of_date']}: ${dateFmt.format(data.asOfDate)}',
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
  // SUMMARY CARDS
  // ============================================
  static pw.Widget _summaryCards(
    ArAgingModel data,
    Map<String, String> labels,
    NumberFormat numFmt,
  ) {
    final cards = <(String, double, PdfColor)>[
      (labels['aging_current']!, data.totalCurrent, PdfColors.blue700),
      (labels['aging_1_30']!, data.total1To30, PdfColors.orange700),
      (labels['aging_31_60']!, data.total31To60, PdfColors.deepOrange700),
      (labels['aging_61_90']!, data.total61To90, PdfColors.red700),
      (labels['aging_90_plus']!, data.totalOver90, PdfColors.red900),
      (labels['grand_total']!, data.grandTotal, PdfColors.blueGrey900),
    ];

    return pw.Row(
      children: cards
          .map(
            (c) => pw.Expanded(
              child: pw.Container(
                margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: c.$3, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      c.$1,
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      numFmt.format(c.$2),
                      style: pw.TextStyle(
                        fontSize: 10,
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
    ArAgingModel data,
    Map<String, String> labels,
    DateFormat dateFmt,
    NumberFormat numFmt,
    pw.TextDirection dir,
  ) {
    final headers = [
      '#',
      labels['customer']!,
      labels['phone']!,
      labels['aging_current']!,
      labels['aging_1_30']!,
      labels['aging_31_60']!,
      labels['aging_61_90']!,
      labels['aging_90_plus']!,
      labels['total']!,
      labels['invoices_count']!,
    ];

    final rows = <List<String>>[];
    for (var i = 0; i < data.rows.length; i++) {
      final r = data.rows[i];
      rows.add([
        '${i + 1}',
        r.customerName,
        r.phone ?? '-',
        r.current > 0.001 ? numFmt.format(r.current) : '-',
        r.days1To30 > 0.001 ? numFmt.format(r.days1To30) : '-',
        r.days31To60 > 0.001 ? numFmt.format(r.days31To60) : '-',
        r.days61To90 > 0.001 ? numFmt.format(r.days61To90) : '-',
        r.over90 > 0.001 ? numFmt.format(r.over90) : '-',
        numFmt.format(r.totalOutstanding),
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
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
        8: pw.Alignment.centerRight,
        9: pw.Alignment.center,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(70),
        3: const pw.FixedColumnWidth(60),
        4: const pw.FixedColumnWidth(60),
        5: const pw.FixedColumnWidth(60),
        6: const pw.FixedColumnWidth(60),
        7: const pw.FixedColumnWidth(60),
        8: const pw.FixedColumnWidth(70),
        9: const pw.FixedColumnWidth(45),
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
    ArAgingModel data,
    Map<String, String> labels,
    NumberFormat numFmt,
    pw.TextDirection dir,
  ) {
    final cells = [
      labels['total']!,
      numFmt.format(data.totalCurrent),
      numFmt.format(data.total1To30),
      numFmt.format(data.total31To60),
      numFmt.format(data.total61To90),
      numFmt.format(data.totalOver90),
      numFmt.format(data.grandTotal),
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey100,
        border: pw.Border.all(
          color: PdfColors.blueGrey800,
          width: 0.8,
        ),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 60,
            child: pw.Text(
              cells[0],
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
          ...List.generate(6, (i) {
            final isGrand = i == 5;
            return pw.Expanded(
              child: pw.Text(
                cells[i + 1],
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: isGrand ? 11 : 9,
                  color: isGrand ? PdfColors.blueGrey900 : null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================
  // HELPERS
  // ============================================
  static String _fileName(ArAgingModel data) {
    final d = DateFormat('yyyyMMdd').format(data.asOfDate);
    return 'ar_aging_$d.pdf';
  }

  static Map<String, String> _labelsFor(String lang) {
    switch (lang) {
      case 'en':
        return {
          'ar_aging': 'Accounts Receivable Aging',
          'as_of_date': 'As of',
          'generated_on': 'Generated',
          'page': 'Page',
          'customer': 'Customer',
          'phone': 'Phone',
          'aging_current': 'Current',
          'aging_1_30': '1-30 Days',
          'aging_31_60': '31-60 Days',
          'aging_61_90': '61-90 Days',
          'aging_90_plus': '90+ Days',
          'total': 'Total',
          'grand_total': 'Grand Total',
          'invoices_count': 'Invoices',
        };
      case 'zh':
        return {
          'ar_aging': '应收账款账龄分析',
          'as_of_date': '截至',
          'generated_on': '生成于',
          'page': '页',
          'customer': '客户',
          'phone': '电话',
          'aging_current': '未到期',
          'aging_1_30': '1-30天',
          'aging_31_60': '31-60天',
          'aging_61_90': '61-90天',
          'aging_90_plus': '90天以上',
          'total': '合计',
          'grand_total': '总计',
          'invoices_count': '发票数',
        };
      default:
        return {
          'ar_aging': 'أعمار ديون العملاء',
          'as_of_date': 'كما في',
          'generated_on': 'تم الإنشاء',
          'page': 'صفحة',
          'customer': 'العميل',
          'phone': 'الهاتف',
          'aging_current': 'لم يستحق',
          'aging_1_30': '1-30 يوم',
          'aging_31_60': '31-60 يوم',
          'aging_61_90': '61-90 يوم',
          'aging_90_plus': 'أكثر من 90',
          'total': 'الإجمالي',
          'grand_total': 'الإجمالي العام',
          'invoices_count': 'فواتير',
        };
    }
  }
}
