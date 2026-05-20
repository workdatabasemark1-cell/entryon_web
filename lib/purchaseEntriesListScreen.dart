
import 'package:entryon/purchaseEntryScreen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

// PDF packages
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// File handling

import 'models/purchase_entry_model.dart';

import 'providers/customer_provider.dart';
import 'providers/supplier_provider.dart';

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

  // ── Filter state ──────────────────────────────────────────────────────────
  String _filterType = 'all'; // all | today | week | month | custom
  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  // ── Data loading ──────────────────────────────────────────────────────────
  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await _fetchAllInvoices();
      setState(() {
        _allInvoices = invoices;
        _filteredInvoices = invoices;
      });
      if (invoices.isEmpty) _showMsg('No invoices found', Colors.orange);
    } catch (e) {
      _showMsg('Error loading invoices: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
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
        print('Error parsing invoice ${doc.id}: $e');
      }
    }
    invoices.sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
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

        switch (_filterType) {
          case 'today':
            return invDate.isAtSameMomentAs(today);
          case 'week':
            return !invDate
                .isBefore(today.subtract(const Duration(days: 7)));
          case 'month':
            return !invDate
                .isBefore(today.subtract(const Duration(days: 30)));
          case 'custom':
            if (_customFrom == null && _customTo == null) return true;
            final from = _customFrom != null
                ? DateTime(_customFrom!.year, _customFrom!.month,
                    _customFrom!.day)
                : null;
            final to = _customTo != null
                ? DateTime(
                    _customTo!.year, _customTo!.month, _customTo!.day)
                : null;
            final afterFrom = from == null ||
                !invDate.isBefore(from);
            final beforeTo = to == null ||
                !invDate.isAfter(to);
            return afterFrom && beforeTo;
          default: // 'all'
            return true;
        }
      }).toList();
    });
  }

  // ── Date range picker ─────────────────────────────────────────────────────
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: (_customFrom != null && _customTo != null)
          ? DateTimeRange(start: _customFrom!, end: _customTo!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)), end: now),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.blue.shade700,
            onPrimary: Colors.white,
            surface: Colors.white,
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

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> _deleteInvoice(String invoiceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure you want to delete this invoice?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('purchase_invoices')
            .doc(invoiceId)
            .delete();
        _showMsg('Invoice deleted', Colors.green);
        _loadInvoices();
      } catch (e) {
        _showMsg('Error deleting: $e', Colors.red);
      }
    }
  }

  // ── PDF Export ────────────────────────────────────────────────────────────
  Future<void> _exportToPdf(PurchaseInvoice invoice) async {
    try {
      // Fetch complete customer and supplier details
      final customerProvider = context.read<CustomerProvider>();
      final supplierProvider = context.read<SupplierProvider>();
      
      final customer = await customerProvider.getCustomerById(invoice.customerId);
      final supplier = await supplierProvider.getSupplierById(invoice.supplierId);

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          // ── Header ────────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('PURCHASE INVOICE',
                  style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Invoice #${invoice.invoiceNo}',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                      'Date: ${DateFormat('dd/MM/yyyy').format(invoice.invoiceDate)}',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.Divider(color: PdfColors.blue800, thickness: 2),
          pw.SizedBox(height: 16),

          // ── Customer Details ──────────────────────────────────────────────
          pw.Text('CUSTOMER INFORMATION',
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(children: [
              _pdfRow('Name', customer?.name ?? invoice.customerName),
              if (customer != null) ...[
                if (customer.phone.isNotEmpty)
                  _pdfRow('Phone', customer.phone),
                if ((customer.email?.isNotEmpty ?? false))
                  _pdfRow('Email', customer.email!),
                if ((customer.organizationName?.isNotEmpty ?? false))
                  _pdfRow('Organization', customer.organizationName!),
                if (customer.address.isNotEmpty)
                  _pdfRow('Address', customer.address),
              ],
              _pdfRow('VAT Number', invoice.customerVatNumber),
            ]),
          ),
          pw.SizedBox(height: 20),

          // ── Supplier & Invoice Details Table ──────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Supplier Details (Left)
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Column(children: [
                    pw.Text('SUPPLIER',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800)),
                    pw.SizedBox(height: 8),
                    _pdfRow('Name', supplier?.name ?? invoice.supplierName),
                    if (supplier != null && supplier.phone.isNotEmpty)
                      _pdfRow('Phone', supplier.phone),
                    if (supplier != null &&
                        (supplier.address?.isNotEmpty ?? false))
                      _pdfRow('Address', supplier.address!),
                    _pdfRow('VAT No.', supplier?.vatNumber ?? 'N/A'),
                  ]),
                ),
              ),
              pw.SizedBox(width: 12),
              // Invoice Details (Right)
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                      color: PdfColors.orange50,
                      borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Column(children: [
                    pw.Text('INVOICE DETAILS',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange800)),
                    pw.SizedBox(height: 8),
                    _pdfRow('Created',
                        DateFormat('dd/MM/yyyy').format(invoice.createdAt)),
                    _pdfRow('Invoice Date',
                        DateFormat('dd/MM/yyyy').format(invoice.invoiceDate)),
                    if (invoice.periodSectionName.isNotEmpty)
                      _pdfRow('Period', invoice.periodSectionName),
                  ]),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Line Items Table ──────────────────────────────────────────────
          pw.Text('LINE ITEMS',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: [
              '#', 'Supplier', 'Amount (Ex VAT)', 'VAT', 'Total (Inc VAT)'
            ],
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.blue700),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(0.5),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(2),
            },
            data: List.generate(invoice.items.length, (i) {
              final item = invoice.items[i];
              return [
                '${i + 1}',
                item.supplierName,
                item.amountExVat.toStringAsFixed(2),
                item.vatAmount.toStringAsFixed(2),
                item.totalIncVat.toStringAsFixed(2),
              ];
            }),
            oddRowDecoration:
                const pw.BoxDecoration(color: PdfColors.grey100),
          ),
          pw.SizedBox(height: 20),

          // ── Totals Summary ────────────────────────────────────────────────
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 280,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  color: PdfColors.purple50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.purple200)),
              child: pw.Column(children: [
                _pdfTotalRow('Subtotal (Excl. VAT)',
                    invoice.totalAmountExVat.toStringAsFixed(2),
                    PdfColors.blue700),
                pw.SizedBox(height: 4),
                _pdfTotalRow('Total VAT',
                    invoice.totalVatAmount.toStringAsFixed(2),
                    PdfColors.green700),
                pw.Divider(color: PdfColors.purple300),
                _pdfTotalRow(
                    'GRAND TOTAL',
                    invoice.totalAmountIncVat.toStringAsFixed(2),
                    PdfColors.purple700,
                    isBold: true,
                    fontSize: 13),
              ]),
            ),
          ),
          pw.SizedBox(height: 30),
          pw.Divider(),
          pw.Center(
              child: pw.Column(children: [
            pw.Text(
                'Generated on ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text('This is an automatically generated document',
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey500)),
          ])),
        ],
      ));
      final bytes = await pdf.save();
      await Printing.sharePdf(
          bytes: bytes, filename: 'invoice_${invoice.invoiceNo}.pdf');
      if (mounted) {
        _showMsg('PDF exported successfully!', Colors.green);
      }
    } catch (e) {
      _showMsg('Error exporting PDF: $e', Colors.red);
    }
  }

  pw.Widget _pdfRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(
                    color: PdfColors.grey700, fontSize: 11)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 11)),
          ],
        ),
      );

  pw.Widget _pdfTotalRow(String label, String value, PdfColor color,
          {bool isBold = false, double fontSize = 11}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: fontSize,
                    fontWeight: isBold
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: fontSize,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
          ],
        ),
      );

  // ── Invoice detail bottom sheet ───────────────────────────────────────────
  void _showInvoiceDetails(PurchaseInvoice invoice) {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Invoice Details',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  _buildDetailRow('Customer', invoice.customerName),
                  if (invoice.customerVatNumber.isNotEmpty)
                    _buildDetailRow('Customer VAT Number', invoice.customerVatNumber),
                  _buildDetailRow('Created Date',
                      DateFormat('dd/MM/yyyy').format(invoice.createdAt)),
                  if ( invoice.periodSectionName.isNotEmpty)
                    _buildDetailRow('Period Section', invoice.periodSectionName),
                ]),
              ),
              const SizedBox(height: 12),
              const Text('Line Items',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columnSpacing: 12,
                  columns: const [
                    DataColumn(label: Text('SL No.')),
                    DataColumn(label: Text('Invoice Date')),
                    DataColumn(label: Text('Supplier')),
                    DataColumn(label: Text('Vat No')),
                    DataColumn(label: Text('Invoice No')),
                    DataColumn(label: Text('Amount\nWithout VAT')),
                    DataColumn(label: Text('VAT')),
                    DataColumn(label: Text('Total')),
                  ],
                  rows: List.generate(invoice.items.length, (index) {
                    final item = invoice.items[index];
                    return DataRow(
                      color: WidgetStateProperty.all(index.isEven
                          ? Colors.grey.shade200
                          : Colors.white),
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(Text(
                            DateFormat('dd/MM/yyyy').format(item.date))),
                        DataCell(SizedBox(
                          width: 100,
                          child: Text(item.supplierName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2),
                        )),
                        DataCell(Text(item.vatNumber)),
                        DataCell(Text(item.invoiceNo)),
                        
                        DataCell(
                            Text(item.amountExVat.toStringAsFixed(2))),
                        DataCell(
                            Text(item.vatAmount.toStringAsFixed(2))),
                        DataCell(
                            Text(item.totalIncVat.toStringAsFixed(2))),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTotalColumn(
                        'Total (Excl. VAT)',
                        invoice.totalAmountExVat.toStringAsFixed(2),
                        Colors.blue),
                    _buildTotalColumn('Total VAT',
                        invoice.totalVatAmount.toStringAsFixed(2),
                        Colors.green),
                    _buildTotalColumn('Grand Total',
                        invoice.totalAmountIncVat.toStringAsFixed(2),
                        Colors.purple),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Export Invoice',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _exportToPdf(invoice);
                    },
                    icon: const Icon(Icons.picture_as_pdf,
                        color: Colors.white),
                    label: const Text('Export PDF'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.table_chart,
                        color: Colors.white),
                    label: const Text('Export Excel'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30))),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _deleteInvoice(invoice.id);
                      },
                      child: Container(height: 45,
                        // padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.black, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.delete, color: Colors.black),
                            SizedBox(width: 8),
                            Text(
                              'Delete Invoice',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),SizedBox(width: 12),
                     Expanded(
                       child: GestureDetector(
                         onTap: () {
                           
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PurchaseEntryScreen(invoice: invoice),  ));
                          
                         },
                          
                         child: Container(height: 45,
                           // padding: const EdgeInsets.symmetric(vertical: 12),
                           decoration: BoxDecoration(
                             color: Colors.white,
                             borderRadius: BorderRadius.circular(30),
                             border: Border.all(color: Colors.black, width: 1),
                             boxShadow: [
                               BoxShadow(
                                 color: Colors.black.withOpacity(0.08),
                                 blurRadius: 6,
                                 offset: const Offset(0, 3),
                               ),
                             ],
                           ),
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: const [
                               Icon(Icons.edit, color: Colors.black),
                               SizedBox(width: 8),
                               Text(
                                 'Edit Invoice',
                                 style: TextStyle(
                                   color: Colors.black,
                                   fontSize: 16,
                                   fontWeight: FontWeight.w600,
                                 ),
                               ),
                             ],
                           ),
                         ),
                       ),
                     )

                ],
              )

            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildTotalColumn(String label, String value, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ]);

  Widget _buildDetailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );

  void _showMsg(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: color));

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Purchase Entries'),
        toolbarHeight: 50,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadInvoices,
            icon: const Icon(Icons.refresh, color: Colors.blueGrey),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (q) => _applyFilters(query: q),
                decoration: const InputDecoration(
                  hintText:
                      'Search by customer, supplier, or invoice #...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ),

          // ── Quick filter chips + Date Range button ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _buildFilterChip('All', 'all'),
                      _buildFilterChip('Today', 'today'),
                      _buildFilterChip('This Week', 'week'),
                      _buildFilterChip('This Month', 'month'),
                    ]),
                  ),
                ),

                // ── Date Range picker button ───────────────────────────
                GestureDetector(
                  onTap: _pickDateRange,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _filterType == 'custom'
                          ? Colors.blue.shade700
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.date_range,
                            size: 15,
                            color: _filterType == 'custom'
                                ? Colors.white
                                : Colors.black87),
                        const SizedBox(width: 4),
                        Text(
                          'Date Range',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _filterType == 'custom'
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: _filterType == 'custom'
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Active date range banner ───────────────────────────────────
          if (_filterType == 'custom' &&
              (_customFrom != null || _customTo != null))
            Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_alt_outlined,
                      size: 15, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_customFrom != null ? DateFormat('dd MMM yyyy').format(_customFrom!) : '—'}'
                      '  →  '
                      '${_customTo != null ? DateFormat('dd MMM yyyy').format(_customTo!) : '—'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  // Edit date range
                  GestureDetector(
                    onTap: _pickDateRange,
                    child: Icon(Icons.edit_calendar_outlined,
                        size: 16, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 12),
                  // Clear
                  GestureDetector(
                    onTap: _clearDateRange,
                    child: Icon(Icons.close,
                        size: 16, color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),

          // ── Results summary row ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredInvoices.length} invoice${_filteredInvoices.length == 1 ? '' : 's'}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                if (_filteredInvoices.isNotEmpty)
                  Text(
                    'Total: ${_filteredInvoices.fold<double>(0, (s, inv) => s + inv.totalAmountIncVat).toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple.shade700),
                  ),
              ],
            ),
          ),

          // ── Data table ────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 52, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text('No invoices found',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 15)),
                            if (_filterType != 'all')
                              TextButton(
                                onPressed: _clearDateRange,
                                child: const Text('Clear filters'),
                              ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          border: TableBorder.all(
                              color: Colors.grey.shade300),
                          columnSpacing: 16,
                          showCheckboxColumn: false,
                          headingRowColor:
                              WidgetStateProperty.all(Colors.white),
                          columns: const [
                            DataColumn(
                                label: Text('SL NO',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Period Section',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),            
                            DataColumn(
                                label: Text('Created Date',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Customer',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('VAT Number',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Amount',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                                numeric: true),
                            DataColumn(
                                label: Text('VAT',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                                numeric: true),
                            DataColumn(
                                label: Text('Total',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                                numeric: true),
                            DataColumn(
                                label: Text('Action',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                          ],
                          rows: List.generate(_filteredInvoices.length,
                              (index) {
                            final invoice = _filteredInvoices[index];
                            return DataRow(
                              color: WidgetStateProperty.all(index.isEven
                                  ? Colors.grey.shade200
                                  : Colors.white),
                              onSelectChanged: (_) =>
                                  _showInvoiceDetails(invoice),
                              cells: [
                                DataCell(Text('${index + 1}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                                DataCell(Text(invoice.periodSectionName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                                DataCell(Text(DateFormat('dd/MM/yyyy')
                                    .format(invoice.createdAt))),
                                DataCell(SizedBox(
                                    width: 120,
                                    child: Text(invoice.customerName,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2))),
                                DataCell(Text(invoice.customerVatNumber,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                                DataCell(Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(invoice.totalAmountExVat
                                        .toStringAsFixed(2)))),
                                DataCell(Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(invoice.totalVatAmount
                                        .toStringAsFixed(2)))),
                                DataCell(Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                        invoice.totalAmountIncVat
                                            .toStringAsFixed(2),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple)))),
                                DataCell(PopupMenuButton(color: Colors.white,
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                      child: const Row(children: [
                                        Icon(Icons.visibility, size: 20),
                                        SizedBox(width: 8),
                                        Text('View'),
                                      ]),
                                      onTap: () =>
                                          _showInvoiceDetails(invoice),
                                    ),
                                    PopupMenuItem(
                                      child:  Row(children: [
                                        Icon(Icons.edit,
                                            size: 20, color: Colors.blue[900]),
                                        SizedBox(width: 8),
                                        Text('Edit',
                                            style: TextStyle(
                                                color: Colors.blue[900])),
                                      ]),
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PurchaseEntryScreen(invoice: invoice))),
                                    ),
                                    PopupMenuItem(
                                      child: const Row(children: [
                                        Icon(Icons.picture_as_pdf,
                                            size: 20, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Export PDF',
                                            style: TextStyle(
                                                color: Colors.red)),
                                      ]),
                                      onTap: () => _exportToPdf(invoice),
                                    ),
                                    PopupMenuItem(
                                      child: const Row(children: [
                                        Icon(Icons.delete,
                                            size: 20, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete',
                                            style: TextStyle(
                                                color: Colors.red)),
                                      ]),
                                      onTap: () =>
                                          _deleteInvoice(invoice.id),
                                    ),
                                  ],
                                )),
                              ],
                            );
                          }),
                        ),
                      ),
          ),

          // ── Bottom CTA ────────────────────────────────────────────────
          SafeArea(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PurchaseEntryScreen()),
              ),
              child: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.9),
                      blurRadius: 8,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.black),
                    SizedBox(width: 8),
                    Text('Create Purchase Entry',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chip ───────────────────────────────────────────────────────────
  Widget _buildFilterChip(String label, String type) {
    final isActive = _filterType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.shade700 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.white : Colors.black87,
              fontWeight:
                  isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}