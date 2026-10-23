import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Global Design System & Helper for all generated PDFs in Entry On
class PdfThemeHelper {
  // Brand & Palette Colors
  static const PdfColor primaryTeal = PdfColor.fromInt(0xFF0D9488);
  static const PdfColor primaryTealDark = PdfColor.fromInt(0xFF0F766E);
  static const PdfColor primaryTealLight = PdfColor.fromInt(0xFFCCFBF1);
  static const PdfColor primaryTealBg = PdfColor.fromInt(0xFFF0FDFA);

  static const PdfColor darkSlate = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor darkSlateLight = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF64748B);
  static const PdfColor textSubtle = PdfColor.fromInt(0xFF94A3B8);

  static const PdfColor surfaceBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor zebraBg = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor borderColor = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor borderDark = PdfColor.fromInt(0xFFCBD5E1);

  // Status & Accent Colors
  static const PdfColor emeraldGreen = PdfColor.fromInt(0xFF10B981);
  static const PdfColor emeraldGreenBg = PdfColor.fromInt(0xFFECFDF5);
  static const PdfColor emeraldGreenBorder = PdfColor.fromInt(0xFFA7F3D0);

  static const PdfColor amberWarning = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor amberGold = PdfColor.fromInt(0xFFF59E0B); // alias
  static const PdfColor amberWarningBg = PdfColor.fromInt(0xFFFFFBEB);
  static const PdfColor amberWarningBorder = PdfColor.fromInt(0xFFFDE68A);

  static const PdfColor indigoAccent = PdfColor.fromInt(0xFF6366F1);
  static const PdfColor indigoAccentBg = PdfColor.fromInt(0xFFEEF2FF);
  static const PdfColor indigoAccentBorder = PdfColor.fromInt(0xFFC7D2FE);

  static const PdfColor roseRed = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor roseRedBg = PdfColor.fromInt(0xFFFEF2F2);
  static const PdfColor roseRedBorder = PdfColor.fromInt(0xFFFECACA);

  /// Builds a top header banner with brand identity and document title
  static pw.Widget buildDocumentHeader({
    required String title,
    String? subtitle,
    String? documentNo,
    String? dateText,
    String? badgeText,
    PdfColor? badgeColor,
    PdfColor? badgeBgColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Top accent line
        pw.Container(
          height: 3.5,
          decoration: const pw.BoxDecoration(
            color: primaryTeal,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(height: 14),

        // Brand + Title Row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: Brand & Document Title
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Logo Box
                  pw.Container(
                    width: 38,
                    height: 38,
                    decoration: pw.BoxDecoration(
                      color: primaryTeal,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'EO',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'ENTRY ON',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryTeal,
                            letterSpacing: 1.2,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          title,
                          style: pw.TextStyle(
                            fontSize: 17,
                            fontWeight: pw.FontWeight.bold,
                            color: darkSlate,
                          ),
                        ),
                        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            subtitle,
                            style: const pw.TextStyle(
                              fontSize: 9.5,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Right: Date & Metadata
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (badgeText != null && badgeText.trim().isNotEmpty) ...[
                  buildBadge(
                    badgeText,
                    textColor: badgeColor ?? primaryTealDark,
                    bgColor: badgeBgColor ?? primaryTealBg,
                  ),
                  pw.SizedBox(height: 6),
                ],
                if (documentNo != null && documentNo.trim().isNotEmpty)
                  pw.Text(
                    'Ref: $documentNo',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: darkSlate,
                    ),
                  ),
                pw.SizedBox(height: 2),
                pw.Text(
                  dateText ?? 'Date: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          height: 1,
          color: borderColor,
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  /// Builds a pill-shaped status or category badge
  static pw.Widget buildBadge(
    String label, {
    PdfColor textColor = primaryTealDark,
    PdfColor bgColor = primaryTealBg,
    PdfColor? borderColor,
    double fontSize = 8.5,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        border: pw.Border.all(
          color: borderColor ?? textColor,
          width: 0.6,
        ),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  /// Resolves status to appropriate badge widget
  static pw.Widget buildStatusBadge(String status) {
    final lower = status.trim().toLowerCase();
    if (lower == 'paid' || lower == 'completed' || lower == 'settled' || lower == 'received') {
      return buildBadge(
        status,
        textColor: emeraldGreen,
        bgColor: emeraldGreenBg,
        borderColor: emeraldGreenBorder,
      );
    } else if (lower == 'pending' || lower == 'work in progress' || lower == 'partial') {
      return buildBadge(
        status,
        textColor: amberWarning,
        bgColor: amberWarningBg,
        borderColor: amberWarningBorder,
      );
    } else if (lower == 'free' || lower == 'card') {
      return buildBadge(
        status,
        textColor: indigoAccent,
        bgColor: indigoAccentBg,
        borderColor: indigoAccentBorder,
      );
    } else if (lower == 'cancelled' || lower == 'failed' || lower == 'deleted') {
      return buildBadge(
        status,
        textColor: roseRed,
        bgColor: roseRedBg,
        borderColor: roseRedBorder,
      );
    }
    return buildBadge(status);
  }

  /// Builds a row of summary metric cards (KPIs)
  static pw.Widget buildKpiCardsRow(List<PdfKpiItem> items) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        children: items.map((item) {
          return pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 3),
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: surfaceBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: borderColor, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    item.label.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    item.value,
                    style: pw.TextStyle(
                      fontSize: 12.5,
                      fontWeight: pw.FontWeight.bold,
                      color: item.color ?? darkSlate,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Section title with accent vertical bar
  static pw.Widget buildSectionHeader(String title, {String? countText}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
      child: pw.Row(
        children: [
          pw.Container(
            width: 3,
            height: 12,
            decoration: const pw.BoxDecoration(
              color: primaryTeal,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(1.5)),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: darkSlate,
            ),
          ),
          if (countText != null) ...[
            pw.SizedBox(width: 6),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: pw.BoxDecoration(
                color: zebraBg,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                countText,
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Clean document footer with page numbers & timestamp
  static pw.Widget buildPageFooter({
    required pw.Context context,
    String? documentName,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: borderColor, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            documentName ?? 'Entry On | Business Intelligence & Service Hub',
            style: const pw.TextStyle(
              fontSize: 8,
              color: textSubtle,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class PdfKpiItem {
  final String label;
  final String value;
  final PdfColor? color;

  const PdfKpiItem({
    required this.label,
    required this.value,
    this.color,
  });
}
