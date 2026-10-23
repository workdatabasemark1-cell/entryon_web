import 'package:entryon/models/service_model.dart';
import 'package:entryon/models/transaction_model.dart';
import 'package:entryon/providers/service_entry_provider.dart';
import 'package:entryon/providers/transaction_provider.dart';
import 'package:entryon/utils/date_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../utils/pdf_theme_helper.dart';
import '../utils/pdf_actions.dart';
import '../utils/app_theme.dart';

class ServiceTransactionReportScreen extends StatefulWidget {
  const ServiceTransactionReportScreen({super.key});

  @override
  State<ServiceTransactionReportScreen> createState() =>
      _ServiceTransactionReportScreenState();
}

class _ServiceTransactionReportScreenState
    extends State<ServiceTransactionReportScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceEntryProvider>().fetchServices();
      context.read<TransactionProvider>().fetchTransactions();
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: _fromDate ?? now.subtract(const Duration(days: 30)),
        end: _toDate ?? now,
      ),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  List<ServiceEntry> _filteredServices(List<ServiceEntry> list) {
    final query = _searchQuery.trim().toLowerCase();
    return list
        .where((s) {
          if (!isDateWithinRange(s.serviceDate, _fromDate, _toDate)) return false;
          if (query.isEmpty) return true;

          final searchableText = [
            s.id,
            s.customerName,
            s.title,
            s.branchName,
            s.staffName,
            s.staffPhone,
            s.softwareName,
            s.description,
            s.paymentStatus,
            s.serviceStatus,
            s.paymentType,
            s.addedByName,
            s.editedByName,
          ].whereType<String>().join(' ').toLowerCase();

          return searchableText.contains(query);
        })
        .toList();
  }

  List<TransactionModel> _txnsForService(
    String serviceId,
    List<TransactionModel> all,
  ) {
    final list = all.where((t) => t.serviceId == serviceId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final serviceProvider = context.watch<ServiceEntryProvider>();
    final txnProvider = context.watch<TransactionProvider>();

    final services = _filteredServices(serviceProvider.services);
    final allTxns = txnProvider.transactions;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          'Service & Transaction Report',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(context),
          ),
        ),
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        actions: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
              decoration: InputDecoration(
                hintText: 'Search customer, service, branch...',
                hintStyle: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.textSecondary(context)),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: Icon(Icons.clear, size: 18, color: AppTheme.textSecondary(context)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: AppTheme.inputBg(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  borderSide: BorderSide(color: AppTheme.accent(context)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 170,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg(context),
                border: Border.all(color: AppTheme.cardBorderColor(context)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: InkWell(
                onTap: _pickDateRange,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.accent(context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _fromDate == null && _toDate == null
                            ? 'Filter by date'
                            : '${_fromDate != null ? DateFormat('dd MMM').format(_fromDate!) : ''}'
                                  '${_fromDate != null && _toDate != null ? ' - ' : ''}'
                                  '${_toDate != null ? DateFormat('dd MMM').format(_toDate!) : ''}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_fromDate != null || _toDate != null) ...[
            const SizedBox(width: 6),
            TextButton(
              onPressed: () => setState(() {
                _fromDate = null;
                _toDate = null;
              }),
              child: Text(
                'Reset',
                style: TextStyle(color: AppTheme.accent(context)),
              ),
            ),
          ],
          const SizedBox(width: 8),

          Padding(
            padding: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                color: services.isEmpty
                    ? Colors.grey.shade400
                    : (isDark ? FuturisticColors.neonCyan : Colors.teal),
                borderRadius: BorderRadius.circular(8),
              ),
              child: InkWell(
                onTap: services.isEmpty ? null : () => _exportPdf(services, allTxns),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Export PDF', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          InkWell(
            onTap: () => txnProvider.fetchTransactions(),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                LucideIcons.listRestart,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
      body: serviceProvider.isLoading && services.isEmpty
          ? Center(child: CircularProgressIndicator(color: AppTheme.accent(context)))
          : services.isEmpty
          ? Center(
              child: Text(
                'No services found',
                style: TextStyle(color: AppTheme.textSecondary(context)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                final txns = _txnsForService(service.id, allTxns);
                final balance = service.amount - service.customerPaidAmount;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorderColor(context)),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Service header table ───────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF132238) : Colors.teal.shade50,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: Text(
                                'SL',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: isDark ? FuturisticColors.neonCyan : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Customer',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: isDark ? FuturisticColors.neonCyan : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                textAlign: TextAlign.center,
                                'Service ID',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: isDark ? FuturisticColors.neonCyan : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                textAlign: TextAlign.center,
                                'Service By',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: isDark ? FuturisticColors.neonCyan : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 160,
                              child: Text(
                                textAlign: TextAlign.center,
                                'Service Date',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: isDark ? FuturisticColors.neonCyan : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                textAlign: TextAlign.center,
                                'Updated By',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: isDark ? FuturisticColors.neonCyan : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 160,
                              child: Text(
                                textAlign: TextAlign.center,
                                'Updated At',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: isDark ? FuturisticColors.neonCyan : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                'Amount',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: isDark ? FuturisticColors.neonCyan : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                'Paid',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: isDark ? FuturisticColors.neonCyan : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                'Balance',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: isDark ? FuturisticColors.neonCyan : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                   
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                service.customerName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                textAlign: TextAlign.center,
                                service.id,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                textAlign: TextAlign.center,
                                service.addedByName.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 160,
                              child: Text(
                                textAlign: TextAlign.center,
                                DateFormat(
                                  'dd/MM/yyyy hh:mm:ss a',
                                ).format(service.serviceDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                textAlign: TextAlign.center,
                                service.addedByName.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 160,
                              child: Text(
                                textAlign: TextAlign.center,
                                DateFormat(
                                  'dd/MM/yyyy hh:mm:ss a',
                                ).format(service.serviceDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                service.amount.toStringAsFixed(2),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                service.customerPaidAmount.toStringAsFixed(2),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark ? FuturisticColors.neonTeal : Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                balance.toStringAsFixed(2),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: balance > 0
                                      ? (isDark ? FuturisticColors.neonCrimson : Colors.red)
                                      : (isDark ? FuturisticColors.neonTeal : Colors.green),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Transaction Details ─────────────────────────
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0D1728) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cardBorderColor(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transaction Details',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (txns.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'No transactions',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary(context),
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            else ...[
                              // Txn header
                              Row(
                                children: [
                                  SizedBox(
                                    width: 32,
                                    child: Text(
                                      'SL',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: AppTheme.textSecondary(context),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Transaction ID',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: AppTheme.textSecondary(context),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      textAlign: TextAlign.center,
                                      'Created By',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: AppTheme.textSecondary(context),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      textAlign: TextAlign.center,
                                      'Payment Type',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: AppTheme.textSecondary(context),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      textAlign: TextAlign.center,
                                      'Transaction Date',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: AppTheme.textSecondary(context),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      'Amount',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: AppTheme.textSecondary(context),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      'Paid',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: AppTheme.textSecondary(context),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      'Balance',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: AppTheme.textSecondary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Divider(height: 14, color: AppTheme.cardBorderColor(context)),
                              // Running balance after each payment
                              ...() {
                                double runningPaid = 0;
                                return List.generate(txns.length, (i) {
                                  final t = txns[i];
                                  runningPaid += t.amount;
                                  final remaining =
                                      service.amount - runningPaid;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 32,
                                          child: Text(
                                            '${i + 1}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textPrimary(context),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            t.id,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textPrimary(context),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            t.addedByName,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textPrimary(context),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 100,
                                          child: Text(
                                            t.paymentType,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textPrimary(context),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            textAlign: TextAlign.center,
                                            DateFormat(
                                              'dd/MM/yyyy hh:mm:ss a',
                                            ).format(t.createdAt),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textPrimary(context),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 70,
                                          child: Text(
                                            t.pendingAmount.toStringAsFixed(2),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textPrimary(context),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 70,
                                          child: Text(
                                            t.amount.toStringAsFixed(2),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark ? FuturisticColors.neonTeal : Colors.green,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 70,
                                          child: Text(
                                            remaining.toStringAsFixed(2),
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: remaining > 0
                                                  ? (isDark ? FuturisticColors.neonCrimson : Colors.red)
                                                  : (isDark ? FuturisticColors.neonTeal : Colors.green),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                });
                              }(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _exportPdf(
    List<ServiceEntry> services,
    List<TransactionModel> allTxns,
  ) async {
    final rangeText = _fromDate == null && _toDate == null
        ? 'All time'
        : '${_fromDate != null ? DateFormat('dd/MM/yyyy').format(_fromDate!) : '...'}'
              ' - '
              '${_toDate != null ? DateFormat('dd/MM/yyyy').format(_toDate!) : '...'}';
    final totalInvoiced = services.fold<double>(0, (sum, s) => sum + s.amount);
    final totalCollected = services.fold<double>(0, (sum, s) => sum + s.customerPaidAmount);
    final totalBalance = totalInvoiced - totalCollected;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        footer: (context) => PdfThemeHelper.buildPageFooter(
          context: context,
          documentName: 'Service & Transactions Ledger | Period: $rangeText',
        ),
        build: (context) {
          final widgets = <pw.Widget>[
            // Header
            PdfThemeHelper.buildDocumentHeader(
              title: 'SERVICE & TRANSACTION LEDGER REPORT',
              subtitle: 'Consolidated overview of services, payments collected, and payment histories',
              dateText: 'Period: $rangeText',
              badgeText: '${services.length} Services',
            ),

            // KPI Summary
            PdfThemeHelper.buildKpiCardsRow([
              PdfKpiItem(
                label: 'Total Invoiced',
                value: 'SAR ${totalInvoiced.toStringAsFixed(2)}',
                color: PdfThemeHelper.darkSlate,
              ),
              PdfKpiItem(
                label: 'Total Collected',
                value: 'SAR ${totalCollected.toStringAsFixed(2)}',
                color: PdfThemeHelper.emeraldGreen,
              ),
              PdfKpiItem(
                label: 'Total Balance Due',
                value: 'SAR ${totalBalance.toStringAsFixed(2)}',
                color: totalBalance > 0 ? PdfThemeHelper.roseRed : PdfThemeHelper.emeraldGreen,
              ),
              PdfKpiItem(
                label: 'Total Services',
                value: '${services.length}',
                color: PdfThemeHelper.primaryTealDark,
              ),
            ]),

            PdfThemeHelper.buildSectionHeader(
              'SERVICE & TRANSACTION BREAKDOWNS',
              countText: '${services.length} items',
            ),
          ];

          for (var i = 0; i < services.length; i++) {
            final s = services[i];
            final txns = _txnsForService(s.id, allTxns);
            final bal = s.amount - s.customerPaidAmount;

            // Master Service Container Card
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfThemeHelper.borderColor, width: 0.8),
                ),
                child: pw.ClipRRect(
                  horizontalRadius: 6,
                  verticalRadius: 6,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Service Header Bar
                      pw.Container(
                        color: PdfThemeHelper.zebraBg,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Row(
                              children: [
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: pw.BoxDecoration(
                                    color: PdfThemeHelper.primaryTeal,
                                    borderRadius: pw.BorderRadius.circular(4),
                                  ),
                                  child: pw.Text(
                                    '#${i + 1}',
                                    style: pw.TextStyle(
                                      color: PdfColors.white,
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                                pw.SizedBox(width: 8),
                                pw.Text(
                                  s.customerName,
                                  style: pw.TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfThemeHelper.darkSlate,
                                  ),
                                ),
                                if (s.title.isNotEmpty) ...[
                                  pw.Text(
                                    '  |  ${s.title}',
                                    style: const pw.TextStyle(
                                      fontSize: 9,
                                      color: PdfThemeHelper.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            pw.Row(
                              children: [
                                pw.Text(
                                  'Invoiced: ',
                                  style: const pw.TextStyle(fontSize: 8, color: PdfThemeHelper.textMuted),
                                ),
                                pw.Text(
                                  'SAR ${s.amount.toStringAsFixed(2)}',
                                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                                ),
                                pw.SizedBox(width: 10),
                                pw.Text(
                                  'Paid: ',
                                  style: const pw.TextStyle(fontSize: 8, color: PdfThemeHelper.textMuted),
                                ),
                                pw.Text(
                                  'SAR ${s.customerPaidAmount.toStringAsFixed(2)}',
                                  style: pw.TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfThemeHelper.emeraldGreen,
                                  ),
                                ),
                                pw.SizedBox(width: 10),
                                pw.Text(
                                  'Balance: ',
                                  style: const pw.TextStyle(fontSize: 8, color: PdfThemeHelper.textMuted),
                                ),
                                pw.Text(
                                  'SAR ${bal.toStringAsFixed(2)}',
                                  style: pw.TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: bal > 0 ? PdfThemeHelper.roseRed : PdfThemeHelper.emeraldGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Transactions Sub-table
                      if (txns.isEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: pw.Text(
                            'No transaction payments recorded for this service.',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfThemeHelper.textMuted,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        pw.Table(
                          columnWidths: {
                            0: const pw.FixedColumnWidth(24),
                            1: const pw.FlexColumnWidth(2.0),
                            2: const pw.FlexColumnWidth(1.6),
                            3: const pw.FlexColumnWidth(1.2),
                            4: const pw.FlexColumnWidth(1.6),
                            5: const pw.FlexColumnWidth(1.2),
                            6: const pw.FlexColumnWidth(1.2),
                            7: const pw.FlexColumnWidth(1.2),
                          },
                          children: [
                            // Table Sub-header
                            pw.TableRow(
                              decoration: const pw.BoxDecoration(
                                color: PdfThemeHelper.darkSlate,
                              ),
                              children: [
                                _pdfReportCell('SL', isHeader: true, alignCenter: true),
                                _pdfReportCell('Transaction ID', isHeader: true),
                                _pdfReportCell('Recorded By', isHeader: true),
                                _pdfReportCell('Payment Type', isHeader: true),
                                _pdfReportCell('Date & Time', isHeader: true),
                                _pdfReportCell('Previous Due', isHeader: true, alignRight: true),
                                _pdfReportCell('Amount Paid', isHeader: true, alignRight: true),
                                _pdfReportCell('Remaining Due', isHeader: true, alignRight: true),
                              ],
                            ),

                            // Data Rows
                            ...txns.asMap().entries.map((txnEntry) {
                              final j = txnEntry.key;
                              final t = txnEntry.value;
                              final isEven = j % 2 == 0;
                              final double runningPaid = txns.take(j + 1).fold(0.0, (sum, tx) => sum + tx.amount);
                              final remaining = s.amount - runningPaid;

                              return pw.TableRow(
                                decoration: pw.BoxDecoration(
                                  color: isEven ? PdfColors.white : PdfThemeHelper.surfaceBg,
                                ),
                                children: [
                                  _pdfReportCell('${j + 1}', alignCenter: true, fontSize: 7.5),
                                  _pdfReportCell(t.id, fontSize: 7.5),
                                  _pdfReportCell(t.addedByName.isEmpty ? '-' : t.addedByName, fontSize: 7.5),
                                  _pdfReportBadgeCell(t.paymentType),
                                  _pdfReportCell(
                                    DateFormat('dd/MM/yy HH:mm').format(t.createdAt),
                                    fontSize: 7.5,
                                    color: PdfThemeHelper.textMuted,
                                  ),
                                  _pdfReportCell(
                                    (t.pendingAmount).toStringAsFixed(2),
                                    alignRight: true,
                                    fontSize: 7.5,
                                  ),
                                  _pdfReportCell(
                                    t.amount.toStringAsFixed(2),
                                    alignRight: true,
                                    isBold: true,
                                    fontSize: 7.5,
                                    color: PdfThemeHelper.emeraldGreen,
                                  ),
                                  _pdfReportCell(
                                    remaining.toStringAsFixed(2),
                                    alignRight: true,
                                    isBold: true,
                                    fontSize: 7.5,
                                    color: remaining > 0 ? PdfThemeHelper.roseRed : PdfThemeHelper.emeraldGreen,
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          }

          return widgets;
        },
      ),
    );

    final bytes = await pdf.save();
    final filename =
        'service_txn_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    if (!mounted) return;
    await showPdfActionsSheet(context: context, bytes: bytes, filename: filename);
  }

  pw.Widget _pdfReportCell(
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
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : (color ?? PdfThemeHelper.darkSlate),
        ),
      ),
    );
  }

  pw.Widget _pdfReportBadgeCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: PdfThemeHelper.buildStatusBadge(text),
    );
  }
}
