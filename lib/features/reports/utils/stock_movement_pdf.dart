import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models/stock_movement_model.dart';

class StockMovementPdf {
  StockMovementPdf._();

  static Future<void> share(StockMovementModel data,
      {required String langCode}) async {
    final bytes = await _build(data, langCode: langCode);
    await Printing.sharePdf(bytes: bytes, filename: _fileName(data));
  }

  static Future<void> print(StockMovementModel data,
      {required String langCode}) async {
    final bytes = await _build(data, langCode: langCode);
    await Printing.layoutPdf(onLayout: (_) => bytes, name: _fileName(data));
  }

  static Future<Uint8List> _build(StockMovementModel data,
      {required String langCode}) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final labels = _labelsFor(langCode);
    final dateFmt = DateFormat('yyyy-MM-dd');
    final numFmt = NumberFormat('#,##0.00');
    final isRtl = langCode == 'ar';
    final dir = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final doc = pw.Document(title: labels['stock_movement']!);

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
        border: pw.Border(bottom: pw.BorderSide(width: 1)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text('SI EXPORTER OS',
              style: pw.TextStyle(
                  font: fontBold, fontSize: 18, color: PdfColors.blueGrey900),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 4),
          pw.Text(labels['stock_movement']!,
              style: pw.TextStyle(
                  font: fontBold, fontSize: 14, color: PdfColors.blueGrey700),
              textAlign: pw.TextAlign.center),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context ctx, Map<String, String> labels,
      StockMovementModel data, DateFormat dateFmt, pw.Font font) {
    final now = DateTime.now();
    final genDate = '${dateFmt.format(now)} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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

  static pw.Widget _summaryCards(StockMovementModel data,
      Map<String, String> labels, NumberFormat numFmt) {
    final cards = <(String, String, PdfColor)>[
      (
        labels['total_in']!,
        '${numFmt.format(data.totalIn)} (${data.inCount})',
        PdfColors.green700
      ),
      (
        labels['total_out']!,
        '${numFmt.format(data.totalOut)} (${data.outCount})',
        PdfColors.red700
      ),
      (
        labels['total_adjustment']!,
        '${numFmt.format(data.totalAdjustment)} (${data.adjustmentCount})',
        PdfColors.orange700
      ),
      (
        labels['total_movements']!,
        '${data.totalMovements}',
        PdfColors.blueGrey800
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
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: c.$3)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  static pw.Widget _table(StockMovementModel data, Map<String, String> labels,
      DateFormat dateFmt, NumberFormat numFmt) {
    final headers = [
      '#',
      labels['date']!,
      labels['product']!,
      labels['warehouse']!,
      labels['type']!,
      labels['quantity']!,
      labels['unit_price']!,
      labels['total_value']!,
    ];

    final rows = <List<String>>[];
    for (var i = 0; i < data.rows.length; i++) {
      final r = data.rows[i];
      rows.add([
        '${i + 1}',
        dateFmt.format(r.date),
        '${r.productCode} - ${r.productName}',
        r.warehouseName,
        _typeLabel(r.type, labels),
        numFmt.format(r.quantity),
        numFmt.format(r.unitPrice),
        numFmt.format(r.totalValue),
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
          fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.center,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        1: const pw.FixedColumnWidth(60),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FixedColumnWidth(60),
        5: const pw.FixedColumnWidth(60),
        6: const pw.FixedColumnWidth(60),
        7: const pw.FixedColumnWidth(70),
      },
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
    );
  }

  static String _typeLabel(StockMovementType t, Map<String, String> labels) {
    switch (t) {
      case StockMovementType.in_:
        return labels['in']!;
      case StockMovementType.out:
        return labels['out']!;
      case StockMovementType.adjustment:
        return labels['adjustment']!;
    }
  }

  static pw.Widget _totalsRow(StockMovementModel data,
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
              flex: 5,
              child: pw.Text(
                  '${labels['movements_count']}: ${data.totalMovements}',
                  style: const pw.TextStyle(fontSize: 9))),
          pw.Expanded(
              child: pw.Text(numFmt.format(data.totalIn),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                      color: PdfColors.green700))),
          pw.Expanded(
              child: pw.Text(numFmt.format(data.totalOut),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                      color: PdfColors.red700))),
          pw.Expanded(
              child: pw.Text(numFmt.format(data.totalAdjustment),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                      color: PdfColors.orange700))),
          pw.Expanded(
              child: pw.Text(
                  numFmt.format(data.totalInValue + data.totalOutValue),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 9))),
        ],
      ),
    );
  }

  static String _fileName(StockMovementModel data) {
    final from = DateFormat('yyyyMMdd').format(data.fromDate);
    final to = DateFormat('yyyyMMdd').format(data.toDate);
    return 'stock_movement_${from}_$to.pdf';
  }

  static Map<String, String> _labelsFor(String lang) {
    switch (lang) {
      case 'en':
        return {
          'stock_movement': 'Stock Movement',
          'period': 'Period',
          'generated_on': 'Generated',
          'page': 'Page',
          'date': 'Date',
          'product': 'Product',
          'warehouse': 'Warehouse',
          'type': 'Type',
          'quantity': 'Quantity',
          'unit_price': 'Unit Price',
          'total_value': 'Value',
          'in': 'In',
          'out': 'Out',
          'adjustment': 'Adjustment',
          'total': 'Total',
          'total_in': 'Total In',
          'total_out': 'Total Out',
          'total_adjustment': 'Total Adjustment',
          'total_movements': 'Total Movements',
          'movements_count': 'Movements',
        };
      case 'zh':
        return {
          'stock_movement': '库存变动',
          'period': '期间',
          'generated_on': '生成于',
          'page': '页',
          'date': '日期',
          'product': '产品',
          'warehouse': '仓库',
          'type': '类型',
          'quantity': '数量',
          'unit_price': '单价',
          'total_value': '价值',
          'in': '入库',
          'out': '出库',
          'adjustment': '调整',
          'total': '合计',
          'total_in': '入库合计',
          'total_out': '出库合计',
          'total_adjustment': '调整合计',
          'total_movements': '变动总数',
          'movements_count': '变动数',
        };
      default:
        return {
          'stock_movement': 'حركة المخزون',
          'period': 'الفترة',
          'generated_on': 'تم الإنشاء',
          'page': 'صفحة',
          'date': 'التاريخ',
          'product': 'المنتج',
          'warehouse': 'المستودع',
          'type': 'النوع',
          'quantity': 'الكمية',
          'unit_price': 'سعر الوحدة',
          'total_value': 'القيمة',
          'in': 'وارد',
          'out': 'صادر',
          'adjustment': 'تسوية',
          'total': 'الإجمالي',
          'total_in': 'إجمالي الوارد',
          'total_out': 'إجمالي الصادر',
          'total_adjustment': 'إجمالي التسويات',
          'total_movements': 'إجمالي الحركات',
          'movements_count': 'حركة',
        };
    }
  }
}
