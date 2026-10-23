import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:entryon/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/profit_calculation_model.dart';
import '../providers/profit_calculation_provider.dart';
import '../utils/app_theme.dart';
import '../utils/pdf_actions.dart';
import '../utils/profit_calculator_pdf_generator.dart';
import 'editProfitCalculationScreen.dart';

class ProfitCalculationDetailsScreen extends StatefulWidget {
  final String? calculationId;
  final ProfitCalculation? initialCalculation;
  final List<ProfitCalculation>? combinedCalculations;

  const ProfitCalculationDetailsScreen({
    super.key,
    this.calculationId,
    this.initialCalculation,
    this.combinedCalculations,
  }) : assert(calculationId != null ||
            initialCalculation != null ||
            combinedCalculations != null);

  @override
  State<ProfitCalculationDetailsScreen> createState() =>
      _ProfitCalculationDetailsScreenState();
}

class _ProfitCalculationDetailsScreenState
    extends State<ProfitCalculationDetailsScreen> {
  final NumberFormat _fmt = NumberFormat('#,##0.00');
  final DateFormat _dateFmt = DateFormat('dd MMMM yyyy, hh:mm a');

  ProfitCalculation? _calc;
  List<ProfitCalculation> _combinedList = [];
  bool get _isCombined => _combinedList.length > 1;

  bool _isLoading = false;
  String? _error;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    if (widget.combinedCalculations != null &&
        widget.combinedCalculations!.isNotEmpty) {
      _combinedList = List.from(widget.combinedCalculations!);
      if (_combinedList.length == 1) {
        _calc = _combinedList.first;
      } else {
        _calc = ProfitCalculation.combine(_combinedList);
      }
    } else {
      _calc = widget.initialCalculation;
      if (_calc == null && widget.calculationId != null) {
        _loadCalculation();
      }
    }
  }

  Future<void> _loadCalculation() async {
    if (widget.calculationId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('profit_calculations')
          .doc(widget.calculationId)
          .get();

      if (!doc.exists) {
        setState(() {
          _error = 'Calculation record not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _calc = ProfitCalculation.fromMap(doc.data()!, doc.id);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading calculation: $e';
        _isLoading = false;
      });
    }
  }

  // ── Copy Statement ─────────────────────────────────────────────────────────
  void _copySummary(ProfitCalculation calc) {
    final vatSales = calc.salesWithTax - calc.salesWithoutTax;
    final vatPurchases = calc.purchasesWithTax - calc.purchasesWithoutTax;
    final commercialProfit = calc.salesWithTax - calc.purchasesWithTax;

    String contributingText = '';
    if (_isCombined) {
      contributingText = '''
\nContributing Statements (${_combinedList.length}):
${_combinedList.asMap().entries.map((e) => '  ${e.key + 1}. ${e.value.customerName ?? "General"} | ${e.value.periodName ?? "Period"} | Sales: ${_fmt.format(e.value.salesWithoutTax)} | Profit: ${_fmt.format(e.value.grossProfit)} (${e.value.profitMargin.toStringAsFixed(1)}%)').join('\n')}
''';
    }

    final text = '''
--- ${_isCombined ? "CONSOLIDATED PROFIT & TAX STATEMENT (${_combinedList.length} Statements)" : "PROFIT & TAX STATEMENT"} ---
Record ID: ${calc.id}
Customer: ${calc.customerName ?? 'General'}
Branch: ${calc.branchName ?? 'N/A'}
Period: ${calc.periodName ?? 'N/A'}
VAT Rate: ${calc.taxPercent.toStringAsFixed(0)}%
Created At: ${_dateFmt.format(calc.createdAt)}
Created By: ${calc.createdByName}

1. Sales:
   - Excl. VAT: ${_fmt.format(calc.salesWithoutTax)}
   - VAT: ${_fmt.format(vatSales)}
   - Incl. VAT: ${_fmt.format(calc.salesWithTax)}

2. Purchases:
   - Excl. VAT: ${_fmt.format(calc.purchasesWithoutTax)}
   - VAT: ${_fmt.format(vatPurchases)}
   - Incl. VAT: ${_fmt.format(calc.purchasesWithTax)}

3. Profit & Tax:
   - Gross Operating Profit (Excl. VAT): ${_fmt.format(calc.grossProfit)}
   - Commercial Profit (Incl. VAT): ${_fmt.format(commercialProfit)}
   - Profit Margin: ${calc.profitMargin.toStringAsFixed(2)}%
   - Net VAT Due: ${_fmt.format(calc.netVatDue)}$contributingText
''';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isCombined
            ? 'Consolidated statement copied to clipboard'
            : 'Financial statement copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Export PDF ─────────────────────────────────────────────────────────────
  Future<void> _exportPdf(ProfitCalculation calc) async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);

    try {
      final customerDisplayName = _isCombined
          ? 'Consolidated (${_combinedList.length} Statements)'
          : (calc.branchName != null && calc.branchName!.isNotEmpty
              ? '${calc.customerName ?? "General"} - ${calc.branchName}'
              : (calc.customerName ?? 'General'));

      final bytes = await ProfitCalculatorPdfGenerator.generate(
        customerName: customerDisplayName,
        periodName: calc.periodName,
        vatNumber: calc.vatNumber,
        taxPct: calc.taxPercent,
        enteredValuesIncludeVat: calc.enteredValuesIncludeVat,
        salesExTax: calc.salesWithoutTax,
        vatSales: calc.salesWithTax - calc.salesWithoutTax,
        salesInTax: calc.salesWithTax,
        purchasesExTax: calc.purchasesWithoutTax,
        vatPurchases: calc.purchasesWithTax - calc.purchasesWithoutTax,
        purchasesInTax: calc.purchasesWithTax,
        grossProfit: calc.grossProfit,
        grossProfitInTax: calc.salesWithTax - calc.purchasesWithTax,
        netVat: calc.netVatDue,
        margin: calc.profitMargin,
        hasTarget: calc.targetProfitAmount > 0 || calc.targetProfitPercent > 0,
        targetProfit: calc.targetProfit,
        targetDiff: calc.grossProfit - calc.targetProfit,
        hasSales: calc.enteredSales > 0,
        hasPurchases: calc.enteredPurchases > 0,
        reqSalesExTax: 0,
        allowPurchasesExTax: 0,
      );

      final periodSafe = (calc.periodName ?? 'statement')
          .replaceAll(RegExp(r'[\\/<>:"|?*\x00-\x1f\s]+'), '_');
      final fileName = _isCombined
          ? 'consolidated_profit_${_combinedList.length}_statements_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf'
          : 'profit_calc_${calc.id.substring(calc.id.length > 6 ? calc.id.length - 6 : 0)}_$periodSafe.pdf';

      if (!mounted) return;
      await showPdfActionsSheet(
        context: context,
        bytes: bytes,
        filename: fileName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(ProfitCalculation calc) async {
    final isDark = AppTheme.isDark(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppTheme.cardBorderColor(context)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Delete Statement',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete this calculation statement? '
          'All associated records will be removed.',
          style: TextStyle(
            fontSize: 13.5,
            color: AppTheme.textSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textMuted(context)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? FuturisticColors.neonCrimson : Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ok = await context
          .read<ProfitCalculationProvider>()
          .deleteCalculation(calc.id);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calculation deleted successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<ProfitCalculationProvider>().errorMessage ??
                'Unable to delete'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Edit ───────────────────────────────────────────────────────────────────
  Future<void> _openEdit(ProfitCalculation calc) async {
    final updated = await  Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 1000,
      maxHeight: 850,
      child:  EditProfitCalculationScreen(calculation: calc),
    );
    // Navigator.of(context).push<ProfitCalculation>(
    //   MaterialPageRoute(
    //     builder: (_) => EditProfitCalculationScreen(calculation: calc),
    //   ),
    // );
    if (updated != null && mounted) {
      setState(() => _calc = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: isDark ? FuturisticColors.bgSurface : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isCombined
                  ? 'Combined Calculation Details'
                  : 'Calculation Details',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
            ),
            if (_isCombined)
              Text(
                '${_combinedList.length} statements combined',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? FuturisticColors.neonCyan
                      : const Color(0xFF0D9488),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          if (_calc != null) ...[
            // Copy
            IconButton(
              tooltip: 'Copy Statement Summary',
              icon: const Icon(LucideIcons.copy, size: 18),
              onPressed: () => _copySummary(_calc!),
            ),
            // Export PDF
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: _isExportingPdf ? null : () => _exportPdf(_calc!),
                icon: _isExportingPdf
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded, size: 15),
                label: const Text('Export PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppTheme.cardBorderColor(context),
            height: 1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _calc == null
                  ? const Center(child: Text('Calculation record not found'))
                  : _buildContent(context, _calc!),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.alertCircle, size: 40, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadCalculation,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProfitCalculation calc) {
    final isDark = AppTheme.isDark(context);
    final isProfitable = calc.grossProfit >= 0;
    final costRatio = calc.salesWithoutTax > 0
        ? (calc.purchasesWithoutTax / calc.salesWithoutTax) * 100
        : 0.0;
    final commercialProfit = calc.salesWithTax - calc.purchasesWithTax;
    final isNetVatDue = calc.netVatDue >= 0;
    final vatSales = calc.salesWithTax - calc.salesWithoutTax;
    final vatPurchases = calc.purchasesWithTax - calc.purchasesWithoutTax;
    final hasTarget =
        calc.targetProfitAmount > 0 || calc.targetProfitPercent > 0;
    final targetDiff = calc.grossProfit - calc.targetProfit;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Metadata / Scope Card
              _buildScopeCard(context, calc, isProfitable),

              const SizedBox(height: 14),

              // 2. Highlight KPI Row
              _buildKpiGrid(context, calc, commercialProfit, isProfitable),

              const SizedBox(height: 14),

              // 3. Financial Statement Table
              _buildStatementTableCard(
                context,
                calc: calc,
                vatSales: vatSales,
                vatPurchases: vatPurchases,
                commercialProfit: commercialProfit,
                costRatio: costRatio,
                isProfitable: isProfitable,
              ),

              const SizedBox(height: 14),

              // 4. VAT & Cash Reconciliation Card
              _buildVatReconciliationCard(
                context,
                vatSales: vatSales,
                vatPurchases: vatPurchases,
                netVat: calc.netVatDue,
                isNetVatDue: isNetVatDue,
                isDark: isDark,
              ),

              if (hasTarget) ...[
                const SizedBox(height: 14),
                // 5. Target Performance Comparison Card
                _buildTargetPerformanceCard(
                  context,
                  calc: calc,
                  targetDiff: targetDiff,
                  isDark: isDark,
                ),
              ],

              if (_isCombined) ...[
                const SizedBox(height: 14),
                // 5.1 Contributing Calculations Breakdown Table
                _buildContributingCalculationsCard(context, _combinedList),
              ],

              const SizedBox(height: 20),

              // 6. Action Bottom Bar
              _buildBottomActions(context, calc),
            ],
          ),
        ),
      ),
    );
  }

  // ── Scope / Context Card ───────────────────────────────────────────────────
  Widget _buildScopeCard(
      BuildContext context, ProfitCalculation calc, bool isProfitable) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: (isDark
                                ? FuturisticColors.neonCyan
                                : const Color(0xFF0D9488))
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _isCombined ? LucideIcons.layers : LucideIcons.fileText,
                        color: isDark
                            ? FuturisticColors.neonCyan
                            : const Color(0xFF0D9488),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isCombined
                                ? 'Consolidated Financial Statement'
                                : (calc.customerName ??
                                    'General / Standalone Customer'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                          Text(
                            _isCombined
                                ? '${_combinedList.length} Individual Calculations Combined | ${calc.customerName ?? ""}'
                                : (calc.branchName != null &&
                                        calc.branchName!.isNotEmpty
                                    ? 'Branch: ${calc.branchName}'
                                    : 'Standalone Account'),
                            style: TextStyle(
                              fontSize: 12.5,
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
              ),
              const SizedBox(width: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  if (_isCombined)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (isDark
                                ? FuturisticColors.neonCyan
                                : const Color(0xFF0D9488))
                            .withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.layers,
                            size: 13,
                            color: isDark
                                ? FuturisticColors.neonCyan
                                : const Color(0xFF0D9488),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${_combinedList.length} STATEMENTS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? FuturisticColors.neonCyan
                                  : const Color(0xFF0D9488),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (isProfitable
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444))
                          .withValues(alpha: isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isProfitable
                              ? LucideIcons.trendingUp
                              : LucideIcons.trendingDown,
                          size: 14,
                          color: isProfitable
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${calc.profitMargin.toStringAsFixed(1)}% ${_isCombined ? "OVERALL " : ""}MARGIN',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: isProfitable
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(height: 1, color: AppTheme.cardBorderColor(context)),
          const SizedBox(height: 12),

          // Metadata Grid
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _metaItem(
                context,
                label: _isCombined ? 'Scope' : 'Financial Period',
                value: _isCombined
                    ? '${_combinedList.length} Calculations Consolidated'
                    : (calc.periodName ?? 'Unspecified'),
                icon: _isCombined ? LucideIcons.layers : LucideIcons.calendar,
              ),
              _metaItem(
                context,
                label: 'Periods Covered',
                value: calc.periodName ?? 'Various Periods',
                icon: LucideIcons.calendar,
              ),
              _metaItem(
                context,
                label: 'Tax Regime',
                value: '${calc.taxPercent.toStringAsFixed(0)}% Standard VAT',
                icon: LucideIcons.percent,
              ),
              _metaItem(
                context,
                label: 'Basis',
                value: calc.enteredValuesIncludeVat
                    ? 'Gross (Entered values include VAT)'
                    : 'Net (Entered values exclude VAT)',
                icon: LucideIcons.checkCheck,
              ),
              _metaItem(
                context,
                label: _isCombined ? 'Latest Timestamp' : 'Logged Date & Time',
                value: _dateFmt.format(calc.createdAt),
                icon: LucideIcons.clock,
              ),
              if (calc.createdByName.isNotEmpty)
                _metaItem(
                  context,
                  label: 'Prepared By',
                  value: calc.createdByName,
                  icon: LucideIcons.user,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted(context)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: AppTheme.textMuted(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Highlight KPI Grid ─────────────────────────────────────────────────────
  Widget _buildKpiGrid(
    BuildContext context,
    ProfitCalculation calc,
    double commercialProfit,
    bool isProfitable,
  ) {
    final isDark = AppTheme.isDark(context);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isNarrow = constraints.maxWidth < 650;

        final items = [
          _kpiBox(
            context,
            label: 'Net Operating Profit',
            value: _fmt.format(calc.grossProfit),
            subtitle: 'Excl. VAT Base',
            color: isProfitable
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
            icon: LucideIcons.wallet,
          ),
          _kpiBox(
            context,
            label: 'Commercial Profit',
            value: _fmt.format(commercialProfit),
            subtitle: 'Gross (Incl. VAT)',
            color: isDark
                ? FuturisticColors.neonCyan
                : const Color(0xFF0D9488),
            icon: LucideIcons.coins,
          ),
          _kpiBox(
            context,
            label: 'Net VAT Due',
            value: _fmt.format(calc.netVatDue.abs()),
            subtitle: calc.netVatDue >= 0
                ? 'Payable to ZATCA'
                : 'Refundable Credit',
            color: const Color(0xFF6366F1),
            icon: LucideIcons.receipt,
          ),
          _kpiBox(
            context,
            label: 'Profit Margin',
            value: '${calc.profitMargin.toStringAsFixed(2)}%',
            subtitle: '% of Net Sales',
            color: const Color(0xFFF59E0B),
            icon: LucideIcons.pieChart,
          ),
        ];

        if (isNarrow) {
          return Column(
            children: items
                .map((it) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: it,
                    ))
                .toList(),
          );
        }

        return Row(
          children: items
              .map((it) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: it,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _kpiBox(
    BuildContext context, {
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary(context),
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.5,
              color: AppTheme.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── Financial Statement Table Card ─────────────────────────────────────────
  Widget _buildStatementTableCard(
    BuildContext context, {
    required ProfitCalculation calc,
    required double vatSales,
    required double vatPurchases,
    required double commercialProfit,
    required double costRatio,
    required bool isProfitable,
  }) {
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? FuturisticColors.bgSurface
                    : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: AppTheme.cardBorderColor(context)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.table,
                    size: 17,
                    color: isDark
                        ? FuturisticColors.neonCyan
                        : const Color(0xFF0D9488),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Financial Statement & Tax Reconciliation',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 680),
                child: DataTable(
                  headingRowHeight: 38,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 54,
                  horizontalMargin: 16,
                  columnSpacing: 18,
                  columns: [
                    _tableHeaderCol('LINE ITEM'),
                    _tableHeaderCol('EXCL. VAT', numeric: true),
                    _tableHeaderCol('VAT (${calc.taxPercent.toStringAsFixed(0)}%)', numeric: true),
                    _tableHeaderCol('INCL. VAT', numeric: true),
                    _tableHeaderCol('% OF SALES', numeric: true),
                    _tableHeaderCol('TYPE'),
                  ],
                  rows: [
                    // Line 1: Turnover / Sales
                    _statementRow(
                      context,
                      icon: LucideIcons.trendingUp,
                      iconColor: const Color(0xFF10B981),
                      title: 'Turnover / Total Sales',
                      subtitle: 'Commercial billings',
                      exclVat: calc.salesWithoutTax,
                      vat: vatSales,
                      inclVat: calc.salesWithTax,
                      ratioText: '100.0%',
                      badgeText: 'REVENUE',
                      badgeColor: const Color(0xFF10B981),
                    ),

                    // Line 2: Purchases
                    _statementRow(
                      context,
                      icon: LucideIcons.shoppingBag,
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Direct Costs / Purchases',
                      subtitle: 'COGS & supplier bills',
                      exclVat: calc.purchasesWithoutTax,
                      vat: vatPurchases,
                      inclVat: calc.purchasesWithTax,
                      ratioText: '${costRatio.toStringAsFixed(1)}%',
                      badgeText: 'DIRECT COST',
                      badgeColor: const Color(0xFFF59E0B),
                    ),

                    // Line 3: Gross Profit
                    _statementRow(
                      context,
                      icon: LucideIcons.checkCircle2,
                      iconColor: isProfitable
                          ? (isDark
                              ? FuturisticColors.neonCyan
                              : const Color(0xFF0D9488))
                          : const Color(0xFFEF4444),
                      title: 'Gross Operating Profit',
                      subtitle: isProfitable
                          ? 'Net positive commercial margin'
                          : 'Operating deficit / loss',
                      exclVat: calc.grossProfit,
                      vat: vatSales - vatPurchases,
                      inclVat: commercialProfit,
                      ratioText: '${calc.profitMargin.toStringAsFixed(1)}%',
                      badgeText: isProfitable ? 'NET PROFIT' : 'NET DEFICIT',
                      badgeColor: isProfitable
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      isHighlight: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataColumn _tableHeaderCol(String label, {bool numeric = false}) {
    return DataColumn(
      numeric: numeric,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary(context),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  DataRow _statementRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required double exclVat,
    required double vat,
    required double inclVat,
    required String ratioText,
    required String badgeText,
    required Color badgeColor,
    bool isHighlight = false,
  }) {
    final isDark = AppTheme.isDark(context);

    return DataRow(
      color: isHighlight
          ? WidgetStateProperty.all(badgeColor.withValues(alpha: isDark ? 0.12 : 0.07))
          : null,
      cells: [
        // 1. Line item
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
                      color: isHighlight
                          ? (isDark
                              ? FuturisticColors.neonCyan
                              : const Color(0xFF0D9488))
                          : AppTheme.textPrimary(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppTheme.textMuted(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. Excl. VAT
        DataCell(
          Text(
            _fmt.format(exclVat),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              color: AppTheme.textPrimary(context),
            ),
          ),
        ),

        // 3. VAT
        DataCell(
          Text(
            _fmt.format(vat),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ),

        // 4. Incl. VAT
        DataCell(
          Text(
            _fmt.format(inclVat),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              color: isHighlight ? badgeColor : AppTheme.textPrimary(context),
            ),
          ),
        ),

        // 5. % of Sales
        DataCell(
          Text(
            ratioText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ),

        // 6. Type Badge
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: badgeColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── VAT Reconciliation Card ────────────────────────────────────────────────
  Widget _buildVatReconciliationCard(
    BuildContext context, {
    required double vatSales,
    required double vatPurchases,
    required double netVat,
    required bool isNetVatDue,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.receipt,
                size: 17,
                color: isDark
                    ? FuturisticColors.neonCyan
                    : const Color(0xFF0D9488),
              ),
              const SizedBox(width: 8),
              Text(
                'ZATCA VAT Reconciliation',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _vatPill(
                context,
                label: 'Output VAT (Sales)',
                amount: vatSales,
                color: const Color(0xFF10B981),
              ),
              _vatPill(
                context,
                label: 'Input VAT (Purchases)',
                amount: vatPurchases,
                color: const Color(0xFFF59E0B),
              ),
              _vatPill(
                context,
                label: isNetVatDue
                    ? 'Net VAT Due to ZATCA'
                    : 'Net VAT Refundable Credit',
                amount: netVat.abs(),
                color: isNetVatDue
                    ? const Color(0xFF6366F1)
                    : const Color(0xFF10B981),
                isBold: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vatPill(
    BuildContext context, {
    required String label,
    required double amount,
    required Color color,
    bool isBold = false,
  }) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _fmt.format(amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Target Performance Card ────────────────────────────────────────────────
  Widget _buildTargetPerformanceCard(
    BuildContext context, {
    required ProfitCalculation calc,
    required double targetDiff,
    required bool isDark,
  }) {
    final targetMet = targetDiff >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.target,
                size: 17,
                color: isDark
                    ? FuturisticColors.neonCyan
                    : const Color(0xFF0D9488),
              ),
              const SizedBox(width: 8),
              Text(
                'Target Profit Variance & Performance',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _targetPill(
                context,
                label: 'Target Profit Benchmark',
                value: _fmt.format(calc.targetProfit),
                subtitle: calc.targetProfitPercent > 0
                    ? '${calc.targetProfitPercent.toStringAsFixed(1)}% of Sales Target'
                    : 'Fixed Amount Target',
                color: const Color(0xFF3B82F6),
              ),
              _targetPill(
                context,
                label: 'Actual Achieved Profit',
                value: _fmt.format(calc.grossProfit),
                subtitle: '${calc.profitMargin.toStringAsFixed(1)}% Actual Margin',
                color: calc.grossProfit >= 0
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
              _targetPill(
                context,
                label: targetMet ? 'Target Surplus' : 'Target Deficit',
                value: _fmt.format(targetDiff.abs()),
                subtitle: targetMet ? 'Target achieved / exceeded' : 'Below benchmark target',
                color: targetMet
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _targetPill(
    BuildContext context, {
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.5,
              color: AppTheme.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── Contributing Calculations Table Card (Combined Mode) ───────────────────
  Widget _buildContributingCalculationsCard(
      BuildContext context, List<ProfitCalculation> list) {
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? FuturisticColors.bgSurface
                    : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: AppTheme.cardBorderColor(context)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (isDark
                              ? FuturisticColors.neonCyan
                              : const Color(0xFF0D9488))
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.layers,
                      size: 17,
                      color: isDark
                          ? FuturisticColors.neonCyan
                          : const Color(0xFF0D9488),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contributing Calculations Breakdown (${list.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        Text(
                          'Individual statements included in this consolidated report',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 780),
                child: DataTable(
                  headingRowHeight: 38,
                  dataRowMinHeight: 46,
                  dataRowMaxHeight: 52,
                  horizontalMargin: 16,
                  columnSpacing: 18,
                  headingRowColor: WidgetStateProperty.all(
                    isDark
                        ? FuturisticColors.bgElevated.withValues(alpha: 0.4)
                        : const Color(0xFFF1F5F9),
                  ),
                  columns: const [
                    DataColumn(
                      label: Text(
                        '#',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'CUSTOMER & BRANCH',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'PERIOD',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'TURNOVER (EXCL. VAT)',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'PURCHASES (EXCL. VAT)',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'GROSS PROFIT',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'MARGIN %',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'NET VAT DUE',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'ACTION',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  rows: list.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final item = entry.value;
                    final isProf = item.grossProfit >= 0;

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            '$idx',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted(context),
                            ),
                          ),
                        ),
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.customerName ?? 'General',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              if (item.branchName != null &&
                                  item.branchName!.isNotEmpty)
                                Text(
                                  item.branchName!,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: AppTheme.textMuted(context),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            item.periodName ?? 'N/A',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _fmt.format(item.salesWithoutTax),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _fmt.format(item.purchasesWithoutTax),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _fmt.format(item.grossProfit),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isProf
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${item.profitMargin.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isProf
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _fmt.format(item.netVatDue),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon:
                                const Icon(LucideIcons.externalLink, size: 15),
                            tooltip: 'View Individual Calculation',
                            color: isDark
                                ? FuturisticColors.neonCyan
                                : const Color(0xFF0D9488),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProfitCalculationDetailsScreen(
                                    calculationId: item.id,
                                    initialCalculation: item,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Action Toolbar ──────────────────────────────────────────────────
  Widget _buildBottomActions(BuildContext context, ProfitCalculation calc) {
    final isDark = AppTheme.isDark(context);
    final tealColor =
        isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488);

    if (_isCombined) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.arrowLeft, size: 15),
            label: const Text('Back to List'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.cardBorderColor(context)),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          Wrap(
            spacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _copySummary(calc),
                icon: const Icon(LucideIcons.copy, size: 15),
                label: const Text('Copy Summary'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.cardBorderColor(context)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isExportingPdf ? null : () => _exportPdf(calc),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('Export Consolidated PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Delete
        OutlinedButton.icon(
          onPressed: () => _confirmDelete(calc),
          icon: const Icon(LucideIcons.trash2, size: 15, color: Colors.red),
          label: const Text('Delete', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        const SizedBox(width: 10),

        // Edit
        ElevatedButton.icon(
          onPressed: () => _openEdit(calc),
          icon: const Icon(LucideIcons.pencil, size: 15),
          label: const Text('Edit Calculation'),
          style: ElevatedButton.styleFrom(
            backgroundColor: tealColor,
            foregroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
