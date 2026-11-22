import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../utils/unit_translator.dart';
import '../data/models/stock_valuation_model.dart';

class StockValuationPdf {
  StockValuationPdf._();

  static Future<void> share(
    StockValuationModel data, {
    required String langCode,
  }) async {
    final bytes = await _build(data, langCode: langCode);
    await Printing.sharePdf(
      bytes: bytes,
      filename: _fileName(data),
    );
  }

  static Future<void> print(
    StockValuationModel data, {
    required String langCode,
  }) async {
    final bytes = await _build(data, langCode: langCode);
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: _fileName(data),
    );
  }

  static Future<Uint8List> _build(
    StockValuationModel data, {
    required String langCode,
  }) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final labels = _labelsFor(langCode);
    final dateFmt = DateFormat('yyyy-MM-dd');
    final numFmt = NumberFormat('#,##0.00');
    final isRtl = langCode == 'ar';
    final dir = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final doc = pw.Document(title: labels['stock_valuation']!);

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
            labels['stock_valuation']!,
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
    StockValuationModel data,
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
    StockValuationModel data,
    Map<String, String> labels,
    NumberFormat numFmt,
  ) {
    final cards = <(String, String, PdfColor)>[
      (
        labels['products_count']!,
        '${data.productCount}',
        PdfColors.blue700,
      ),
      (
        labels['total_cost_value']!,
        numFmt.format(data.totalCostValue),
        PdfColors.blueGrey700,
      ),
      (
        labels['total_sales_value']!,
        numFmt.format(data.totalSalesValue),
        PdfColors.green700,
      ),
      (
        labels['expected_profit']!,
        '${numFmt.format(data.totalExpectedProfit)}  '
            '(${data.overallProfitMargin.toStringAsFixed(1)}%)',
        PdfColors.green800,
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

  static pw.Widget _table(
    StockValuationModel data,
    Map<String, String> labels,
    NumberFormat numFmt,
    String langCode,
  ) {
    final headers = [
      '#',
      labels['product']!,
      labels['unit']!,
      labels['quantity']!,
      labels['purchase_price']!,
      labels['selling_price']!,
      labels['cost_value']!,
      labels['sales_value']!,
      labels['expected_profit']!,
      labels['margin']!,
    ];

    final rows = <List<String>>[];
    for (var i = 0; i < data.products.length; i++) {
      final p = data.products[i];
      rows.add([
        '${i + 1}',
        '${p.productCode} - ${p.productName}',
        UnitTranslator.translateForLocale(p.unit, langCode),
        numFmt.format(p.totalQuantity),
        numFmt.format(p.purchasePrice),
        numFmt.format(p.sellingPrice),
        numFmt.format(p.costValue),
        numFmt.format(p.salesValue),
        numFmt.format(p.expectedProfit),
        '${p.profitMargin.toStringAsFixed(1)}%',
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontSize: 7.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
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
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(35),
        3: const pw.FixedColumnWidth(50),
        4: const pw.FixedColumnWidth(55),
        5: const pw.FixedColumnWidth(55),
        6: const pw.FixedColumnWidth(60),
        7: const pw.FixedColumnWidth(60),
        8: const pw.FixedColumnWidth(60),
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

  static pw.Widget _totalsRow(
    StockValuationModel data,
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
              '${labels['products_count']}: ${data.productCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.SizedBox(width: 90),
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
          pw.SizedBox(width: 110),
          pw.Expanded(
            child: pw.Text(
              numFmt.format(data.totalCostValue),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.blueGrey800,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              numFmt.format(data.totalSalesValue),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.green700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              numFmt.format(data.totalExpectedProfit),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.green800,
              ),
            ),
          ),
          pw.SizedBox(width: 45),
        ],
      ),
    );
  }

  static String _fileName(StockValuationModel data) {
    final d = DateFormat('yyyyMMdd').format(data.asOfDate);
    return 'stock_valuation_$d.pdf';
  }

  static Map<String, String> _labelsFor(String lang) {
    switch (lang) {
      case 'en':
        return {
          'stock_valuation': 'Stock Valuation',
          'as_of_date': 'As of',
          'generated_on': 'Generated',
          'page': 'Page',
          'product': 'Product',
          'unit': 'Unit',
          'quantity': 'Qty',
          'purchase_price': 'Cost',
          'selling_price': 'Sell',
          'cost_value': 'Cost Value',
          'sales_value': 'Sales Value',
          'expected_profit': 'Profit',
          'margin': 'Margin',
          'total': 'Total',
          'products_count': 'Products',
          'total_cost_value': 'Total Cost',
          'total_sales_value': 'Total Sales',
        };
      case 'zh':
        return {
          'stock_valuation': '库存估值',
          'as_of_date': '截至',
          'generated_on': '生成于',
          'page': '页',
          'product': '产品',
          'unit': '单位',
          'quantity': '数量',
          'purchase_price': '成本',
          'selling_price': '售价',
          'cost_value': '成本价值',
          'sales_value': '销售价值',
          'expected_profit': '预期利润',
          'margin': '利润率',
          'total': '合计',
          'products_count': '产品数',
          'total_cost_value': '总成本',
          'total_sales_value': '总销售额',
        };
      default:
        return {
          'stock_valuation': 'تقييم المخزون',
          'as_of_date': 'كما في',
          'generated_on': 'تم الإنشاء',
          'page': 'صفحة',
          'product': 'المنتج',
          'unit': 'الوحدة',
          'quantity': 'الكمية',
          'purchase_price': 'التكلفة',
          'selling_price': 'البيع',
          'cost_value': 'قيمة التكلفة',
          'sales_value': 'قيمة البيع',
          'expected_profit': 'الربح المتوقع',
          'margin': 'هامش الربح',
          'total': 'الإجمالي',
          'products_count': 'منتج',
          'total_cost_value': 'إجمالي التكلفة',
          'total_sales_value': 'إجمالي البيع',
        };
    }
  }
}
