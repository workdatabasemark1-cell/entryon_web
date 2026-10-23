import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/service_model.dart';
import 'pdf_theme_helper.dart';

class ServicePdfGenerator {
  static Future<Uint8List> generate(
    ServiceEntry service, {
    String? customerPhone,
  }) async {
    final pdf = pw.Document();

    final purchaseTotal = service.purchaseLines.fold<double>(
      0,
      (total, line) => total + line.cost,
    );
    final balanceAmount = service.amount - service.customerPaidAmount;
    final isFree = service.paymentStatus.toLowerCase() == 'free';
    final isFullyPaid = balanceAmount <= 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(26),
        footer: (context) => PdfThemeHelper.buildPageFooter(
          context: context,
          documentName: 'Service Voucher | Ref: ${service.id}',
        ),
        build: (context) => [
          // Header
          PdfThemeHelper.buildDocumentHeader(
            title: 'SERVICE VOUCHER & INVOICE',
            subtitle: service.title,
            documentNo: service.id,
            badgeText: service.serviceStatus,
            badgeColor: service.serviceStatus.toLowerCase() == 'completed'
                ? PdfThemeHelper.emeraldGreen
                : PdfThemeHelper.amberWarning,
            badgeBgColor: service.serviceStatus.toLowerCase() == 'completed'
                ? PdfThemeHelper.emeraldGreenBg
                : PdfThemeHelper.amberWarningBg,
          ),

          // Financial KPI Summary Cards
          PdfThemeHelper.buildKpiCardsRow([
            PdfKpiItem(
              label: 'Service Fee',
              value: 'SAR ${service.serviceFee.toStringAsFixed(2)}',
              color: PdfThemeHelper.primaryTealDark,
            ),
            PdfKpiItem(
              label: 'Parts / Material',
              value: 'SAR ${purchaseTotal.toStringAsFixed(2)}',
              color: PdfThemeHelper.indigoAccent,
            ),
            PdfKpiItem(
              label: 'Total Amount',
              value: isFree ? 'Free' : 'SAR ${service.amount.toStringAsFixed(2)}',
              color: PdfThemeHelper.darkSlate,
            ),
            PdfKpiItem(
              label: 'Paid Amount',
              value: 'SAR ${service.customerPaidAmount.toStringAsFixed(2)}',
              color: PdfThemeHelper.emeraldGreen,
            ),
            PdfKpiItem(
              label: 'Balance Due',
              value: 'SAR ${balanceAmount.toStringAsFixed(2)}',
              color: balanceAmount > 0 ? PdfThemeHelper.roseRed : PdfThemeHelper.emeraldGreen,
            ),
          ]),

          pw.SizedBox(height: 6),

          // 2-Column Metadata Card (Customer Info on Left, Service Meta on Right)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left: Customer Information
              pw.Expanded(
                child: _buildInfoCard(
                  title: 'CUSTOMER INFORMATION',
                  rows: [
                    _InfoRow('Customer Name', service.customerName, isBold: true),
                    if (customerPhone?.trim().isNotEmpty == true)
                      _InfoRow('Phone', customerPhone!.trim()),
                    if (service.branchName?.trim().isNotEmpty == true)
                      _InfoRow('Branch', service.branchName!.trim()),
                    if (service.staffName?.trim().isNotEmpty == true)
                      _InfoRow(
                        'Staff Contact',
                        '${service.staffName!.trim()}${service.staffPhone?.trim().isNotEmpty == true ? ' (${service.staffPhone!.trim()})' : ''}',
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 10),

              // Right: Service & Order Metadata
              pw.Expanded(
                child: _buildInfoCard(
                  title: 'SERVICE METADATA',
                  rows: [
                    _InfoRow('Service Date', DateFormat('dd MMM yyyy').format(service.serviceDate)),
                    _InfoRow('Service Status', service.serviceStatus),
                    _InfoRow('Payment Status', service.paymentStatus),
                    _InfoRow('Payment Method', service.paymentType),
                    if (service.softwareName?.trim().isNotEmpty == true)
                      _InfoRow('Software / Node', service.softwareName!.trim()),
                    if (service.addedByName?.trim().isNotEmpty == true)
                      _InfoRow('Created By', service.addedByName!.trim()),
                  ],
                ),
              ),
            ],
          ),

          // Itemized Purchase / Parts Table
          if (service.purchaseLines.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            PdfThemeHelper.buildSectionHeader(
              'PARTS & MATERIAL LINES',
              countText: '${service.purchaseLines.length} items',
            ),
            pw.Container(
              decoration: pw.BoxDecoration(
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfThemeHelper.borderColor, width: 0.8),
              ),
              child: pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FixedColumnWidth(30),
                    1: const pw.FlexColumnWidth(4.5),
                    2: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfThemeHelper.darkSlate,
                      ),
                      children: [
                        _tableCell('#', isHeader: true, alignCenter: true),
                        _tableCell('Item Name / Description', isHeader: true),
                        _tableCell('Cost (SAR)', isHeader: true, alignRight: true),
                      ],
                    ),
                    // Item Rows
                    ...service.purchaseLines.asMap().entries.map((entry) {
                      final isEven = entry.key % 2 == 0;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: isEven ? PdfColors.white : PdfThemeHelper.surfaceBg,
                        ),
                        children: [
                          _tableCell('${entry.key + 1}', alignCenter: true),
                          _tableCell(entry.value.purchaseName),
                          _tableCell(
                            entry.value.cost.toStringAsFixed(2),
                            alignRight: true,
                            isBold: true,
                          ),
                        ],
                      );
                    }),
                    // Subtotal Footer
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfThemeHelper.zebraBg,
                        border: pw.Border(
                          top: pw.BorderSide(color: PdfThemeHelper.borderColor, width: 1),
                        ),
                      ),
                      children: [
                        _tableCell(''),
                        _tableCell('Parts Subtotal', isBold: true),
                        _tableCell(
                          'SAR ${purchaseTotal.toStringAsFixed(2)}',
                          alignRight: true,
                          isBold: true,
                          color: PdfThemeHelper.indigoAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Remarks / Notes Box
          if (service.description?.trim().isNotEmpty == true) ...[
            pw.SizedBox(height: 10),
            PdfThemeHelper.buildSectionHeader('REMARKS & SERVICE NOTES'),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfThemeHelper.surfaceBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfThemeHelper.borderColor, width: 0.8),
              ),
              child: pw.Text(
                service.description!.trim(),
                style: const pw.TextStyle(
                  fontSize: 9.5,
                  color: PdfThemeHelper.darkSlate,
                  lineSpacing: 1.4,
                ),
              ),
            ),
          ],

          pw.SizedBox(height: 18),

          // Settlement Banner / Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // Settlement status pill
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Payment Status:',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfThemeHelper.textMuted),
                  ),
                  pw.SizedBox(height: 3),
                  PdfThemeHelper.buildStatusBadge(
                    isFree ? 'Free Service' : (isFullyPaid ? 'Fully Settled' : 'Payment Outstanding'),
                  ),
                ],
              ),

              // Signature Line
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 140,
                    height: 1,
                    color: PdfThemeHelper.borderDark,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Authorized Signature',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfThemeHelper.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoCard({
    required String title,
    required List<_InfoRow> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfThemeHelper.surfaceBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfThemeHelper.borderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfThemeHelper.primaryTeal,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 6),
          ...rows.map((r) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3.5),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 80,
                      child: pw.Text(
                        r.label,
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: PdfThemeHelper.textMuted,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        r.value,
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: r.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                          color: PdfThemeHelper.darkSlate,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    bool alignRight = false,
    bool alignCenter = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: alignRight
            ? pw.TextAlign.right
            : (alignCenter ? pw.TextAlign.center : pw.TextAlign.left),
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 8.5,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : (color ?? PdfThemeHelper.darkSlate),
        ),
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  final bool isBold;

  const _InfoRow(this.label, this.value, {this.isBold = false});
}
