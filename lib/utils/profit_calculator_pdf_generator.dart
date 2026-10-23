// import 'dart:typed_data';

// import 'package:intl/intl.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;

// import 'pdf_theme_helper.dart';

// class ProfitCalculatorPdfGenerator {
//   static Future<Uint8List> generate({
//     String? customerName,
//     String? periodName,
//     String? vatNumber,
//     required double taxPct,
//     required bool enteredValuesIncludeVat,
//     required double salesExTax,
//     required double vatSales,
//     required double salesInTax,
//     required double purchasesExTax,
//     required double vatPurchases,
//     required double purchasesInTax,
//     required double grossProfit,
//     required double grossProfitInTax,
//     required double netVat,
//     required double margin,
//     required bool hasTarget,
//     required double targetProfit,
//     required double targetDiff,
//     required bool hasSales,
//     required bool hasPurchases,
//     required double reqSalesExTax,
//     required double allowPurchasesExTax,
//   }) async {
//     final pdf = pw.Document();
//     final fmt = NumberFormat('#,##0.00');

//     final isProfitable = grossProfit >= 0;
//     final costRatio = salesExTax > 0
//         ? (purchasesExTax / salesExTax) * 100
//         : 0.0;
//     final isNetVatPayable = netVat >= 0;
//     final targetMet = targetDiff >= 0;

//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         margin: const pw.EdgeInsets.all(26),
//         footer: (context) => PdfThemeHelper.buildPageFooter(
//           context: context,
//           documentName: 'Profit & Loss Statement | Entry On Business Suite',
//         ),
//         build: (context) => [
//           // ── Top Header ──────────────────────────────────────────────
//           PdfThemeHelper.buildDocumentHeader(
//             title: 'PROFIT & LOSS STATEMENT',
//             subtitle: 'Commercial Performance & ZATCA Tax Reconciliation',
//             documentNo:
//                 'P&L-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
//             badgeText: isProfitable
//                 ? 'MARGIN ${margin.toStringAsFixed(1)}%'
//                 : 'DEFICIT ${margin.toStringAsFixed(1)}%',
//             badgeColor: isProfitable
//                 ? PdfThemeHelper.emeraldGreen
//                 : PdfThemeHelper.roseRed,
//             badgeBgColor: isProfitable
//                 ? PdfThemeHelper.emeraldGreenBg
//                 : PdfThemeHelper.roseRedBg,
//           ),

//           // ── Executive KPI Cards ───────────────────────────────────────
//           PdfThemeHelper.buildKpiCardsRow([
//             PdfKpiItem(
//               label: 'Gross Profit (incl. VAT)',
//               value: 'SAR ${fmt.format(grossProfitInTax)}',
//               color: isProfitable
//                   ? PdfThemeHelper.emeraldGreen
//                   : PdfThemeHelper.roseRed,
//             ),
//             PdfKpiItem(
//               label: 'Net Operating Profit',
//               value: 'SAR ${fmt.format(grossProfit)}',
//               color: isProfitable
//                   ? PdfThemeHelper.primaryTealDark
//                   : PdfThemeHelper.roseRed,
//             ),
//             PdfKpiItem(
//               label: isNetVatPayable
//                   ? 'Net VAT Due to ZATCA'
//                   : 'Net VAT Refundable',
//               value: 'SAR ${fmt.format(netVat.abs())}',
//               color: isNetVatPayable
//                   ? PdfThemeHelper.indigoAccent
//                   : PdfThemeHelper.emeraldGreen,
//             ),
//             PdfKpiItem(
//               label: 'Profit Margin',
//               value: '${margin.toStringAsFixed(2)}%',
//               color: isProfitable
//                   ? PdfThemeHelper.emeraldGreen
//                   : PdfThemeHelper.roseRed,
//             ),
//           ]),

//           pw.SizedBox(height: 6),

//           // ── Metadata Card ───────────────────────────────────────────
//           pw.Container(
//             padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
//             decoration: pw.BoxDecoration(
//               color: PdfThemeHelper.surfaceBg,
//               borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
//               border: pw.Border.all(
//                 color: PdfThemeHelper.borderColor,
//                 width: 0.8,
//               ),
//             ),
//             child: pw.Row(
//               mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//               children: [
//                 _buildMetaItem(
//                   'CLIENT / ACCOUNT',
//                   customerName ?? 'General Business Analysis',
//                 ),
//                 _buildMetaItem(
//                   'PERIOD SECTION',
//                   periodName ?? 'Current Financial Period',
//                 ),
//                 _buildMetaItem(
//                   'APPLIED VAT RATE',
//                   '${taxPct.toStringAsFixed(0)}% Tax Rate',
//                 ),
//                 _buildMetaItem(
//                   'VALUATION BASIS',
//                   enteredValuesIncludeVat
//                       ? 'Gross (VAT Inclusive)'
//                       : 'Net (VAT Exclusive)',
//                 ),
//                 _buildMetaItem(
//                   'VAT NUMBER',
//                   vatNumber?.trim().isNotEmpty == true ? vatNumber!.trim() : '—',
//                 ),
//               ],
//             ),
//           ),

//           pw.SizedBox(height: 14),

//           // ── Primary Statement Table ─────────────────────────────────
//           PdfThemeHelper.buildSectionHeader('FINANCIAL STATEMENT BREAKDOWN'),
//           pw.SizedBox(height: 6),

//           pw.Container(
//             decoration: pw.BoxDecoration(
//               borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
//               border: pw.Border.all(
//                 color: PdfThemeHelper.borderColor,
//                 width: 0.8,
//               ),
//             ),
//             child: pw.Table(
//               columnWidths: const {
//                 0: pw.FlexColumnWidth(3.2),
//                 1: pw.FlexColumnWidth(2.2),
//                 2: pw.FlexColumnWidth(2.0),
//                 3: pw.FlexColumnWidth(2.2),
//                 4: pw.FlexColumnWidth(1.6),
//                 5: pw.FlexColumnWidth(1.8),
//               },
//               children: [
//                 // Header
//                 pw.TableRow(
//                   decoration: const pw.BoxDecoration(
//                     color: PdfThemeHelper.darkSlate,
//                   ),
//                   children: [
//                     _tableHeaderCell('LINE ITEM / ACCOUNT', isLeft: true),
//                     _tableHeaderCell('EXCL. VAT (SAR)'),
//                     _tableHeaderCell('VAT (${taxPct.toStringAsFixed(0)}%)'),
//                     _tableHeaderCell('INCL. VAT (SAR)'),
//                     _tableHeaderCell('% OF SALES'),
//                     _tableHeaderCell('TYPE'),
//                   ],
//                 ),
//                 // Row 1: Sales
//                 _tableDataRow(
//                   title: hasSales
//                       ? 'Sales Turnover / Revenue'
//                       : 'Calculated Sales (Target)',
//                   subtitle: hasSales
//                       ? 'Recognized commercial turnover'
//                       : 'Derived from target goal',
//                   excl: fmt.format(salesExTax),
//                   vat: fmt.format(vatSales),
//                   incl: fmt.format(salesInTax),
//                   ratio: '100.0%',
//                   badgeText: 'REVENUE',
//                   badgeColor: PdfThemeHelper.emeraldGreen,
//                   badgeBg: PdfThemeHelper.emeraldGreenBg,
//                   isEven: false,
//                 ),
//                 // Row 2: Purchases / COGS
//                 _tableDataRow(
//                   title: hasPurchases
//                       ? 'Purchases & Direct Costs (COGS)'
//                       : 'Allowable Purchases',
//                   subtitle: hasPurchases
//                       ? 'Direct cost of supplies / items'
//                       : 'Derived from target margin',
//                   excl: fmt.format(purchasesExTax),
//                   vat: fmt.format(vatPurchases),
//                   incl: fmt.format(purchasesInTax),
//                   ratio: '${costRatio.toStringAsFixed(1)}%',
//                   badgeText: 'EXPENSE',
//                   badgeColor: PdfThemeHelper.amberWarning,
//                   badgeBg: PdfThemeHelper.amberWarningBg,
//                   isEven: true,
//                 ),
//                 // Row 3: Gross Commercial Profit (Highlighted)
//                 _tableDataRow(
//                   title: 'Gross Commercial Profit',
//                   subtitle: isProfitable
//                       ? 'Net operational contribution'
//                       : 'Operational loss on transactions',
//                   excl: fmt.format(grossProfit),
//                   vat: fmt.format(netVat),
//                   incl: fmt.format(grossProfitInTax),
//                   ratio: '${margin.toStringAsFixed(1)}%',
//                   badgeText: isProfitable ? 'PROFIT' : 'DEFICIT',
//                   badgeColor: isProfitable
//                       ? PdfThemeHelper.primaryTealDark
//                       : PdfThemeHelper.roseRed,
//                   badgeBg: isProfitable
//                       ? PdfThemeHelper.primaryTealLight
//                       : PdfThemeHelper.roseRedBg,
//                   isHighlight: true,
//                   isEven: false,
//                 ),
//               ],
//             ),
//           ),

//           pw.SizedBox(height: 14),

//           // ── VAT & Cash Flow Reconciliation Box ──────────────────────
//           PdfThemeHelper.buildSectionHeader(
//             'TAX RECONCILIATION & CASH SUMMARY',
//           ),
//           pw.SizedBox(height: 6),

//           pw.Container(
//             padding: const pw.EdgeInsets.all(12),
//             decoration: pw.BoxDecoration(
//               color: PdfThemeHelper.surfaceBg,
//               borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
//               border: pw.Border.all(
//                 color: PdfThemeHelper.borderColor,
//                 width: 0.8,
//               ),
//             ),
//             child: pw.Row(
//               children: [
//                 _reconciliationCol(
//                   'OUTPUT VAT (SALES)',
//                   'SAR ${fmt.format(vatSales)}',
//                   'Collected on sales',
//                   PdfThemeHelper.emeraldGreen,
//                 ),
//                 _dividerV(),
//                 _reconciliationCol(
//                   'INPUT VAT (PURCHASES)',
//                   'SAR ${fmt.format(vatPurchases)}',
//                   'Deductible input tax',
//                   PdfThemeHelper.amberWarning,
//                 ),
//                 _dividerV(),
//                 _reconciliationCol(
//                   isNetVatPayable
//                       ? 'NET VAT DUE TO ZATCA'
//                       : 'NET VAT REFUNDABLE',
//                   'SAR ${fmt.format(netVat.abs())}',
//                   isNetVatPayable
//                       ? 'Remittance due to tax authority'
//                       : 'Refund / credit carried forward',
//                   isNetVatPayable
//                       ? PdfThemeHelper.indigoAccent
//                       : PdfThemeHelper.emeraldGreen,
//                   isBold: true,
//                 ),
//                 _dividerV(),
//                 _reconciliationCol(
//                   'NET CASH FLOW',
//                   'SAR ${fmt.format(grossProfitInTax)}',
//                   'Incl. VAT cash balance',
//                   isProfitable
//                       ? PdfThemeHelper.emeraldGreen
//                       : PdfThemeHelper.roseRed,
//                   isBold: true,
//                 ),
//               ],
//             ),
//           ),

//           // ── Target Performance & Variance Table (if set) ────────────
//           if (hasTarget) ...[
//             pw.SizedBox(height: 14),
//             PdfThemeHelper.buildSectionHeader(
//               'TARGET PERFORMANCE & VARIANCE ANALYSIS',
//             ),
//             pw.SizedBox(height: 6),

//             pw.Container(
//               decoration: pw.BoxDecoration(
//                 borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
//                 border: pw.Border.all(
//                   color: PdfThemeHelper.borderColor,
//                   width: 0.8,
//                 ),
//               ),
//               child: pw.Table(
//                 columnWidths: const {
//                   0: pw.FlexColumnWidth(3.5),
//                   1: pw.FlexColumnWidth(2.5),
//                   2: pw.FlexColumnWidth(2.5),
//                   3: pw.FlexColumnWidth(2.5),
//                   4: pw.FlexColumnWidth(2.0),
//                 },
//                 children: [
//                   pw.TableRow(
//                     decoration: const pw.BoxDecoration(
//                       color: PdfThemeHelper.darkSlate,
//                     ),
//                     children: [
//                       _tableHeaderCell('TARGET METRIC', isLeft: true),
//                       _tableHeaderCell('TARGET GOAL (SAR)'),
//                       _tableHeaderCell('ACTUAL RESULT (SAR)'),
//                       _tableHeaderCell('VARIANCE (SAR)'),
//                       _tableHeaderCell('STATUS'),
//                     ],
//                   ),
//                   pw.TableRow(
//                     decoration: const pw.BoxDecoration(color: PdfColors.white),
//                     children: [
//                       _tableCell(
//                         'Profit Goal Target',
//                         isBold: true,
//                         isLeft: true,
//                       ),
//                       _tableCell(fmt.format(targetProfit)),
//                       _tableCell(
//                         fmt.format(grossProfit),
//                         color: targetMet
//                             ? PdfThemeHelper.emeraldGreen
//                             : PdfThemeHelper.roseRed,
//                       ),
//                       _tableCell(
//                         '${targetDiff >= 0 ? '+' : ''}${fmt.format(targetDiff)}',
//                         color: targetMet
//                             ? PdfThemeHelper.emeraldGreen
//                             : PdfThemeHelper.roseRed,
//                         isBold: true,
//                       ),
//                       pw.Container(
//                         padding: const pw.EdgeInsets.symmetric(
//                           vertical: 6,
//                           horizontal: 6,
//                         ),
//                         alignment: pw.Alignment.center,
//                         child: PdfThemeHelper.buildBadge(
//                           targetMet ? 'ACHIEVED' : 'SHORTFALL',
//                           textColor: targetMet
//                               ? PdfThemeHelper.emeraldGreen
//                               : PdfThemeHelper.roseRed,
//                           bgColor: targetMet
//                               ? PdfThemeHelper.emeraldGreenBg
//                               : PdfThemeHelper.roseRedBg,
//                         ),
//                       ),
//                     ],
//                   ),
//                   if (hasPurchases && !hasSales)
//                     pw.TableRow(
//                       decoration: const pw.BoxDecoration(
//                         color: PdfThemeHelper.zebraBg,
//                       ),
//                       children: [
//                         _tableCell('Required Sales (excl. VAT)', isLeft: true),
//                         _tableCell(
//                           fmt.format(reqSalesExTax),
//                           color: PdfThemeHelper.primaryTealDark,
//                         ),
//                         _tableCell('0.00'),
//                         _tableCell(
//                           '-${fmt.format(reqSalesExTax)}',
//                           color: PdfThemeHelper.roseRed,
//                         ),
//                         pw.Container(
//                           padding: const pw.EdgeInsets.symmetric(
//                             vertical: 6,
//                             horizontal: 6,
//                           ),
//                           alignment: pw.Alignment.center,
//                           child: PdfThemeHelper.buildBadge(
//                             'PENDING SALES',
//                             textColor: PdfThemeHelper.amberWarning,
//                             bgColor: PdfThemeHelper.amberWarningBg,
//                           ),
//                         ),
//                       ],
//                     ),
//                   if (hasSales && !hasPurchases)
//                     pw.TableRow(
//                       decoration: const pw.BoxDecoration(
//                         color: PdfThemeHelper.zebraBg,
//                       ),
//                       children: [
//                         _tableCell(
//                           'Max Allowable Purchases (excl. VAT)',
//                           isLeft: true,
//                         ),
//                         _tableCell(
//                           fmt.format(allowPurchasesExTax),
//                           color: PdfThemeHelper.primaryTealDark,
//                         ),
//                         _tableCell('0.00'),
//                         _tableCell(
//                           '+${fmt.format(allowPurchasesExTax)}',
//                           color: PdfThemeHelper.emeraldGreen,
//                         ),
//                         pw.Container(
//                           padding: const pw.EdgeInsets.symmetric(
//                             vertical: 6,
//                             horizontal: 6,
//                           ),
//                           alignment: pw.Alignment.center,
//                           child: PdfThemeHelper.buildBadge(
//                             'ALLOWED CEILING',
//                             textColor: PdfThemeHelper.primaryTealDark,
//                             bgColor: PdfThemeHelper.primaryTealLight,
//                           ),
//                         ),
//                       ],
//                     ),
//                 ],
//               ),
//             ),
//           ],
//         ],
//       ),
//     );

//     return pdf.save();
//   }

//   // ── Helper Widgets ──────────────────────────────────────────────────────────

//   static pw.Widget _buildMetaItem(String label, String value) {
//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.start,
//       children: [
//         pw.Text(
//           label,
//           style: pw.TextStyle(
//             fontSize: 7.5,
//             color: PdfThemeHelper.textMuted,
//             fontWeight: pw.FontWeight.bold,
//           ),
//         ),
//         pw.SizedBox(height: 2),
//         pw.Text(
//           value,
//           style: pw.TextStyle(
//             fontSize: 9.5,
//             color: PdfThemeHelper.darkSlate,
//             fontWeight: pw.FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }

//   static pw.Widget _tableHeaderCell(String text, {bool isLeft = false}) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6.5),
//       alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
//       child: pw.Text(
//         text,
//         style: pw.TextStyle(
//           color: PdfColors.white,
//           fontSize: 7.5,
//           fontWeight: pw.FontWeight.bold,
//           letterSpacing: 0.3,
//         ),
//       ),
//     );
//   }

//   static pw.TableRow _tableDataRow({
//     required String title,
//     required String subtitle,
//     required String excl,
//     required String vat,
//     required String incl,
//     required String ratio,
//     required String badgeText,
//     required PdfColor badgeColor,
//     required PdfColor badgeBg,
//     bool isHighlight = false,
//     bool isEven = false,
//   }) {
//     return pw.TableRow(
//       decoration: pw.BoxDecoration(
//         color: isHighlight
//             ? PdfThemeHelper.primaryTealLight.flatten(
//                 background: PdfColors.white,
//               )
//             : (isEven ? PdfThemeHelper.zebraBg : PdfColors.white),
//       ),
//       children: [
//         // 0: Title & Subtitle
//         pw.Padding(
//           padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//           child: pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Text(
//                 title,
//                 style: pw.TextStyle(
//                   fontSize: 8.5,
//                   fontWeight: pw.FontWeight.bold,
//                   color: isHighlight
//                       ? PdfThemeHelper.primaryTealDark
//                       : PdfThemeHelper.darkSlate,
//                 ),
//               ),
//               pw.Text(
//                 subtitle,
//                 style: const pw.TextStyle(
//                   fontSize: 7,
//                   color: PdfThemeHelper.textMuted,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         // 1: Excl
//         _tableCell(
//           excl,
//           isBold: isHighlight,
//           color: isHighlight ? PdfThemeHelper.primaryTealDark : null,
//         ),
//         // 2: VAT
//         _tableCell(
//           vat,
//           color: isHighlight
//               ? PdfThemeHelper.primaryTealDark
//               : PdfThemeHelper.amberWarning,
//         ),
//         // 3: Incl
//         _tableCell(
//           incl,
//           isBold: isHighlight,
//           color: isHighlight ? PdfThemeHelper.primaryTealDark : null,
//         ),
//         // 4: Ratio
//         _tableCell(ratio, isBold: isHighlight),
//         // 5: Badge
//         pw.Container(
//           padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
//           alignment: pw.Alignment.center,
//           child: PdfThemeHelper.buildBadge(
//             badgeText,
//             textColor: badgeColor,
//             bgColor: badgeBg,
//             fontSize: 7.5,
//           ),
//         ),
//       ],
//     );
//   }

//   static pw.Widget _tableCell(
//     String text, {
//     bool isBold = false,
//     PdfColor? color,
//     bool isLeft = false,
//   }) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
//       alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
//       child: pw.Text(
//         text,
//         style: pw.TextStyle(
//           fontSize: 8.5,
//           fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
//           color: color ?? PdfThemeHelper.darkSlate,
//         ),
//       ),
//     );
//   }

//   static pw.Widget _reconciliationCol(
//     String label,
//     String value,
//     String desc,
//     PdfColor color, {
//     bool isBold = false,
//   }) {
//     return pw.Expanded(
//       child: pw.Padding(
//         padding: const pw.EdgeInsets.symmetric(horizontal: 6),
//         child: pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.start,
//           children: [
//             pw.Text(
//               label,
//               style: pw.TextStyle(
//                 fontSize: 7,
//                 fontWeight: pw.FontWeight.bold,
//                 color: PdfThemeHelper.textMuted,
//               ),
//             ),
//             pw.SizedBox(height: 2),
//             pw.Text(
//               value,
//               style: pw.TextStyle(
//                 fontSize: 10.5,
//                 fontWeight: pw.FontWeight.bold,
//                 color: color,
//               ),
//             ),
//             pw.SizedBox(height: 1),
//             pw.Text(
//               desc,
//               style: const pw.TextStyle(
//                 fontSize: 6.5,
//                 color: PdfThemeHelper.textSubtle,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   static pw.Widget _dividerV() {
//     return pw.Container(
//       width: 0.8,
//       height: 28,
//       color: PdfThemeHelper.borderColor,
//       margin: const pw.EdgeInsets.symmetric(horizontal: 4),
//     );
//   }
// }






import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/profit_calculation_model.dart';
import 'pdf_theme_helper.dart';

class ProfitCalculatorPdfGenerator {
  static Future<Uint8List> generate({
    String? customerName,
    String? periodName,
    String? vatNumber,
    required double taxPct,
    required bool enteredValuesIncludeVat,
    required double salesExTax,
    required double vatSales,
    required double salesInTax,
    required double purchasesExTax,
    required double vatPurchases,
    required double purchasesInTax,
    required double grossProfit,
    required double grossProfitInTax,
    required double netVat,
    required double margin,
    required bool hasTarget,
    required double targetProfit,
    required double targetDiff,
    required bool hasSales,
    required bool hasPurchases,
    required double reqSalesExTax,
    required double allowPurchasesExTax,
    pw.Document? document,
    bool saveDocument = true,
  }) async {
    final pdf = document ?? pw.Document();
    final fmt = NumberFormat('#,##0.00');

    final isNetVatPayable = netVat >= 0;

    // Map your existing values into the VAT form lines
    final standardRatedSales = salesExTax;
    final standardRatedPurchases = purchasesExTax;
    final totalSales = salesExTax;
    
    final totalPurchases = purchasesExTax;
    final totalVatDue = vatSales - vatPurchases;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── Top Header Bar ───────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F1F5F9'),
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'VAT Return Form',
                          style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#0F172A'),
                          ),
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          periodName ?? 'Q226',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColor.fromHex('#475569'),
                          ),
                        ),
                      ],
                    ),
                    pw.Expanded(child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(textAlign: pw.TextAlign.center,
                          customerName ?? 'USRA JAMEA',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#1E40AF'),
                          ),
                        ),
                        
                      ],
                    ),), // Spacer
                    
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // ── Period oval + VAT Number ─────────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Period oval
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColor.fromHex('#3B82F6'), width: 1.6),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                    ),
                    child: pw.Text(
                      periodName ?? '1/4/26 To 31/6/26',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#1E40AF'),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  // VAT Number
                  pw.Spacer(),
                  pw.Text('Vat Number: ', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  
                  pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Text(
                        vatNumber ?? '', // replace with real VAT number if you have it
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ),
                  
                  // small margin % badge (optional)
                  pw.SizedBox(width: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#FEF3C7'),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                      border: pw.Border.all(color: PdfColor.fromHex('#F59E0B')),
                    ),
                    child: pw.Text(
                      '${margin.toStringAsFixed(2)}%',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#92400E'),
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 12),

              // ── Column Headers ───────────────────────────────────────
              pw.Row(
                children: [
                  pw.Expanded(flex: 5, child: pw.SizedBox()),
                  _colHeader('Amount ( SAR )'),
                  _colHeader('Adjustment (SAR)'),
                  _colHeader('VAT Amount ( SAR )'),
                ],
              ),
              pw.SizedBox(height: 3),

              // ── VAT on Sales (Green) ─────────────────────────────CustomersList
              _buildSection(
                sideLabel: 'VAT on Sales',
                sideColor: PdfColor.fromHex('#16A34A'),
                rows: [
                  _formRow('1-Standard rated sales (15%)', standardRatedSales, 0, vatSales, highlight: true),
                  _formRow('2-Sales on which the government bears the VAT', 0, 0, 0),
                  _formRow('3-Zero rated domestic sales', 0, 0, 0),
                  _formRow('4-Exports', 0, 0, 0),
                  _formRow('5-Exempt sales', 0, 0, 0),
                  _formRow('6-Total Sales', totalSales, 0, vatSales, highlight: true, isTotal: true),
                ],
              ),

              pw.SizedBox(height: 8),

              // ── VAT on Purchases (Orange) ────────────────────────────
              _buildSection(
                sideLabel: 'VAT on Purchase',
                sideColor: PdfColor.fromHex('#F59E0B'),
                rows: [
                  _formRow('7-Standard rated domestic purchases (15%)', standardRatedPurchases, 0, vatPurchases, highlight: true),
                  _formRow('8-Imports subject to VAT paid on import (15%)', 0, 0, 0),
                  _formRow('9-Imports subject to VAT accounted for through the', 0, 0, 0),
                  _formRow('10-Zero rated purchases', 0, 0, 0),
                  _formRow('11-Exempt purchases', 0, 0, 0),
                  _formRow('12-Total purchases', totalPurchases, 0, vatPurchases, highlight: true, isTotal: true),
                ],
              ),

              pw.SizedBox(height: 12),

              // ── Lines 13-16 ──────────────────────────────────────────
              _summaryLine('13-Total VAT due for current period', totalVatDue, yellow: true),
              _summaryLine('14-Corrections from previous period ( between SAR ± 5000.00 )', 0),
              _summaryLine('15-VAT credit carried forward from previous period(s)', 0),
              _summaryLine(
                '16-Net VAT due (or reclaimed)',
                netVat,
                isFinal: true,
                isPositive: isNetVatPayable,
              ),

              pw.Spacer(),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  'ZATCA VAT Return • Generated by Entry On Business Suite • Tax rate: ${taxPct.toStringAsFixed(0)}%',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );

    return saveDocument ? pdf.save() : Uint8List(0);
  }

  /// Creates one PDF containing one statement page for each calculation.
  static Future<Uint8List> generateMultiple(
    List<ProfitCalculation> calculations,
  ) async {
    if (calculations.isEmpty) {
      throw ArgumentError('At least one calculation is required');
    }

    final pdf = pw.Document();
    for (final calculation in calculations) {
      final vatSales = calculation.salesWithTax - calculation.salesWithoutTax;
      final vatPurchases =
          calculation.purchasesWithTax - calculation.purchasesWithoutTax;
      final customerName = calculation.branchName?.trim().isNotEmpty == true
          ? calculation.customerName ?? 'General'
          : calculation.customerName;

      await generate(
        document: pdf,
        saveDocument: false,
        customerName: customerName,
        periodName: calculation.periodName,
        vatNumber: calculation.vatNumber,
        taxPct: calculation.taxPercent,
        enteredValuesIncludeVat: calculation.enteredValuesIncludeVat,
        salesExTax: calculation.salesWithoutTax,
        vatSales: vatSales,
        salesInTax: calculation.salesWithTax,
        purchasesExTax: calculation.purchasesWithoutTax,
        vatPurchases: vatPurchases,
        purchasesInTax: calculation.purchasesWithTax,
        grossProfit: calculation.grossProfit,
        grossProfitInTax:
            calculation.salesWithTax - calculation.purchasesWithTax,
        netVat: calculation.netVatDue,
        margin: calculation.profitMargin,
        hasTarget: calculation.targetProfitAmount > 0 ||
            calculation.targetProfitPercent > 0,
        targetProfit: calculation.targetProfit,
        targetDiff: calculation.grossProfit - calculation.targetProfit,
        hasSales: calculation.enteredSales > 0,
        hasPurchases: calculation.enteredPurchases > 0,
        reqSalesExTax: 0,
        allowPurchasesExTax: 0,
      );
    }

    return pdf.save();
  }

  /// Creates a complete Arabic, right-to-left version of the selected statements.
  static Future<Uint8List> generateMultipleArabic(
    List<ProfitCalculation> calculations,
  ) async {
    if (calculations.isEmpty) {
      throw ArgumentError('At least one calculation is required');
    }

    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansArabic-Regular.ttf',
    );
    final arabicFont = pw.Font.ttf(fontData);
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: arabicFont,
        bold: arabicFont,
      ),
    );
    final fmt = NumberFormat('#,##0.00');

    for (final calculation in calculations) {
      final vatSales = calculation.salesWithTax - calculation.salesWithoutTax;
      final vatPurchases =
          calculation.purchasesWithTax - calculation.purchasesWithoutTax;
      final customer = calculation.branchName?.trim().isNotEmpty == true
          ? '${calculation.customerName ?? 'عام'} '
          : (calculation.customerName ?? 'عام');
      final isPayable = calculation.netVatDue >= 0;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(10, 10, 10, 10),
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
          build: (context) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F1F5F9'),
                    border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          customer,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#1E40AF'),
                          ),
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'نموذج إقرار ضريبة القيمة المضافة',
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#0F172A'),
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            calculation.periodName ?? 'بدون فترة',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColor.fromHex('#475569'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                            color: PdfColor.fromHex('#CBD5E1')),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(3),
                        ),
                      ),
                      child: pw.Text(
                        calculation.vatNumber?.trim().isNotEmpty == true
                            ? calculation.vatNumber!.trim()
                            : '—',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.SizedBox(width: 5),
                    pw.Text('الرقم الضريبي',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Spacer(),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                            color: PdfColor.fromHex('#3B82F6'), width: 1.6),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(20),
                        ),
                      ),
                      child: pw.Text(
                        calculation.periodName ?? 'بدون فترة',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1E40AF'),
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                _arabicColumnHeaders(),
                pw.SizedBox(height: 3),
                _buildSection(
                  sideLabel: 'المبيعات',
                  sideColor: PdfColor.fromHex('#16A34A'),
                  rows: [
                    _formRow('1-المبيعات الخاضعة للنسبة الأساسية',
                        calculation.salesWithoutTax, 0, vatSales,
                        highlight: true),
                    _formRow('2-مبيعات تتحمل الحكومة ضريبتها', 0, 0, 0),
                    _formRow('3-المبيعات المحلية ذات النسبة الصفرية', 0, 0, 0),
                    _formRow('4-الصادرات', 0, 0, 0),
                    _formRow('5-المبيعات المعفاة', 0, 0, 0),
                    _formRow('6-إجمالي المبيعات', calculation.salesWithoutTax,
                        0, vatSales, highlight: true, isTotal: true),
                  ],
                ),
                pw.SizedBox(height: 8),
                _buildSection(
                  sideLabel: 'المشتريات',
                  sideColor: PdfColor.fromHex('#F59E0B'),
                  rows: [
                    _formRow('7-المشتريات المحلية الخاضعة للنسبة الأساسية',
                        calculation.purchasesWithoutTax, 0, vatPurchases,
                        highlight: true),
                    _formRow('8-الواردات مع ضريبة مدفوعة عند الاستيراد', 0, 0, 0),
                    _formRow('9-الواردات الخاضعة للاحتساب العكسي', 0, 0, 0),
                    _formRow('10-المشتريات ذات النسبة الصفرية', 0, 0, 0),
                    _formRow('11-المشتريات المعفاة', 0, 0, 0),
                    _formRow('12-إجمالي المشتريات',
                        calculation.purchasesWithoutTax, 0, vatPurchases,
                        highlight: true, isTotal: true),
                  ],
                ),
                pw.SizedBox(height: 10),
                _summaryLine('13-إجمالي الضريبة المستحقة للفترة الحالية',
                    calculation.netVatDue,
                    yellow: true),
                _summaryLine('14-التعديلات من الفترة السابقة', 0),
                _summaryLine('15-الرصيد الدائن المرحل', 0),
                _summaryLine('16-صافي الضريبة المستحقة أو المستردة',
                    calculation.netVatDue,
                    isFinal: true,
                    isPositive: isPayable),
                pw.Spacer(),
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8FAFC'),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'إقرار ضريبة القيمة المضافة من Entry On Business Suite | نسبة الضريبة: ${calculation.taxPercent.toStringAsFixed(0)}% | الربح: ${fmt.format(calculation.grossProfit)} ريال',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _arabicColumnHeaders() {
    return pw.Row(
      children: [
        pw.Expanded(flex: 5, child: pw.SizedBox()),
        _colHeader('المبلغ (ريال)'),
        _colHeader('التعديلات (ريال)'),
        _colHeader('مبلغ الضريبة (ريال)'),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Helper widgets that recreate the form look
  // ─────────────────────────────────────────────────────────────────────

  static pw.Widget _colHeader(String text) {
    return pw.Expanded(
      flex: 2,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey700,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildSection({
    required String sideLabel,
    required PdfColor sideColor,
    required List<pw.Widget> rows,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Vertical colored sidebar with rotated text
        pw.Container(
          //  width: 26,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, ),
          height:150,
          decoration: pw.BoxDecoration(
            color: sideColor,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(4),
              bottomLeft: pw.Radius.circular(4),
            ),
          ),
          child: pw.Center(
            child: pw.Transform.rotateBox(
              angle: -1.5708, // -90 degrees
              child: pw.Text(
                sideLabel,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        // Content
        pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFC'),
              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
              borderRadius: const pw.BorderRadius.only(
                topRight: pw.Radius.circular(4),
                bottomRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Column(children: rows),
          ),
        ),
      ],
    );
  }

  static pw.Widget _formRow(
    String label,
    double amount,
    double adjustment,
    double vat, {
    bool highlight = false,
    bool isTotal = false,
  }) {
    final fmt = NumberFormat('#,##0.00');
    final bg = highlight ? PdfColor.fromHex('#FEF3C7') : PdfColors.white;
    final borderC = highlight ? PdfColor.fromHex('#F59E0B') : PdfColor.fromHex('#E2E8F0');

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border(bottom: pw.BorderSide(color: borderC, width: 0.7)),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 6),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 5,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: PdfColor.fromHex('#1E293B'),
              ),
            ),
          ),
          _cell(fmt.format(amount), highlight: highlight, bold: isTotal || highlight),
          _cell(fmt.format(adjustment)),
          _cell(fmt.format(vat), highlight: highlight, bold: isTotal || highlight),
        ],
      ),
    );
  }

  static pw.Widget _cell(String text, {bool highlight = false, bool bold = false}) {
    return pw.Expanded(
      flex: 2,
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 2),
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        decoration: pw.BoxDecoration(
          color: highlight ? PdfColor.fromHex('#FDE68A') : PdfColors.white,
          border: pw.Border.all(
            color: highlight ? PdfColor.fromHex('#D97706') : PdfColor.fromHex('#CBD5E1'),
            width: 0.8,
          ),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
        ),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
          textAlign: pw.TextAlign.right,
        ),
      ),
    );
  }

  static pw.Widget _summaryLine(
    String label,
    double value, {
    bool yellow = false,
    bool isFinal = false,
    bool isPositive = true,
  }) {
    final fmt = NumberFormat('#,##0.00');

    PdfColor bg = PdfColors.white;
    PdfColor border = PdfColor.fromHex('#E2E8F0');
    PdfColor textC = PdfColor.fromHex('#1E293B');

    if (isFinal) {
      bg = isPositive ? PdfColor.fromHex('#D1FAE5') : PdfColor.fromHex('#FEE2E2');
      border = isPositive ? PdfColor.fromHex('#10B981') : PdfColor.fromHex('#EF4444');
      textC = isPositive ? PdfColor.fromHex('#065F46') : PdfColor.fromHex('#991B1B');
    } else if (yellow) {
      bg = PdfColor.fromHex('#FEF3C7');
      border = PdfColor.fromHex('#F59E0B');
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 3),
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border.all(color: border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: isFinal || yellow ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: textC,
              ),
            ),
          ),
          pw.Container(
            width: 100,
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            decoration: pw.BoxDecoration(
              color: isFinal ? bg : (yellow ? PdfColor.fromHex('#FDE68A') : PdfColors.white),
              border: pw.Border.all(color: border),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
            child: pw.Text(
              fmt.format(value),
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: textC,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}