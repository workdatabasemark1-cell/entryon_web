import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pluto_grid/pluto_grid.dart';

import '../models/purchase_entry_model.dart';
import '../providers/customer_provider.dart';
import '../utils/app_theme.dart';
import '../utils/file_name_utils.dart';
import '../utils/pdf_actions.dart';
import '../utils/pdf_theme_helper.dart';
import '../utils/responsive.dart';
import 'editPurchaseEntryScreen.dart';
import 'purchaseEntryDetailsScreen.dart';
import 'purchaseEntryScreen.dart';

enum ViewMode { grid, table }

class PurchaseEntriesListScreen extends StatefulWidget {
  const PurchaseEntriesListScreen({super.key});

  @override
  State<PurchaseEntriesListScreen> createState() =>
      _PurchaseEntriesListScreenState();
}

class _PurchaseEntriesListScreenState extends State<PurchaseEntriesListScreen> {
  final _searchController = TextEditingController();
  List<PurchaseInvoice> _allInvoices = [];
  List<PurchaseInvoice> _filteredInvoices = [];
  bool _isLoading = false;

  // Period sections
  List<Map<String, String>> _periods = [];
  bool _periodsLoading = true;
  Set<String> _selectedPeriodIds = {}; // empty = all

  // ── Filter state ──────────────────────────────────────────────────────────
  String _filterType = 'all'; // all | today | week | month | custom
  DateTime? _customFrom;
  DateTime? _customTo;
  ViewMode _viewMode = ViewMode.grid;

  @override
  void initState() {
    super.initState();
    _fetchPeriods();
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPeriods() async {
    setState(() => _periodsLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('period_sections')
          .orderBy('sectionNumber')
          .get();
      _periods = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': (data['name'] ?? '').toString(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching periods: $e');
      _periods = [];
    } finally {
      if (mounted) setState(() => _periodsLoading = false);
    }
  }

  // ── Data loading ──────────────────────────────────────────────────────────
  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await _fetchAllInvoices();
      if (!mounted) return;
      setState(() {
        _allInvoices = invoices;
        _filteredInvoices = invoices;
      });
      if (invoices.isEmpty) _showMsg('No invoices found', Colors.orange);
    } catch (e) {
      if (mounted) _showMsg('Error loading invoices: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<PurchaseInvoice>> _fetchAllInvoices() async {
    final db = FirebaseFirestore.instance;
    final snapshot = await db.collection('purchase_invoices').get();

    List<PurchaseInvoice> invoices = [];
    for (var doc in snapshot.docs) {
      try {
        final itemsSnapshot = await doc.reference.collection('items').get();
        final items = itemsSnapshot.docs
            .map((d) => PurchaseItem.fromMap(d.data()))
            .toList();
        final invoice = PurchaseInvoice.fromMap(doc.data(), items);
        invoices.add(PurchaseInvoice(
          id: doc.id,
          customerId: invoice.customerId,
          customerName: invoice.customerName,
          customerVatNumber: invoice.customerVatNumber,
          supplierId: invoice.supplierId,
          supplierName: invoice.supplierName,
          invoiceNo: invoice.invoiceNo,
          invoiceDate: invoice.invoiceDate,
          items: items,
          createdAt: invoice.createdAt,
          periodSectionId: invoice.periodSectionId,
          periodSectionName: invoice.periodSectionName,
        ));
      } catch (e) {
        debugPrint('Error parsing invoice ${doc.id}: $e');
      }
    }
    invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return invoices;
  }

  // ── Filtering logic ───────────────────────────────────────────────────────
  void _applyFilters({String? query}) {
    final q = query ?? _searchController.text;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _filteredInvoices = _allInvoices.where((inv) {
        // Search match
        final matchesSearch = q.isEmpty ||
            inv.customerName.toLowerCase().contains(q.toLowerCase()) ||
            inv.supplierName.toLowerCase().contains(q.toLowerCase()) ||
            inv.invoiceNo.contains(q);

        if (!matchesSearch) return false;

        // Date match against createdAt
        final invDate = DateTime(
            inv.createdAt.year, inv.createdAt.month, inv.createdAt.day);

        bool matchesDate = false;
        switch (_filterType) {
          case 'today':
            matchesDate = invDate.isAtSameMomentAs(today);
            break;
          case 'week':
            matchesDate = !invDate
                .isBefore(today.subtract(const Duration(days: 7)));
            break;
          case 'month':
            matchesDate = !invDate
                .isBefore(today.subtract(const Duration(days: 30)));
            break;
          case 'custom':
            if (_customFrom == null && _customTo == null) {
              matchesDate = true;
            } else {
              final from = _customFrom != null
                  ? DateTime(_customFrom!.year, _customFrom!.month,
                      _customFrom!.day)
                  : null;
              final to = _customTo != null
                  ? DateTime(
                      _customTo!.year, _customTo!.month, _customTo!.day)
                  : null;
              final afterFrom = from == null || !invDate.isBefore(from);
              final beforeTo = to == null || !invDate.isAfter(to);
              matchesDate = afterFrom && beforeTo;
            }
            break;
          default: // 'all'
            matchesDate = true;
            break;
        }

        if (!matchesDate) return false;

        // Period section filter: if periods selected, require match
        if (_selectedPeriodIds.isNotEmpty) {
          if (!_selectedPeriodIds.contains(inv.periodSectionId)) return false;
        }
        return true;
      }).toList();
    });
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _filterType != 'all' ||
      _selectedPeriodIds.isNotEmpty ||
      _customFrom != null ||
      _customTo != null;

  void _resetAllFilters() {
    setState(() {
      _searchController.clear();
      _filterType = 'all';
      _customFrom = null;
      _customTo = null;
      _selectedPeriodIds.clear();
    });
    _applyFilters();
  }

  // ── Date range picker ─────────────────────────────────────────────────────
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: (_customFrom != null && _customTo != null)
          ? DateTimeRange(start: _customFrom!, end: _customTo!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)), end: now),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.accent(context),
            onPrimary: Colors.white,
            surface: AppTheme.surfaceBg(context),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _customFrom = picked.start;
        _customTo = picked.end;
        _filterType = 'custom';
      });
      _applyFilters();
    }
  }

  void _clearDateRange() {
    setState(() {
      _customFrom = null;
      _customTo = null;
      _filterType = 'all';
    });
    _applyFilters();
  }

  // ── Show period selection dialog ──────────────────────────────────────────
  Future<void> _showPeriodSelectDialog() async {
    final selectedCopy = Set<String>.from(_selectedPeriodIds);

    await Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 440,
      child: StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
          padding: const EdgeInsets.all(20),
          color: AppTheme.surfaceBg(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter by Period Sections',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: AppTheme.textSecondary(context)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                activeColor: AppTheme.accent(context),
                contentPadding: EdgeInsets.zero,
                value: selectedCopy.length == _periods.length && _periods.isNotEmpty,
                onChanged: (val) {
                  setDialogState(() {
                    if (val == true) {
                      selectedCopy.addAll(_periods.map((p) => p['id']!));
                    } else {
                      selectedCopy.clear();
                    }
                  });
                },
                title: Text('All Periods',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context))),
                dense: true,
              ),
              Divider(color: AppTheme.cardBorderColor(context)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(
                  child: Column(
                    children: _periods.map((period) {
                      final id = period['id']!;
                      final name = period['name']!;
                      return CheckboxListTile(
                        activeColor: AppTheme.accent(context),
                        contentPadding: EdgeInsets.zero,
                        value: selectedCopy.contains(id),
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedCopy.add(id);
                            } else {
                              selectedCopy.remove(id);
                            }
                          });
                        },
                        title: Text(name,
                            style: TextStyle(
                                color: AppTheme.textPrimary(context))),
                        dense: true,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style: TextStyle(color: AppTheme.textSecondary(context))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent(context),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      setState(() => _selectedPeriodIds = selectedCopy);
                      _applyFilters();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> _deleteInvoice(String invoiceId) async {
    final confirm = await Responsive.showAdaptiveDialog<bool>(
      context: context,
      maxWidth: 420,
      child: Container(
        padding: const EdgeInsets.all(20),
        color: AppTheme.surfaceBg(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.alertTriangle,
                      color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Delete Invoice',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to delete this invoice? This action cannot be undone.',
              style: TextStyle(
                  color: AppTheme.textSecondary(context),
                  fontSize: 13.5,
                  height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel',
                      style: TextStyle(color: AppTheme.textSecondary(context))),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('purchase_invoices')
            .doc(invoiceId)
            .delete();
        _showMsg('Invoice deleted successfully', Colors.green);
        _loadInvoices();
      } catch (e) {
        _showMsg('Error deleting: $e', Colors.red);
      }
    }
  }

  // ── PDF Export ────────────────────────────────────────────────────────────
  Future<void> _exportToPdf(
    PurchaseInvoice invoice, [
    List<PurchaseItem>? filteredItems,
  ]) async {
    final itemsToExport = filteredItems ?? invoice.items;
    try {
      final customerProvider = context.read<CustomerProvider>();
      final customer = await customerProvider.getCustomerById(
        invoice.customerId,
      );

      // Arabic font fallback
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSansArabic-Regular.ttf',
      );
      final arabicFont = pw.Font.ttf(fontData);

      // Financial totals
      final totalExVat = itemsToExport.fold<double>(
          0, (total, i) => total + i.amountExVat);
      final totalVat = itemsToExport.fold<double>(
          0, (total, i) => total + i.vatAmount);
      final totalIncVat = itemsToExport.fold<double>(
          0, (total, i) => total + i.totalIncVat);

      final customerName = customer?.name ?? invoice.customerName;
      final invoiceDateStr =
          DateFormat('dd/MM/yyyy').format(invoice.invoiceDate);
      final generatedAt =
          DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          fontFallback: [arabicFont],
        ),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(22),
          footer: (context) => PdfThemeHelper.buildPageFooter(
            context: context,
            documentName: 'Purchase Invoice | ${invoice.invoiceNo}',
          ),
          build: (context) => [
            // ── Document Header ──────────────────────────────────────────
            PdfThemeHelper.buildDocumentHeader(
              title: 'PURCHASE INVOICE SUMMARY',
              subtitle: 'Line-item breakdown for invoice ${invoice.invoiceNo}',
              dateText:
                  'Invoice Date: $invoiceDateStr  |  Generated: $generatedAt',
              badgeText: invoice.invoiceNo,
            ),

            // ── KPI Cards ─────────────────────────────────────────────────
            PdfThemeHelper.buildKpiCardsRow([
              PdfKpiItem(
                label: 'Amount (Ex-VAT)',
                value: 'SAR ${totalExVat.toStringAsFixed(2)}',
                color: PdfThemeHelper.darkSlate,
              ),
              PdfKpiItem(
                label: 'Total VAT',
                value: 'SAR ${totalVat.toStringAsFixed(2)}',
                color: PdfThemeHelper.amberGold,
              ),
              PdfKpiItem(
                label: 'Total (Inc-VAT)',
                value: 'SAR ${totalIncVat.toStringAsFixed(2)}',
                color: PdfThemeHelper.emeraldGreen,
              ),
              PdfKpiItem(
                label: 'Line Items',
                value: '${itemsToExport.length}',
                color: PdfThemeHelper.primaryTealDark,
              ),
            ]),

            // ── Customer / Invoice Info Cards ────────────────────────────
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 14),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfThemeHelper.surfaceBg,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(
                            color: PdfThemeHelper.borderColor, width: 0.8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'CUSTOMER DETAILS',
                            style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfThemeHelper.primaryTeal,
                              letterSpacing: 0.8,
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            customerName,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfThemeHelper.darkSlate,
                            ),
                          ),
                          if (customer?.phone != null &&
                              customer!.phone.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Tel: ${customer.phone}',
                              style: const pw.TextStyle(
                                  fontSize: 8, color: PdfThemeHelper.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfThemeHelper.surfaceBg,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(
                            color: PdfThemeHelper.borderColor, width: 0.8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'INVOICE DETAILS',
                            style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfThemeHelper.primaryTeal,
                              letterSpacing: 0.8,
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          _pdfInfoRow('Invoice No', invoice.invoiceNo),
                          _pdfInfoRow('Invoice Date', invoiceDateStr),
                          _pdfInfoRow('Total Items', '${itemsToExport.length}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Section Header ────────────────────────────────────────────
            PdfThemeHelper.buildSectionHeader(
              'LINE ITEMS',
              countText: '${itemsToExport.length} items',
            ),

            // ── Items Table ───────────────────────────────────────────────
            if (itemsToExport.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.all(16),
                child: pw.Text(
                  'No line items available for this export.',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfThemeHelper.textMuted,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              )
            else
              pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(22), // SL
                  1: const pw.FixedColumnWidth(58), // Date
                  2: const pw.FlexColumnWidth(2.2), // Supplier
                  3: const pw.FlexColumnWidth(1.2), // VAT No
                  4: const pw.FlexColumnWidth(1.2), // Invoice No
                  5: const pw.FlexColumnWidth(1.0), // Amt Ex-VAT
                  6: const pw.FlexColumnWidth(1.0), // VAT
                  7: const pw.FlexColumnWidth(1.0), // Total
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfThemeHelper.darkSlate,
                    ),
                    children: [
                      _pdfInvCell('SL', isHeader: true, alignCenter: true),
                      _pdfInvCell('Date', isHeader: true),
                      _pdfInvCell('Supplier', isHeader: true),
                      _pdfInvCell('VAT No', isHeader: true),
                      _pdfInvCell('Invoice No', isHeader: true),
                      _pdfInvCell('Amt Ex-VAT',
                          isHeader: true, alignRight: true),
                      _pdfInvCell('VAT', isHeader: true, alignRight: true),
                      _pdfInvCell('Total Inc-VAT',
                          isHeader: true, alignRight: true),
                    ],
                  ),

                  // Data rows
                  ...itemsToExport.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final isEven = idx % 2 == 0;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color:
                            isEven ? PdfColors.white : PdfThemeHelper.surfaceBg,
                      ),
                      children: [
                        _pdfInvCell('${idx + 1}',
                            alignCenter: true, fontSize: 7.5),
                        _pdfInvCell(
                          DateFormat('dd/MM/yy').format(item.date),
                          fontSize: 7.5,
                          color: PdfThemeHelper.textMuted,
                        ),
                        _pdfInvCell(item.supplierName, fontSize: 7.5),
                        _pdfInvCell(
                          item.vatNumber.isEmpty ? '-' : item.vatNumber,
                          fontSize: 7.5,
                          color: PdfThemeHelper.textMuted,
                        ),
                        _pdfInvCell(item.invoiceNo, fontSize: 7.5),
                        _pdfInvCell(
                          item.amountExVat.toStringAsFixed(2),
                          alignRight: true,
                          fontSize: 7.5,
                        ),
                        _pdfInvCell(
                          item.vatAmount.toStringAsFixed(2),
                          alignRight: true,
                          fontSize: 7.5,
                          color: PdfThemeHelper.amberGold,
                        ),
                        _pdfInvCell(
                          item.totalIncVat.toStringAsFixed(2),
                          alignRight: true,
                          isBold: true,
                          fontSize: 7.5,
                          color: PdfThemeHelper.darkSlate,
                        ),
                      ],
                    );
                  }),

                  // Grand Total row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfThemeHelper.zebraBg,
                    ),
                    children: [
                      _pdfInvCell('', fontSize: 8),
                      _pdfInvCell('', fontSize: 8),
                      _pdfInvCell('', fontSize: 8),
                      _pdfInvCell('', fontSize: 8),
                      _pdfInvCell('GRAND TOTAL', isBold: true, fontSize: 8),
                      _pdfInvCell(
                        totalExVat.toStringAsFixed(2),
                        isBold: true,
                        alignRight: true,
                        fontSize: 8,
                        color: PdfThemeHelper.darkSlate,
                      ),
                      _pdfInvCell(
                        totalVat.toStringAsFixed(2),
                        isBold: true,
                        alignRight: true,
                        fontSize: 8,
                        color: PdfThemeHelper.amberGold,
                      ),
                      _pdfInvCell(
                        totalIncVat.toStringAsFixed(2),
                        isBold: true,
                        alignRight: true,
                        fontSize: 8.5,
                        color: PdfThemeHelper.emeraldGreen,
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final safeFileName =
          buildSafeExportFileName(invoice.invoiceNo, extension: 'pdf');
      if (!mounted) return;
      await showPdfActionsSheet(
          context: context, bytes: bytes, filename: safeFileName);
      if (mounted) _showMsg('PDF ready!', Colors.green);
    } catch (e) {
      if (mounted) _showMsg('Error exporting PDF: $e', Colors.red);
    }
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.Text(
            '$label: ',
            style:
                const pw.TextStyle(fontSize: 8, color: PdfThemeHelper.textMuted),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfThemeHelper.darkSlate,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfInvCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    bool alignRight = false,
    bool alignCenter = false,
    double fontSize = 8,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: alignRight
            ? pw.TextAlign.right
            : (alignCenter ? pw.TextAlign.center : pw.TextAlign.left),
        maxLines: 1,
        style: pw.TextStyle(
          fontSize: isHeader ? 7.5 : fontSize,
          fontWeight:
              isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader
              ? PdfColors.white
              : (color ?? PdfThemeHelper.darkSlate),
        ),
      ),
    );
  }

  // ── Excel Export ──────────────────────────────────────────────────────────
  Future<void> _exportToExcel(
    PurchaseInvoice invoice, [
    List<PurchaseItem>? filteredItems,
  ]) async {
    final itemsToExport = filteredItems ?? invoice.items;
    try {
      final customerProvider = context.read<CustomerProvider>();
      final customer = await customerProvider.getCustomerById(
        invoice.customerId,
      );

      final excel = Excel.createExcel();
      final sheet = excel['Invoice'];

      sheet.appendRow(['Purchase Invoice']);
      sheet.appendRow(['Invoice No', invoice.invoiceNo]);
      sheet.appendRow(['Customer', customer?.name ?? invoice.customerName]);
      sheet.appendRow([
        'Date',
        DateFormat('dd/MM/yyyy').format(invoice.invoiceDate),
      ]);
      sheet.appendRow([]);

      sheet.appendRow([
        'SL',
        'Invoice Date',
        'Invoice No',
        'Supplier',
        'VAT No',
        'Amount (Excl VAT)',
        'VAT',
        'Total (Incl VAT)',
      ]);

      for (var i = 0; i < itemsToExport.length; i++) {
        final it = itemsToExport[i];
        sheet.appendRow([
          (i + 1).toString(),
          DateFormat('dd/MM/yyyy').format(it.date),
          it.invoiceNo,
          it.supplierName,
          it.vatNumber,
          it.amountExVat.toStringAsFixed(2),
          it.vatAmount.toStringAsFixed(2),
          it.totalIncVat.toStringAsFixed(2),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) throw 'Failed to generate Excel';
      final dir = await getTemporaryDirectory();
      final safeFileName = buildSafeExportFileName(invoice.invoiceNo);
      final file = File('${dir.path}/$safeFileName');
      await file.writeAsBytes(bytes, flush: true);
      await OpenFile.open(file.path);
      if (mounted) _showMsg('Excel exported successfully!', Colors.green);
    } catch (e) {
      if (mounted) {
        debugPrint('Error exporting Excel: $e');
        _showMsg('Error exporting Excel: $e', Colors.red);
      }
    }
  }

  void _showMsg(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openInvoiceDetails(PurchaseInvoice invoice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseEntryDetailsScreen(
          invoice: invoice,
          onDelete: () => _deleteInvoice(invoice.id),
          onExportPdf: (items) => _exportToPdf(invoice, items),
          onExportExcel: (items) => _exportToExcel(invoice, items),
          onEdit: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => EditPurchaseEntryScreen(invoiceId: invoice.id)),
          ),
        ),
      ),
    );
  }

  int _getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 650) return 1;
    if (width < 1050) return 2;
    if (width < 1500) return 3;
    return 4;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        centerTitle: isMobile,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Purchase Entries',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: isMobile ? 16 : 18,
                color: AppTheme.textPrimary(context),
              ),
            ),
            if (!_isLoading && _filteredInvoices.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_filteredInvoices.length}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent(context),
                  ),
                ),
              ),
            ],
          ],
        ),
        toolbarHeight: 52,
        backgroundColor: AppTheme.surfaceBg(context),
        scrolledUnderElevation: 0,
        elevation: 0,
        actions: [
          // View Mode Switcher
          _ViewModeToggle(
            viewMode: _viewMode,
            onChanged: (mode) => setState(() => _viewMode = mode),
          ),
          const SizedBox(width: 4),

          // Refresh Button
          IconButton(
            tooltip: 'Refresh entries',
            icon: Icon(LucideIcons.refreshCw,
                size: 17, color: AppTheme.accent(context)),
            onPressed: _isLoading ? null : _loadInvoices,
          ),

          // Create Purchase Entry Action Button (Desktop & Tablet)
          if (!isMobile) ...[
            const SizedBox(width: 6),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PurchaseEntryScreen()),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                isTablet ? 'Create Entry' : 'Create Purchase Entry',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(width: 12),
          ] else ...[
            const SizedBox(width: 6),
          ],
        ],
      ),
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PurchaseEntryScreen()),
              ),
              backgroundColor: AppTheme.accent(context),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Create Entry',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            )
          : null,
      body: Column(
        children: [
          // ── Responsive Filter Bar ─────────────────────────────────────────
          _buildResponsiveFilterBar(context),

          // ── KPI Dashboard Cards ───────────────────────────────────────────
          if (!_isLoading && _filteredInvoices.isNotEmpty)
            _buildKpiRow(context),

          // ── Results list / table / empty / loading ────────────────────────
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.accent(context)),
                  )
                : _filteredInvoices.isEmpty
                    ? _buildEmptyState(context)
                    : _viewMode == ViewMode.grid
                        ? _buildGridView(context)
                        : Padding(
                          padding: const EdgeInsets.only(left: 12.0, right: 12.0,top: 6.0,bottom: 10.0),
                          child: _buildTableView(context),
                        ),
          ),
        ],
      ),
    );
  }

  // ── Responsive Filter Bar ─────────────────────────────────────────────────
  Widget _buildResponsiveFilterBar(BuildContext context) {
    if (context.isMobile) {
      return _buildMobileFilterBar(context);
    } else if (context.isTablet) {
      return _buildTabletFilterBar(context);
    } else {
      return _buildDesktopFilterBar(context);
    }
  }

  Widget _buildDesktopFilterBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppTheme.surfaceBg(context),
      child: Row(
        children: [
          // Search Field
          SizedBox(
            width: 270,
            height: 38,
            child: _buildSearchField(context),
          ),
          const SizedBox(width: 8),

          // Period Section Dropdown
          SizedBox(
            width: 200,
            height: 38,
            child: _buildPeriodDropdown(context),
          ),
          const SizedBox(width: 8),

          // Quick Filter Chips + Date Range
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  _buildFilterChip('Today', 'today'),
                  _buildFilterChip('This Week', 'week'),
                  _buildFilterChip('This Month', 'month'),
                  _buildDateRangeButton(context),
                  if (_filterType == 'custom' &&
                      (_customFrom != null || _customTo != null)) ...[
                    const SizedBox(width: 6),
                    _buildCustomDatePill(context),
                  ],
                ],
              ),
            ),
          ),

          if (_hasActiveFilters) ...[
            const SizedBox(width: 8),
            _buildResetButton(context),
          ],
        ],
      ),
    );
  }

  Widget _buildTabletFilterBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppTheme.surfaceBg(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: _buildSearchField(context),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 200,
                height: 38,
                child: _buildPeriodDropdown(context),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 8),
                _buildResetButton(context),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Today', 'today'),
                _buildFilterChip('This Week', 'week'),
                _buildFilterChip('This Month', 'month'),
                _buildDateRangeButton(context),
                if (_filterType == 'custom' &&
                    (_customFrom != null || _customTo != null)) ...[
                  const SizedBox(width: 6),
                  _buildCustomDatePill(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFilterBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: AppTheme.surfaceBg(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 36,
            child: _buildSearchField(context),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: _buildPeriodDropdown(context),
                ),
              ),
              const SizedBox(width: 6),
              _buildDateRangeButton(context),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 6),
                _buildResetButton(context, iconOnly: true),
              ],
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Today', 'today'),
                _buildFilterChip('This Week', 'week'),
                _buildFilterChip('This Month', 'month'),
                if (_filterType == 'custom' &&
                    (_customFrom != null || _customTo != null)) ...[
                  const SizedBox(width: 6),
                  _buildCustomDatePill(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Field Widget ───────────────────────────────────────────────────
  Widget _buildSearchField(BuildContext context) {
    return TextField(
      controller: _searchController,
      onChanged: (q) => _applyFilters(query: q),
      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppTheme.inputBg(context),
        hintText: 'Search customer, supplier, invoice #...',
        hintStyle:
            TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
        prefixIcon: Icon(LucideIcons.search,
            size: 15, color: AppTheme.textSecondary(context)),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(LucideIcons.x,
                    size: 14, color: AppTheme.textSecondary(context)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  _searchController.clear();
                  _applyFilters();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.cardBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.cardBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.accent(context), width: 1.5),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  // ── Period Dropdown Widget ────────────────────────────────────────────────
  Widget _buildPeriodDropdown(BuildContext context) {
    if (_periodsLoading) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceBg(context),
          border: Border.all(color: AppTheme.cardBorderColor(context)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.accent(context)),
          ),
        ),
      );
    }

    String dropdownValue;
    if (_selectedPeriodIds.isEmpty) {
      dropdownValue = 'all';
    } else if (_selectedPeriodIds.length == 1) {
      final firstId = _selectedPeriodIds.first;
      final exists = _periods.any((p) => p['id'] == firstId);
      dropdownValue = exists ? firstId : 'all';
    } else {
      dropdownValue = 'multi';
    }

    final displayText = _selectedPeriodIds.isEmpty
        ? 'All Periods'
        : (_selectedPeriodIds.length == 1
            ? (_periods.firstWhere((p) => p['id'] == _selectedPeriodIds.first,
                orElse: () => {'name': '1 Period'})['name'] ?? '1 Period')
            : '${_selectedPeriodIds.length} Periods');

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg(context),
        border: Border.all(
          color: _selectedPeriodIds.isNotEmpty
              ? AppTheme.accent(context)
              : AppTheme.cardBorderColor(context),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: AppTheme.surfaceBg(context),
          value: dropdownValue,
          isExpanded: true,
          icon: Icon(LucideIcons.chevronDown,
              size: 14, color: AppTheme.textSecondary(context)),
          selectedItemBuilder: (ctx) => [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: _selectedPeriodIds.isNotEmpty
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: _selectedPeriodIds.isNotEmpty
                      ? AppTheme.accent(context)
                      : AppTheme.textPrimary(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ..._periods.map((p) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Text('All Periods',
                  style: TextStyle(
                      fontSize: 12.5, color: AppTheme.textPrimary(context))),
            ),
            ..._periods.map((p) => DropdownMenuItem(
                  value: p['id'],
                  child: Text(p['name']!,
                      style: TextStyle(
                          fontSize: 12.5, color: AppTheme.textPrimary(context))),
                )),
            DropdownMenuItem(
              value: 'multi',
              child: Text('Select multiple...',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.accent(context),
                      fontWeight: FontWeight.w600)),
            ),
          ],
          onChanged: (val) {
            if (val == null) return;
            if (val == 'all') {
              setState(() => _selectedPeriodIds.clear());
              _applyFilters();
              return;
            }
            if (val == 'multi') {
              _showPeriodSelectDialog();
              return;
            }
            setState(() {
              _selectedPeriodIds = {val};
            });
            _applyFilters();
          },
        ),
      ),
    );
  }

  // ── Date Range Button Widget ──────────────────────────────────────────────
  Widget _buildDateRangeButton(BuildContext context) {
    final isCustom = _filterType == 'custom';
    return GestureDetector(
      onTap: _pickDateRange,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isCustom
              ? AppTheme.accent(context)
              : AppTheme.surfaceBg(context),
          border: Border.all(
            color: isCustom
                ? AppTheme.accent(context)
                : AppTheme.cardBorderColor(context),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.calendar,
              size: 13,
              color: isCustom ? Colors.white : AppTheme.textSecondary(context),
            ),
            const SizedBox(width: 4),
            Text(
              'Date Range',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCustom ? FontWeight.w600 : FontWeight.normal,
                color:
                    isCustom ? Colors.white : AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Custom Date Range Pill ────────────────────────────────────────────────
  Widget _buildCustomDatePill(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.accent(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.accent(context).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.calendarRange,
              size: 13, color: AppTheme.accent(context)),
          const SizedBox(width: 6),
          Text(
            '${_customFrom != null ? DateFormat('dd MMM').format(_customFrom!) : '—'}'
            ' → '
            '${_customTo != null ? DateFormat('dd MMM').format(_customTo!) : '—'}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.accent(context),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: _pickDateRange,
            child: Icon(LucideIcons.pencil,
                size: 12, color: AppTheme.accent(context)),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: _clearDateRange,
            child: Icon(LucideIcons.x,
                size: 13, color: AppTheme.accent(context)),
          ),
        ],
      ),
    );
  }

  // ── Filter Chip Widget ────────────────────────────────────────────────────
  Widget _buildFilterChip(String label, String type) {
    final isActive = _filterType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filterType = type;
            if (type != 'custom') {
              _customFrom = null;
              _customTo = null;
            }
          });
          _applyFilters();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.accent(context)
                : AppTheme.surfaceBg(context),
            border: Border.all(
              color: isActive
                  ? AppTheme.accent(context)
                  : AppTheme.cardBorderColor(context),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.white : AppTheme.textSecondary(context),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // ── Reset Button Widget ───────────────────────────────────────────────────
  Widget _buildResetButton(BuildContext context, {bool iconOnly = false}) {
    return Tooltip(
      message: 'Reset all filters',
      child: InkWell(
        onTap: _resetAllFilters,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 38,
          padding: EdgeInsets.symmetric(horizontal: iconOnly ? 8 : 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.surfaceBg(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.cardBorderColor(context)),
          ),
          child: iconOnly
              ? Icon(LucideIcons.rotateCcw,
                  size: 14, color: AppTheme.textSecondary(context))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.rotateCcw,
                        size: 13, color: AppTheme.textSecondary(context)),
                    const SizedBox(width: 4),
                    Text(
                      'Reset',
                      style: TextStyle(
                        color: AppTheme.textSecondary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── KPI Stats Cards ───────────────────────────────────────────────────────
  Widget _buildKpiRow(BuildContext context) {
    final count = _filteredInvoices.length;
    final totalExVat = _filteredInvoices.fold<double>(
        0, (s, inv) => s + inv.totalAmountExVat);
    final totalVat = _filteredInvoices.fold<double>(
        0, (s, inv) => s + inv.totalVatAmount);
    final totalIncVat = _filteredInvoices.fold<double>(
        0, (s, inv) => s + inv.totalAmountIncVat);

    final items = [
      _KpiData(
        label: 'Total Invoices',
        value: count.toString(),
        icon: LucideIcons.fileText,
        color: AppTheme.accent(context),
      ),
      _KpiData(
        label: 'Amount (Ex-VAT)',
        value: 'SAR ${totalExVat.toStringAsFixed(2)}',
        icon: LucideIcons.calculator,
        color: const Color(0xFF3B82F6),
      ),
      _KpiData(
        label: 'Total VAT',
        value: 'SAR ${totalVat.toStringAsFixed(2)}',
        icon: LucideIcons.percent,
        color: const Color(0xFFF59E0B),
      ),
      _KpiData(
        label: 'Total (Inc-VAT)',
        value: 'SAR ${totalIncVat.toStringAsFixed(2)}',
        icon: LucideIcons.badgePercent,
        color: const Color(0xFF10B981),
      ),
    ];

    if (context.isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((item) => SizedBox(
                        width: itemWidth,
                        child: _buildKpiCard(context, item, compact: true),
                      ))
                  .toList(),
            );
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: items
            .map((item) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child:
                        _buildKpiCard(context, item, compact: context.isTablet),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, _KpiData data,
      {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14, vertical: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, size: compact ? 15 : 17, color: data.color),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.label,
                  style: TextStyle(
                    fontSize: compact ? 10.5 : 11.5,
                    color: AppTheme.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: compact ? 13 : 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Grid View ─────────────────────────────────────────────────────────────
  Widget _buildGridView(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _filteredInvoices.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getGridColumns(context),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 198,
      ),
      itemBuilder: (context, index) {
        final invoice = _filteredInvoices[index];
        return _buildInvoiceCard(invoice, index);
      },
    );
  }

  Widget _buildInvoiceCard(PurchaseInvoice invoice, int index) {
    final isDark = AppTheme.isDark(context);
    final totalItems = invoice.items.length;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openInvoiceDetails(invoice),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: Period section badge + Date + More menu
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      invoice.periodSectionName.isNotEmpty
                          ? invoice.periodSectionName
                          : 'No Period',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      Icon(LucideIcons.calendar,
                          size: 12, color: AppTheme.textMuted(context)),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(invoice.createdAt),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _buildInvoicePopupMenu(invoice),
                ],
              ),
              const SizedBox(height: 6),

              // Customer Name & VAT number
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor:
                        AppTheme.accent(context).withValues(alpha: 0.12),
                    child: Text(
                      invoice.customerName.isNotEmpty
                          ? invoice.customerName[0].toUpperCase()
                          : 'C',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.customerName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (invoice.customerVatNumber.isNotEmpty)
                          Text(
                            'VAT: ${invoice.customerVatNumber}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Financial Summary Block
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.inputBg(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color:
                          AppTheme.cardBorderColor(context).withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount (Ex)',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppTheme.textMuted(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          invoice.totalAmountExVat.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'VAT',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppTheme.textMuted(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          invoice.totalVatAmount.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEAB308),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total (Inc)',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppTheme.textMuted(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'SAR ${invoice.totalAmountIncVat.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accent(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Footer row: Line items count + Details hint
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBg(context),
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: AppTheme.cardBorderColor(context)),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.layers,
                            size: 11, color: AppTheme.textSecondary(context)),
                        const SizedBox(width: 4),
                        Text(
                          '$totalItems item${totalItems == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent(context),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: AppTheme.accent(context),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Table View ────────────────────────────────────────────────────────────
  Widget _buildTableView(BuildContext context) {
    final borderColor = AppTheme.cardBorderColor(context);
    const slColumnWidth = 60.0;
    const periodColumnWidth = 150.0;
    const dateColumnWidth = 120.0;
    const actionColumnWidth = 90.0;

    final columns = <PlutoColumn>[
      PlutoColumn(
        title: 'SL',
        field: 'sl',
        type: PlutoColumnType.number(format: '#,##0'),
        width: slColumnWidth,
        minWidth: slColumnWidth,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableDropToResize: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'Period',
        field: 'period',
        type: PlutoColumnType.text(),
        width: periodColumnWidth,
        minWidth: periodColumnWidth,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableDropToResize: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'Created Date',
        field: 'createdDate',
        type: PlutoColumnType.text(),
        width: dateColumnWidth,
        minWidth: dateColumnWidth,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableDropToResize: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'Customer',
        field: 'customer',
        type: PlutoColumnType.text(),
        width: 220,
        minWidth: 180,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'VAT Number',
        field: 'vatNumber',
        type: PlutoColumnType.text(),
        width: 140,
        minWidth: 120,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'Amount (Ex)',
        field: 'amountExVat',
        type: PlutoColumnType.number(format: '#,##0.00'),
        width: 120,
        minWidth: 100,
        textAlign: PlutoColumnTextAlign.right,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'VAT',
        field: 'vatAmount',
        type: PlutoColumnType.number(format: '#,##0.00'),
        width: 110,
        minWidth: 90,
        textAlign: PlutoColumnTextAlign.right,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'Total (Inc)',
        field: 'totalIncVat',
        type: PlutoColumnType.number(format: '#,##0.00'),
        width: 130,
        minWidth: 110,
        textAlign: PlutoColumnTextAlign.right,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'Action',
        field: 'action',
        type: PlutoColumnType.text(),
        width: actionColumnWidth,
        minWidth: actionColumnWidth,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableDropToResize: false,
        enableContextMenu: false,
        enableSorting: false,
        renderer: (rendererContext) {
          final invoiceId = rendererContext.cell.value as String;
          final invoice = _filteredInvoices.firstWhere(
            (item) => item.id == invoiceId,
            orElse: () => _filteredInvoices.first,
          );

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Open invoice',
                icon: Icon(Icons.visibility_outlined,
                    size: 16, color: AppTheme.accent(context)),
                onPressed: () => _openInvoiceDetails(invoice),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              ),
              IconButton(
                tooltip: 'More actions',
                icon: Icon(Icons.more_vert,
                    size: 16, color: AppTheme.textSecondary(context)),
                onPressed: () {
                  final menuInvoice = _filteredInvoices.firstWhere(
                    (item) => item.id == invoiceId,
                    orElse: () => invoice,
                  );
                  _showInvoiceMenu(menuInvoice, context);
                },
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              ),
            ],
          );
        },
      ),
    ];

    final rows = _filteredInvoices.asMap().entries.map((entry) {
      final index = entry.key;
      final invoice = entry.value;
      return PlutoRow(
        cells: {
          'sl': PlutoCell(value: index + 1),
          'period': PlutoCell(
            value: invoice.periodSectionName.isNotEmpty
                ? invoice.periodSectionName
                : '—',
          ),
          'createdDate': PlutoCell(
            value: DateFormat('dd/MM/yyyy').format(invoice.createdAt),
          ),
          'customer': PlutoCell(value: invoice.customerName),
          'vatNumber': PlutoCell(
            value: invoice.customerVatNumber.isNotEmpty
                ? invoice.customerVatNumber
                : '—',
          ),
          'amountExVat': PlutoCell(value: invoice.totalAmountExVat),
          'vatAmount': PlutoCell(value: invoice.totalVatAmount),
          'totalIncVat': PlutoCell(value: invoice.totalAmountIncVat),
          'action': PlutoCell(value: invoice.id),
        },
      );
    }).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.68,
      child: PlutoGrid(
        columns: columns,
        rows: rows,
        onRowDoubleTap: (event) {
          final row = event.row; 
          final id = row.cells['action']?.value as String?;
          if (id == null) return;
          final invoice = _filteredInvoices.firstWhere(
            (item) => item.id == id,
            orElse: () => _filteredInvoices.first,
          );
          _openInvoiceDetails(invoice);
        },
        configuration: PlutoGridConfiguration(
          style: PlutoGridStyleConfig(
            gridBackgroundColor: AppTheme.cardBg(context),
            rowColor: AppTheme.cardBg(context),
            evenRowColor: AppTheme.cardBg(context),
            oddRowColor: AppTheme.scaffoldBg(context),
            activatedColor: AppTheme.accent(context).withValues(alpha: 0.12),
            borderColor: borderColor,
            gridBorderColor: borderColor,
            columnHeight: 40,
            rowHeight: 44,
            columnTextStyle: TextStyle(
              color: AppTheme.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            cellTextStyle: TextStyle(
              color: AppTheme.textPrimary(context),
              fontSize: 12,
            ),
            gridBorderRadius: BorderRadius.circular(10),
          ),
          scrollbar: const PlutoGridScrollbarConfig(
            isAlwaysShown: true,
            draggableScrollbar: true,
          ),
        ),
      ),
    );
  }

  // ── Popup Menu Widget ─────────────────────────────────────────────────────
  Widget _buildInvoicePopupMenu(PurchaseInvoice invoice) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert,
          size: 18, color: AppTheme.textSecondary(context)),
      color: AppTheme.surfaceBg(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.cardBorderColor(context)),
      ),
      onSelected: (val) {
        if (val == 'view') {
          _openInvoiceDetails(invoice);
        } else if (val == 'edit') {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    EditPurchaseEntryScreen(invoiceId: invoice.id)),
          );
        } else if (val == 'pdf') {
          _exportToPdf(invoice);
        } else if (val == 'delete') {
          _deleteInvoice(invoice.id);
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(LucideIcons.eye, size: 16, color: AppTheme.accent(context)),
              const SizedBox(width: 8),
              Text('View',
                  style: TextStyle(
                      color: AppTheme.textPrimary(context), fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(LucideIcons.pencil, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Text('Edit',
                  style: TextStyle(
                      color: AppTheme.textPrimary(context), fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              const Icon(LucideIcons.fileDown,
                  size: 16, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text('Export PDF',
                  style: TextStyle(
                      color: AppTheme.textPrimary(context), fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: const Row(
            children: [
              Icon(LucideIcons.trash2, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete',
                  style: TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showInvoiceMenu(PurchaseInvoice invoice, BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);
    final Rect rect = offset & button.size;

    final String? value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        rect,
        Offset.zero & MediaQuery.of(context).size,
      ),
      color: AppTheme.surfaceBg(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.cardBorderColor(context)),
      ),
      items: [
        PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(LucideIcons.eye, size: 16, color: AppTheme.accent(context)),
              const SizedBox(width: 8),
              Text('View',
                  style: TextStyle(
                      color: AppTheme.textPrimary(context), fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(LucideIcons.pencil, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Text('Edit',
                  style: TextStyle(
                      color: AppTheme.textPrimary(context), fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              const Icon(LucideIcons.fileDown,
                  size: 16, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text('Export PDF',
                  style: TextStyle(
                      color: AppTheme.textPrimary(context), fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: const Row(
            children: [
              Icon(LucideIcons.trash2, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete',
                  style: TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ),
        ),
      ],
    );

    if (!context.mounted || value == null) return;

    if (value == 'view') {
      _openInvoiceDetails(invoice);
    } else if (value == 'edit') {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditPurchaseEntryScreen(invoiceId: invoice.id),
        ),
      );
    } else if (value == 'pdf') {
      _exportToPdf(invoice);
    } else if (value == 'delete') {
      _deleteInvoice(invoice.id);
    }
  }

  // ── Empty State Widget ────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.receipt,
                size: 42,
                color: AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _hasActiveFilters
                  ? 'No invoices match your filter criteria'
                  : 'No purchase invoices found',
              style: TextStyle(
                color: AppTheme.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _hasActiveFilters
                  ? 'Try adjusting or clearing your date range or search keyword'
                  : 'Create your first purchase invoice entry using the button above',
              style: TextStyle(
                color: AppTheme.textSecondary(context),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _resetAllFilters,
                icon: const Icon(LucideIcons.rotateCcw, size: 14),
                label: const Text('Clear all filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent(context),
                  side: BorderSide(color: AppTheme.accent(context)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View Mode Toggle (Grid / Table)
// ─────────────────────────────────────────────────────────────────────────────

class _ViewModeToggle extends StatelessWidget {
  final ViewMode viewMode;
  final ValueChanged<ViewMode> onChanged;

  const _ViewModeToggle({required this.viewMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.inputBg(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(
            context: context,
            mode: ViewMode.grid,
            icon: LucideIcons.layoutGrid,
            tooltip: 'Grid View',
          ),
          const SizedBox(width: 2),
          _buildOption(
            context: context,
            mode: ViewMode.table,
            icon: LucideIcons.table,
            tooltip: 'Table View',
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required ViewMode mode,
    required IconData icon,
    required String tooltip,
  }) {
    final isSelected = viewMode == mode;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => onChanged(mode),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color:
                isSelected ? AppTheme.surfaceBg(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: AppTheme.isDark(context) ? 0.3 : 0.08,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected
                ? AppTheme.accent(context)
                : AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI Item Data Model
// ─────────────────────────────────────────────────────────────────────────────

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
