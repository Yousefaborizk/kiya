import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../utils/unit_translator.dart';
import '../data/models/low_stock_model.dart';

class LowStockPdf {
  LowStockPdf._();

  static Future<void> share(
    LowStockModel data, {
    required String langCode,
  }) async {
    final bytes = await _build(data, langCode: langCode);
    await Printing.sharePdf(
      bytes: bytes,
      filename: _fileName(data),
    );
  }

  static Future<void> print(
    LowStockModel data, {
    required String langCode,
  }) async {
    final bytes = await _build(data, langCode: langCode);
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: _fileName(data),
    );
  }

  static Future<Uint8List> _build(
    LowStockModel data, {
    required String langCode,
  }) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final labels = _labelsFor(langCode);
    final dateFmt = DateFormat('yyyy-MM-dd');
    final numFmt = NumberFormat('#,##0.00');
    final isRtl = langCode == 'ar';
    final dir = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final doc = pw.Document(title: labels['low_stock']!);

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
          _table(data, labels, numFmt, langCode),
          pw.SizedBox(height: 10),
          _totalsRow(data, labels, numFmt),
        ],
      ),
    );

    return doc.save();
  }

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
            labels['low_stock']!,
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

  static pw.Widget _footer(
    pw.Context ctx,
    Map<String, String> labels,
    LowStockModel data,
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

  static pw.Widget _summaryCards(
    LowStockModel data,
    Map<String, String> labels,
    NumberFormat numFmt,
  ) {
    final cards = <(String, String, PdfColor)>[
      (
        labels['severity_out_of_stock']!,
        '${data.outOfStockCount}',
        PdfColors.red900,
      ),
      (
        labels['severity_critical']!,
        '${data.criticalCount}',
        PdfColors.red700,
      ),
      (
        labels['severity_low']!,
        '${data.lowCount}',
        PdfColors.orange700,
      ),
      (
        labels['total']!,
        '${data.totalCount}',
        PdfColors.blueGrey800,
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
                        fontSize: 14,
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

  static pw.Widget _table(
    LowStockModel data,
    Map<String, String> labels,
    NumberFormat numFmt,
    String langCode,
  ) {
    final headers = [
      '#',
      labels['product']!,
      labels['unit']!,
      labels['current_stock']!,
      labels['min_level']!,
      labels['shortfall']!,
      labels['severity']!,
    ];

    final rows = <List<String>>[];
    for (var i = 0; i < data.rows.length; i++) {
      final r = data.rows[i];
      rows.add([
        '${i + 1}',
        '${r.productCode} - ${r.productName}',
        UnitTranslator.translateForLocale(r.unit, langCode),
        numFmt.format(r.currentStock),
        '${r.minStockLevel}',
        numFmt.format(r.shortfall),
        _severityLabel(r.severity, labels),
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
        6: pw.Alignment.center,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(70),
        4: const pw.FixedColumnWidth(70),
        5: const pw.FixedColumnWidth(70),
        6: const pw.FixedColumnWidth(80),
      },
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      cellPadding: const pw.EdgeInsets.symmetric(
        horizontal: 3,
        vertical: 2.5,
      ),
    );
  }

  static String _severityLabel(
    LowStockSeverity s,
    Map<String, String> labels,
  ) {
    switch (s) {
      case LowStockSeverity.outOfStock:
        return labels['severity_out_of_stock']!;
      case LowStockSeverity.critical:
        return labels['severity_critical']!;
      case LowStockSeverity.low:
        return labels['severity_low']!;
    }
  }

  static pw.Widget _totalsRow(
    LowStockModel data,
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
            flex: 4,
            child: pw.Text(
              '${labels['products_count']}: ${data.totalCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.SizedBox(width: 100),
          pw.Expanded(
            child: pw.Text(
              numFmt.format(data.totalShortfall),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.red800,
              ),
            ),
          ),
          pw.SizedBox(width: 150),
        ],
      ),
    );
  }

  static String _fileName(LowStockModel data) {
    final d = DateFormat('yyyyMMdd').format(data.asOfDate);
    return 'low_stock_$d.pdf';
  }

  static Map<String, String> _labelsFor(String lang) {
    switch (lang) {
      case 'en':
        return {
          'low_stock': 'Low Stock Products',
          'as_of_date': 'As of',
          'generated_on': 'Generated',
          'page': 'Page',
          'product': 'Product',
          'unit': 'Unit',
          'current_stock': 'Current Stock',
          'min_level': 'Min Level',
          'shortfall': 'Shortfall',
          'severity': 'Severity',
          'severity_out_of_stock': 'Out of Stock',
          'severity_critical': 'Critical',
          'severity_low': 'Low',
          'total': 'Total',
          'products_count': 'Products',
        };
      case 'zh':
        return {
          'low_stock': '低库存产品',
          'as_of_date': '截至',
          'generated_on': '生成于',
          'page': '页',
          'product': '产品',
          'unit': '单位',
          'current_stock': '当前库存',
          'min_level': '最低库存',
          'shortfall': '缺口',
          'severity': '严重程度',
          'severity_out_of_stock': '缺货',
          'severity_critical': '紧急',
          'severity_low': '偏低',
          'total': '合计',
          'products_count': '产品数',
        };
      default:
        return {
          'low_stock': 'المنتجات تحت الحد الأدنى',
          'as_of_date': 'كما في',
          'generated_on': 'تم الإنشاء',
          'page': 'صفحة',
          'product': 'المنتج',
          'unit': 'الوحدة',
          'current_stock': 'المخزون الحالي',
          'min_level': 'الحد الأدنى',
          'shortfall': 'النقص',
          'severity': 'الحالة',
          'severity_out_of_stock': 'نفد',
          'severity_critical': 'حرج',
          'severity_low': 'منخفض',
          'total': 'الإجمالي',
          'products_count': 'منتج',
        };
    }
  }
}
