import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final Future<QuerySnapshot<Map<String, dynamic>>> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = FirebaseFirestore.instance
        .collection('purchase_invoices')
        .orderBy('invoiceDate', descending: true)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Reports',
          style: TextStyle(
            color: AppTheme.textPrimary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
      ),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppTheme.accent(context)));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load reports: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            );
          }

          final invoices = snapshot.data?.docs ?? [];
          if (invoices.isEmpty) {
            return Center(
              child: Text(
                'No purchase invoices found yet.',
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary(context)),
              ),
            );
          }

          final report = _buildReportMetrics(invoices);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(report),
                const SizedBox(height: 16),
                Text(
                  'Latest invoices',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildInvoiceList(invoices)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(_ReportMetrics report) {
    final isDark = AppTheme.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Purchase Report',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            runSpacing: 12,
            spacing: 12,
            children: [
              _buildInfoTile('Invoices', report.totalInvoices.toString()),
              _buildInfoTile('Ex VAT', _formatCurrency(report.totalExVat)),
              _buildInfoTile('VAT', _formatCurrency(report.totalVat)),
              _buildInfoTile('Inc VAT', _formatCurrency(report.totalIncVat)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    final isDark = AppTheme.isDark(context);
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A2C) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AppTheme.textSecondary(context))),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? FuturisticColors.neonCyan : AppTheme.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList(List<QueryDocumentSnapshot<Map<String, dynamic>>> invoices) {
    return ListView.separated(
      itemCount: invoices.length.clamp(0, 8),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final invoice = invoices[index].data();
        final invoiceNo = invoice['invoiceNo']?.toString() ?? 'Unknown';
        final supplierName = invoice['supplierName']?.toString() ?? 'Unknown supplier';
        final invoiceDate = _parseDate(invoice['invoiceDate']);
        final totalIncVat = (invoice['totalAmountIncVat'] as num?)?.toDouble() ?? 0.0;

        final isDark = AppTheme.isDark(context);
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.cardBorderColor(context)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoiceNo,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(supplierName, style: TextStyle(color: AppTheme.textSecondary(context))),
                    const SizedBox(height: 6),
                    Text(_formatDate(invoiceDate), style: TextStyle(color: AppTheme.textSecondary(context))),
                  ],
                ),
              ),
              Text(
                _formatCurrency(totalIncVat),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? FuturisticColors.neonTeal : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _ReportMetrics _buildReportMetrics(List<QueryDocumentSnapshot<Map<String, dynamic>>> invoices) {
    var totalExVat = 0.0;
    var totalVat = 0.0;
    var totalIncVat = 0.0;

    for (final doc in invoices) {
      final data = doc.data();
      totalExVat += (data['totalAmountExVat'] as num?)?.toDouble() ?? 0.0;
      totalVat += (data['totalVatAmount'] as num?)?.toDouble() ?? 0.0;
      totalIncVat += (data['totalAmountIncVat'] as num?)?.toDouble() ?? 0.0;
    }

    return _ReportMetrics(
      totalInvoices: invoices.length,
      totalExVat: totalExVat,
      totalVat: totalVat,
      totalIncVat: totalIncVat,
    );
  }

  DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return DateTime.now();
    final raw = value.toString();
    if (raw.contains('Timestamp')) {
      try {
        return (value as dynamic).toDate();
      } catch (_) {
        return DateTime.now();
      }
    }
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return DateTime.now();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatCurrency(double value) {
    return 'SAR ${value.toStringAsFixed(2)}';
  }
}

class _ReportMetrics {
  final int totalInvoices;
  final double totalExVat;
  final double totalVat;
  final double totalIncVat;

  _ReportMetrics({
    required this.totalInvoices,
    required this.totalExVat,
    required this.totalVat,
    required this.totalIncVat,
  });
}
