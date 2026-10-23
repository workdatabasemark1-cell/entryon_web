import 'dart:math' as math;
import 'package:entryon/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/profit_calculation_model.dart';
import '../providers/auth_Provider.dart';
import '../providers/profit_calculation_provider.dart';
import '../utils/app_theme.dart';
import '../utils/pdf_actions.dart';
import '../utils/profit_calculator_pdf_generator.dart';
import 'editProfitCalculationScreen.dart';
import 'profitCalculationDetailsScreen.dart';
import 'profitCalculatorScreen.dart';

enum ProfitFilterStatus { all, profitable, deficit }
enum ProfitSortOption { newest, oldest, highestProfit, lowestProfit, highestMargin }

class ProfitCalculationsListScreen extends StatefulWidget {
  const ProfitCalculationsListScreen({super.key});

  @override
  State<ProfitCalculationsListScreen> createState() =>
      _ProfitCalculationsListScreenState();
}

class _ProfitCalculationsListScreenState
    extends State<ProfitCalculationsListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final NumberFormat _fmt = NumberFormat('#,##0.00');
  final DateFormat _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

  String _searchQuery = '';
  String? _selectedPeriod;
  final ProfitFilterStatus _statusFilter = ProfitFilterStatus.all;
  ProfitSortOption _sortOption = ProfitSortOption.newest;
  bool _isTableView = true;
  bool _isExportingId = false;
  String? _exportingCalcId;
  bool _isExportingCombined = false;
  bool _isExportingArabic = false;

  // ── Multi-Selection State ──────────────────────────────────────────────────
  final Set<String> _selectedCalcIds = {};
  bool get _isSelectionMode => _selectedCalcIds.isNotEmpty;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedCalcIds.contains(id)) {
        _selectedCalcIds.remove(id);
      } else {
        _selectedCalcIds.add(id);
      }
    });
  }

  void _selectAll(List<ProfitCalculation> list) {
    setState(() {
      _selectedCalcIds.addAll(list.map((c) => c.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedCalcIds.clear();
    });
  }

  void _openCombinedDetails(List<ProfitCalculation> allList) {
    final selectedList =
        allList.where((c) => _selectedCalcIds.contains(c.id)).toList();
    if (selectedList.isEmpty) return;

    if (selectedList.length == 1) {
      _openDetails(selectedList.first);
      return;
    }
 Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 1000,
      maxHeight: 850,
      child:  ProfitCalculationDetailsScreen(
          combinedCalculations: selectedList,
        ),
    );
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (_) => ProfitCalculationDetailsScreen(
    //       combinedCalculations: selectedList,
    //     ),
    //   ),
    // );
  }

  Future<void> _saveCombinedCalculation(
      List<ProfitCalculation> allList) async {
    final selectedList =
        allList.where((c) => _selectedCalcIds.contains(c.id)).toList();
    if (selectedList.length < 2) return;

    final auth = context.read<AuthProvider>();
    final combined = ProfitCalculation.combine(selectedList).copyWith(
      id: 'combined_${DateTime.now().millisecondsSinceEpoch}',
      createdById: auth.currentUserId,
      createdByName: auth.currentUserName,
      createdAt: DateTime.now(),
    );
    final provider = context.read<ProfitCalculationProvider>();
    final saved = await provider.saveCalculation(combined);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved
            ? 'Combined calculation saved successfully'
            : provider.errorMessage ?? 'Unable to save combined calculation'),
        backgroundColor: saved ? const Color(0xFF10B981) : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfitCalculationProvider>().listenToCalculations();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filtering and Sorting ──────────────────────────────────────────────────
  List<ProfitCalculation> _getFilteredCalculations(
      List<ProfitCalculation> list) {
    var result = list.where((calc) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final customer = (calc.customerName ?? '').toLowerCase();
        final branch = (calc.branchName ?? '').toLowerCase();
        final period = (calc.periodName ?? '').toLowerCase();
        final createdBy = calc.createdByName.toLowerCase();
        if (!customer.contains(q) &&
            !branch.contains(q) &&
            !period.contains(q) &&
            !createdBy.contains(q)) {
          return false;
        }
      }

      // 2. Period Filter
      if (_selectedPeriod != null && _selectedPeriod!.isNotEmpty) {
        if (calc.periodName != _selectedPeriod) {
          return false;
        }
      }

      // 3. Profit Status Filter
      if (_statusFilter == ProfitFilterStatus.profitable &&
          calc.grossProfit < 0) {
        return false;
      }
      if (_statusFilter == ProfitFilterStatus.deficit &&
          calc.grossProfit >= 0) {
        return false;
      }

      return true;
    }).toList();

    // Sorting
    switch (_sortOption) {
      case ProfitSortOption.newest:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case ProfitSortOption.oldest:
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case ProfitSortOption.highestProfit:
        result.sort((a, b) => b.grossProfit.compareTo(a.grossProfit));
        break;
      case ProfitSortOption.lowestProfit:
        result.sort((a, b) => a.grossProfit.compareTo(b.grossProfit));
        break;
      case ProfitSortOption.highestMargin:
        result.sort((a, b) => b.profitMargin.compareTo(a.profitMargin));
        break;
    }

    return result;
  }

  // ── Export PDF ─────────────────────────────────────────────────────────────
  Future<void> _exportPdf(ProfitCalculation calc) async {
    if (_isExportingId) return;
    setState(() {
      _isExportingId = true;
      _exportingCalcId = calc.id;
    });

    try {
      final customerDisplayName = calc.branchName != null &&
              calc.branchName!.isNotEmpty
          ? calc.customerName ?? "General"
          : (calc.customerName ?? 'General');

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
      final fileName = 'profit_calc_${calc.id.substring(calc.id.length > 6 ? calc.id.length - 6 : 0)}_$periodSafe.pdf';

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
      if (mounted) {
        setState(() {
          _isExportingId = false;
          _exportingCalcId = null;
        });
      }
    }
  }

  Future<void> _exportSelectedCalculationsPdf(
      List<ProfitCalculation> allList) async {
    if (_isExportingId || _isExportingCombined) return;
    final selected =
        allList.where((calc) => _selectedCalcIds.contains(calc.id)).toList();
    if (selected.isEmpty) return;

    setState(() => _isExportingCombined = true);
    try {
      final bytes = await ProfitCalculatorPdfGenerator.generateMultiple(selected);
      if (!mounted) return;
      await showPdfActionsSheet(
        context: context,
        bytes: bytes,
        filename:
            'profit_calculations_${selected.length}_statements_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export selected PDFs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingCombined = false);
    }
  }

  Future<void> _exportSelectedCalculationsArabicPdf(
      List<ProfitCalculation> allList) async {
    if (_isExportingId || _isExportingCombined || _isExportingArabic) return;
    final selected =
        allList.where((calc) => _selectedCalcIds.contains(calc.id)).toList();
    if (selected.isEmpty) return;

    setState(() => _isExportingArabic = true);
    try {
      final bytes =
          await ProfitCalculatorPdfGenerator.generateMultipleArabic(selected);
      if (!mounted) return;
      await showPdfActionsSheet(
        context: context,
        bytes: bytes,
        filename:
            'profit_calculations_arabic_${selected.length}_statements_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export Arabic PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingArabic = false);
    }
  }

  // ── Delete Calculation Dialog ──────────────────────────────────────────────
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
              'Delete Calculation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this profit calculation for '
          '"${calc.customerName ?? "General"}" (${calc.periodName ?? "Unnamed Period"})? '
          'This action cannot be undone.',
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final prov = context.read<ProfitCalculationProvider>();
      final ok = await prov.deleteCalculation(calc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Calculation deleted successfully'
              : (prov.errorMessage ?? 'Unable to delete')),
          backgroundColor: ok ? const Color(0xFF10B981) : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _openCalculator() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfitCalculatorScreen()),
    );
  }

  void _openDetails(ProfitCalculation calc) {
     Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 1000,
      maxHeight: 850,
      child:  ProfitCalculationDetailsScreen(calculationId: calc.id),
    );
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (_) => ProfitCalculationDetailsScreen(calculationId: calc.id),
    //   ),
    // );
  }

  void _openEdit(ProfitCalculation calc) {
    Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 1000,
      maxHeight: 850,
      child:  EditProfitCalculationScreen(calculation: calc),
    );
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (_) => EditProfitCalculationScreen(calculation: calc),
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProfitCalculationProvider>();
    final allCalculations = prov.calculations;
    final filtered = _getFilteredCalculations(allCalculations);

    // Extract unique periods for filter dropdown
    final periods = allCalculations
        .map((c) => c.periodName)
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: _buildAppBar(context, allCalculations.length, filtered),
      body: prov.isLoading && allCalculations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // // 1. KPI Summary Cards
                      // _buildKpiSummary(context, filtered),
                  
                      // 2. Search & Filters Bar
                      _buildFilterBar(context, periods),
                  
                       const SizedBox(height: 8),
                  
                      // 3. Main Data Area (Table or Cards)
                      Expanded(
                        child: filtered.isEmpty
                            ? _buildEmptyState(context, prov.isLoading)
                              : _isTableView
                                ? _buildTableView(context, filtered)
                                : _buildCardsView(context, filtered),
                      ),
                  
                      if (_isSelectionMode)
                        const SizedBox(height: 70),
                    ],
                  ),
                ),

                // Floating Selection Bottom Bar
                if (_isSelectionMode)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildSelectionBottomBar(
                        context, allCalculations, filtered),
                  ),
              ],
            ),
    );
  }

  // ── Header / AppBar ────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(
      BuildContext context, int totalCount, List<ProfitCalculation> filtered) {
    final isDark = AppTheme.isDark(context);
    final tealColor =
        isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488);

    return AppBar(
      backgroundColor: isDark ? FuturisticColors.bgSurface : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppTheme.textPrimary(context)),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: tealColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              _isSelectionMode
                  ? LucideIcons.checkSquare
                  : LucideIcons.calculator,
              size: 20,
              color: tealColor,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSelectionMode
                    ? '${_selectedCalcIds.length} Selected'
                    : 'Profit Calculations',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              Text(
                _isSelectionMode
                    ? 'Select multiple calculations to combine'
                    : '$totalCount record${totalCount == 1 ? '' : 's'} logged',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Consumer<ProfitCalculationProvider>(
          builder: (context, provider, _) => IconButton(
            tooltip: 'Refresh calculations',
            onPressed: provider.isLoading
                ? null
                : () => provider.listenToCalculations(),
            icon: provider.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.refreshCw, size: 18),
            color: tealColor,
          ),
        ),
        const SizedBox(width: 4),
        if (_isSelectionMode) ...[
          TextButton.icon(
            onPressed: _clearSelection,
            icon: const Icon(LucideIcons.x, size: 14),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => _openCombinedDetails(filtered),
              icon: Icon(
                _selectedCalcIds.length > 1
                    ? LucideIcons.layers
                    : LucideIcons.eye,
                size: 16,
              ),
              label: Text(
                _selectedCalcIds.length > 1
                    ? 'Combine (${_selectedCalcIds.length})'
                    : 'View Details',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _openCalculator,
              icon: const Icon(LucideIcons.plusCircle, size: 16),
              label: const Text('New Calculation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: tealColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: AppTheme.cardBorderColor(context),
          height: 1,
        ),
      ),
    );
  }

  // ── KPI Summary ────────────────────────────────────────────────────────────
  Widget _buildKpiSummary(
      BuildContext context, List<ProfitCalculation> calculations) {
    final isDark = AppTheme.isDark(context);

    double totalTurnover = 0;
    double totalPurchases = 0;
    double cumulativeProfit = 0;
    double totalVatDue = 0;

    for (final c in calculations) {
      totalTurnover += c.salesWithoutTax;
      totalPurchases += c.purchasesWithoutTax;
      cumulativeProfit += c.grossProfit;
      totalVatDue += c.netVatDue;
    }

    final avgMargin = totalTurnover > 0
        ? (cumulativeProfit / totalTurnover) * 100
        : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final isNarrow = constraints.maxWidth < 700;

          final kpis = [
            _buildKpiItem(
              context,
              label: 'Total Calculations',
              value: calculations.length.toString(),
              icon: LucideIcons.layers,
              color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
            ),
            _buildKpiItem(
              context,
              label: 'Cumulative Turnover',
              value: _fmt.format(totalTurnover),
              icon: LucideIcons.trendingUp,
              color: const Color(0xFF3B82F6),
            ),
            _buildKpiItem(
              context,
              label: 'Direct Purchases',
              value: _fmt.format(totalPurchases),
              icon: LucideIcons.shoppingBag,
              color: const Color(0xFFF59E0B),
            ),
            _buildKpiItem(
              context,
              label: 'Cumulative Profit',
              value: _fmt.format(cumulativeProfit),
              icon: LucideIcons.wallet,
              color: cumulativeProfit >= 0
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
            ),
            _buildKpiItem(
              context,
              label: 'Average Margin',
              value: '${avgMargin.toStringAsFixed(1)}%',
              icon: LucideIcons.pieChart,
              color: const Color(0xFFF59E0B),
            ),
            _buildKpiItem(
              context,
              label: 'Net VAT Position',
              value: _fmt.format(totalVatDue),
              icon: LucideIcons.receipt,
              color: const Color(0xFF8B5CF6),
            ),
          ];

          if (isNarrow) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: kpis
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(right: 18),
                          child: item,
                        ))
                    .toList(),
              ),
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: kpis.map((item) => Expanded(child: item)).toList(),
          );
        },
      ),
    );
  }

  Widget _buildKpiItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = AppTheme.isDark(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary(context),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Filters & Search ───────────────────────────────────────────────────────
  Widget _buildFilterBar(BuildContext context, List<String> periods) {
    final isDark = AppTheme.isDark(context);
    final activeColor = isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488);

    return Container(
      // padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Search Input
          SizedBox(
            width: 260,
            height: 35,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary(context),
              ),
              decoration: InputDecoration(
                hintText: 'Search customer, period...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted(context),
                ),
                prefixIcon: Icon(
                  LucideIcons.search,
                  size: 15,
                  color: AppTheme.textSecondary(context),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.inputBg(context),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 7),
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
                  borderSide: BorderSide(color: activeColor, width: 1.5),
                ),
              ),
            ),
          ),

          // Right Controls: Period, Status, Sorting
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Period Dropdown
              Container(
                height: 35,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.inputBg(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorderColor(context)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedPeriod,
                    hint: Text(
                      'All Periods',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: AppTheme.textSecondary(context),
                    ),
                    dropdownColor: AppTheme.cardBg(context),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textPrimary(context),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'All Periods',
                          style: TextStyle(
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ),
                      ...periods.map((p) => DropdownMenuItem<String?>(
                            value: p,
                            child: Text(
                              p,
                              style: TextStyle(
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                          )),
                    ],
                    onChanged: (val) => setState(() => _selectedPeriod = val),
                  ),
                ),
              ),

              // Status Filter Toggle
              // Container(
              //   height: 38,
              //   padding: const EdgeInsets.all(3),
              //   decoration: BoxDecoration(
              //     color: AppTheme.inputBg(context),
              //     borderRadius: BorderRadius.circular(8),
              //     border: Border.all(color: AppTheme.cardBorderColor(context)),
              //   ),
              //   child: Row(
              //     mainAxisSize: MainAxisSize.min,
              //     children: [
              //       _filterChip(
              //         label: 'All',
              //         selected: _statusFilter == ProfitFilterStatus.all,
              //         onTap: () => setState(() => _statusFilter = ProfitFilterStatus.all),
              //       ),
              //       _filterChip(
              //         label: 'Profit',
              //         selected: _statusFilter == ProfitFilterStatus.profitable,
              //         onTap: () => setState(
              //             () => _statusFilter = ProfitFilterStatus.profitable),
              //         activeColor: const Color(0xFF10B981),
              //       ),
              //       _filterChip(
              //         label: 'Deficit',
              //         selected: _statusFilter == ProfitFilterStatus.deficit,
              //         onTap: () => setState(
              //             () => _statusFilter = ProfitFilterStatus.deficit),
              //         activeColor: const Color(0xFFEF4444),
              //       ),
              //     ],
              //   ),
              // ),

              // Sort Dropdown
              Container(
                height: 35,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.inputBg(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorderColor(context)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ProfitSortOption>(
                    value: _sortOption,
                    icon: Icon(
                      LucideIcons.arrowUpDown,
                      size: 14,
                      color: AppTheme.textSecondary(context),
                    ),
                    dropdownColor: AppTheme.cardBg(context),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary(context),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ProfitSortOption.newest,
                        child: Text('Newest First'),
                      ),
                      DropdownMenuItem(
                        value: ProfitSortOption.oldest,
                        child: Text('Oldest First'),
                      ),
                      DropdownMenuItem(
                        value: ProfitSortOption.highestProfit,
                        child: Text('Highest Profit'),
                      ),
                      DropdownMenuItem(
                        value: ProfitSortOption.lowestProfit,
                        child: Text('Lowest Profit'),
                      ),
                      DropdownMenuItem(
                        value: ProfitSortOption.highestMargin,
                        child: Text('Highest Margin %'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _sortOption = val);
                    },
                  ),
                ),
              ),

              // View mode toggle
              Container(
                height: 35,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.inputBg(context),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: AppTheme.cardBorderColor(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _viewChip(
                      label: 'Table',
                      icon: LucideIcons.table,
                      selected: _isTableView,
                      onTap: () => setState(() => _isTableView = true),
                    ),
                    _viewChip(
                      label: 'Cards',
                      icon: LucideIcons.layoutGrid,
                      selected: !_isTableView,
                      onTap: () => setState(() => _isTableView = false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    final isDark = AppTheme.isDark(context);
    final color = activeColor ??
        (isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: isDark ? 0.25 : 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? color : AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _viewChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDark(context);
    final color = isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: isDark ? 0.22 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? color : AppTheme.textSecondary(context)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Desktop Table View ─────────────────────────────────────────────────────
  Widget _buildTableView(
      BuildContext context, List<ProfitCalculation> calculations) {
    final isDark = AppTheme.isDark(context);
    final tealColor =
        isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488);

    final allVisibleSelected = calculations.isNotEmpty &&
        calculations.every((c) => _selectedCalcIds.contains(c.id));
    final someVisibleSelected =
        calculations.any((c) => _selectedCalcIds.contains(c.id));

    return Container(
      // margin: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = math.max(constraints.maxWidth, 1150.0);
            const horizontalMargin = 14.0;
            const columnSpacing = 14.0;
            const wCheck = 28.0;

            // 10 columns -> 9 column gaps (columnSpacing * 9) + 2 horizontal margins (horizontalMargin * 2) + wCheck
            final fixedOverhead =
                (horizontalMargin * 2) + (columnSpacing * 9) + wCheck;
            final contentWidth = math.max(0.0, availableWidth - fixedOverhead);

            // 9 flexible columns flex ratios (sum = 16.0):
            // 1. Customer & Branch: 3.0
            // 2. Period:            1.3
            // 3. Turnover:          1.7
            // 4. Purchases:         1.7
            // 5. Gross Profit:      1.7
            // 6. Margin %:          1.1
            // 7. Net VAT Due:       1.7
            // 8. Date & Creator:    1.6
            // 9. Actions:           2.2
            const totalFlex =
                3.0 + 1.3 + 1.7 + 1.7 + 1.7 + 1.1 + 1.7 + 1.6 + 2.2; // 16.0

            final wCustomer = contentWidth * (3.0 / totalFlex);
            final wPeriod = contentWidth * (1.3 / totalFlex);
            final wTurnover = contentWidth * (1.7 / totalFlex);
            final wPurchases = contentWidth * (1.7 / totalFlex);
            final wProfit = contentWidth * (1.7 / totalFlex);
            final wMargin = contentWidth * (1.1 / totalFlex);
            final wNetVat = contentWidth * (1.7 / totalFlex);
            final wDate = contentWidth * (1.6 / totalFlex);
            final wActions = contentWidth -
                (wCustomer +
                    wPeriod +
                    wTurnover +
                    wPurchases +
                    wProfit +
                    wMargin +
                    wNetVat +
                    wDate);

            return SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: availableWidth,
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowHeight: 40,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 58,
                    horizontalMargin: horizontalMargin,
                    columnSpacing: columnSpacing,
                    headingRowColor: WidgetStateProperty.all(
                      isDark
                          ? FuturisticColors.bgElevated.withValues(alpha: 0.5)
                          : const Color(0xFFF1F5F9),
                    ),
                    columns: [
                      DataColumn(
                        label: SizedBox(
                          width: wCheck,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: allVisibleSelected
                                    ? true
                                    : someVisibleSelected
                                        ? null
                                        : false,
                                tristate: true,
                                activeColor: tealColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) {
                                  if (allVisibleSelected) {
                                    setState(() {
                                      for (final c in calculations) {
                                        _selectedCalcIds.remove(c.id);
                                      }
                                    });
                                  } else {
                                    setState(() {
                                      for (final c in calculations) {
                                        _selectedCalcIds.add(c.id);
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      _headerCol('CUSTOMER & BRANCH', wCustomer),
                      _headerCol('PERIOD', wPeriod),
                      _headerCol('TURNOVER (EXCL. VAT)', wTurnover, numeric: true),
                      _headerCol('PURCHASES (EXCL. VAT)', wPurchases, numeric: true),
                      _headerCol('GROSS PROFIT', wProfit, numeric: true),
                      _headerCol('MARGIN %', wMargin, numeric: true),
                      _headerCol('NET VAT DUE', wNetVat, numeric: true),
                      _headerCol('DATE & CREATOR', wDate),
                      _headerCol('ACTIONS', wActions, align: TextAlign.right),
                    ],
                    rows: calculations.map((calc) {
                      final isProfitable = calc.grossProfit >= 0;
                      final isNetVatDue = calc.netVatDue >= 0;
                      final isExportingThis =
                          _isExportingId && _exportingCalcId == calc.id;
                      final isSelected = _selectedCalcIds.contains(calc.id);

                      return DataRow(
                        selected: isSelected,
                        onSelectChanged: (_) {
                          if (_isSelectionMode) {
                            _toggleSelection(calc.id);
                          } else {
                            _openDetails(calc);
                          }
                        },
                        cells: [
                          // Checkbox
                          DataCell(
                            SizedBox(
                              width: wCheck,
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: isSelected,
                                    activeColor: tealColor,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4)),
                                    onChanged: (_) => _toggleSelection(calc.id),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Customer & Branch (Flexible with Expanded)
                          DataCell(
                            SizedBox(
                              width: wCustomer,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: (isDark
                                            ? FuturisticColors.neonCyan
                                            : const Color(0xFF0D9488))
                                        .withValues(alpha: 0.15),
                                    child: Text(
                                      (calc.customerName?.isNotEmpty == true)
                                          ? calc.customerName![0].toUpperCase()
                                          : 'G',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? FuturisticColors.neonCyan
                                            : const Color(0xFF0D9488),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          calc.customerName ??
                                              'General / Standalone',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                AppTheme.textPrimary(context),
                                          ),
                                        ),
                                        if (calc.branchName != null &&
                                            calc.branchName!.isNotEmpty)
                                          Text(
                                            calc.branchName!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  AppTheme.textMuted(context),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Period
                          DataCell(
                            SizedBox(
                              width: wPeriod,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? FuturisticColors.bgElevated
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color:
                                            AppTheme.cardBorderColor(context)),
                                  ),
                                  child: Text(
                                    calc.periodName ?? 'Unspecified',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary(context),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Turnover (Excl. VAT)
                          DataCell(
                            SizedBox(
                              width: wTurnover,
                              child: Text(
                                _fmt.format(calc.salesWithoutTax),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ),
                          ),

                          // Purchases (Excl. VAT)
                          DataCell(
                            SizedBox(
                              width: wPurchases,
                              child: Text(
                                _fmt.format(calc.purchasesWithoutTax),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ),
                          ),

                          // Gross Profit
                          DataCell(
                            SizedBox(
                              width: wProfit,
                              child: Text(
                                _fmt.format(calc.grossProfit),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isProfitable
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ),

                          // Margin %
                          DataCell(
                            SizedBox(
                              width: wMargin,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isProfitable
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444))
                                        .withValues(
                                            alpha: isDark ? 0.2 : 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${calc.profitMargin.toStringAsFixed(1)}%',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isProfitable
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Net VAT Due
                          DataCell(
                            SizedBox(
                              width: wNetVat,
                              child: Text(
                                _fmt.format(calc.netVatDue),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isNetVatDue
                                      ? (isDark
                                          ? FuturisticColors.neonCyan
                                          : const Color(0xFF6366F1))
                                      : const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ),

                          // Date & Creator (Flexible with Expanded)
                          DataCell(
                            SizedBox(
                              width: wDate,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _dateFmt.format(calc.createdAt),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary(context),
                                    ),
                                  ),
                                  if (calc.createdByName.isNotEmpty)
                                    Text(
                                      'by ${calc.createdByName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textMuted(context),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // Actions (Flexible Right-Aligned)
                          DataCell(
                            SizedBox(
                              width: wActions,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // View Details
                                  IconButton(
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(
                                        minWidth: 30, minHeight: 30),
                                    splashRadius: 16,
                                    icon: const Icon(LucideIcons.eye,
                                        size: 16),
                                    tooltip: 'View Statement Details',
                                    color: AppTheme.textSecondary(context),
                                    onPressed: () => _openDetails(calc),
                                  ),

                                  // Edit
                                  IconButton(
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(
                                        minWidth: 30, minHeight: 30),
                                    splashRadius: 16,
                                    icon: const Icon(LucideIcons.pencil,
                                        size: 16),
                                    tooltip: 'Edit Calculation',
                                    color: isDark
                                        ? FuturisticColors.neonCyan
                                        : const Color(0xFF0D9488),
                                    onPressed: () => _openEdit(calc),
                                  ),

                                  // Export PDF
                                  IconButton(
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(
                                        minWidth: 30, minHeight: 30),
                                    splashRadius: 16,
                                    icon: isExportingThis
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.picture_as_pdf_rounded,
                                            size: 16),
                                    tooltip: 'Export PDF Statement',
                                    color: const Color(0xFFF59E0B),
                                    onPressed: isExportingThis
                                        ? null
                                        : () => _exportPdf(calc),
                                  ),

                                  // Delete
                                  IconButton(
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(
                                        minWidth: 30, minHeight: 30),
                                    splashRadius: 16,
                                    icon: const Icon(LucideIcons.trash2,
                                        size: 16),
                                    tooltip: 'Delete',
                                    color: const Color(0xFFEF4444),
                                    onPressed: () =>
                                        _confirmDelete(calc),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  DataColumn _headerCol(String title, double width,
      {bool numeric = false, TextAlign? align}) {
    return DataColumn(
      numeric: numeric,
      label: SizedBox(
        width: width,
        child: Text(
          title,
          textAlign: align ?? (numeric ? TextAlign.right : TextAlign.left),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }

  // ── Mobile Cards View ──────────────────────────────────────────────────────
  Widget _buildCardsView(
      BuildContext context, List<ProfitCalculation> calculations) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1150 ? 3 :constraints.maxWidth >= 900 ? 2 : 1;
        return GridView.builder(
          // padding: EdgeInsets.fromLTRB(14, 4, 14, _isSelectionMode ? 80 : 14),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 150,
          ),
          itemCount: calculations.length,
          itemBuilder: (ctx, index) {
            final calc = calculations[index];
            return _buildMobileCard(context, calc);
          },
        );
      },
    );
  }

  Widget _buildMobileCard(BuildContext context, ProfitCalculation calc) {
    final isDark = AppTheme.isDark(context);
    final tealColor =
        isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488);
    final isProfitable = calc.grossProfit >= 0;
    final isExportingThis = _isExportingId && _exportingCalcId == calc.id;
    final isSelected = _selectedCalcIds.contains(calc.id);

    return Container(
      // margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? tealColor.withValues(alpha: isDark ? 0.12 : 0.06)
            : AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? tealColor : AppTheme.cardBorderColor(context),
          width: isSelected ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? tealColor.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: isSelected ? 8 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(calc.id);
          } else {
            _openDetails(calc);
          }
        },
        onLongPress: () => _toggleSelection(calc.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Checkbox + Customer Name + Margin Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: Checkbox(
                      value: isSelected,
                      activeColor: tealColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (_) => _toggleSelection(calc.id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                calc.customerName ?? 'General / Standalone',
                                style: TextStyle(overflow: TextOverflow.ellipsis,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (calc.branchName != null &&
                            calc.branchName!.isNotEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  calc.branchName!,
                                  style: TextStyle(overflow: TextOverflow.ellipsis,
                                    fontSize: 11.5,
                                    color: AppTheme.textMuted(context),
                                  ),
                                ),
                              ),
                            ],
                          )
                          else
                          Text(
                            'Main Branch',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textMuted(context),
                            ),
                          )
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isProfitable
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444))
                          .withValues(alpha: isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Margin\n${calc.profitMargin.toStringAsFixed(1)}% ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isProfitable
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Divider(height: 1, color: AppTheme.cardBorderColor(context)),
              const SizedBox(height: 8),

              // Row 2: Metrics Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniMetric(
                    context,
                    label: 'Turnover',
                    value: _fmt.format(calc.salesWithoutTax),
                  ),
                  _miniMetric(
                    context,
                    label: 'Purchases',
                    value: _fmt.format(calc.purchasesWithoutTax),
                  ),
                  _miniMetric(
                    context,
                    label: 'Gross Profit',
                    value: _fmt.format(calc.grossProfit),
                    valueColor: isProfitable
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                  _miniMetric(
                    context,
                    label: 'Net VAT Due',
                    value: _fmt.format(calc.netVatDue),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Divider(height: 1, color: AppTheme.cardBorderColor(context)),
              const SizedBox(height: 8),

              // Row 3: Period, Date & Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendar,
                            size: 13, color: AppTheme.textMuted(context)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${calc.periodName ?? "No Period"} | ${_dateFmt.format(calc.createdAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.pencil, size: 15),
                        tooltip: 'Edit',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: isDark
                            ? FuturisticColors.neonCyan
                            : const Color(0xFF0D9488),
                        onPressed: () => _openEdit(calc),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: isExportingThis
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        tooltip: 'PDF',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: const Color(0xFFF59E0B),
                        onPressed: isExportingThis ? null : () => _exportPdf(calc),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(LucideIcons.trash2, size: 15),
                        tooltip: 'Delete',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: const Color(0xFFEF4444),
                        onPressed: () => _confirmDelete(calc),
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

  Widget _miniMetric(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textMuted(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppTheme.textPrimary(context),
          ),
        ),
      ],
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context, bool isLoading) {
    final isDark = AppTheme.isDark(context);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (isDark
                        ? FuturisticColors.neonCyan
                        : const Color(0xFF0D9488))
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.fileSpreadsheet,
                size: 40,
                color: isDark
                    ? FuturisticColors.neonCyan
                    : const Color(0xFF0D9488),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _selectedPeriod != null
                  ? 'No calculations match your filters'
                  : 'No saved profit calculations yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty || _selectedPeriod != null
                  ? 'Try adjusting your search criteria or resetting filters'
                  : 'Run profit calculations and save them to build your financial history',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted(context),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openCalculator,
              icon: const Icon(LucideIcons.plusCircle, size: 16),
              label: const Text('Open Profit Calculator'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? FuturisticColors.neonCyan
                    : const Color(0xFF0D9488),
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Floating Selection Bottom Bar ───────────────────────────────────────────
  Widget _buildSelectionBottomBar(
    BuildContext context,
    List<ProfitCalculation> allCalculations,
    List<ProfitCalculation> filtered,
  ) {
    final isDark = AppTheme.isDark(context);
    final tealColor =
        isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    final selectedCalculations = allCalculations
        .where((c) => _selectedCalcIds.contains(c.id))
        .toList();

    final totalProfit = selectedCalculations.fold<double>(
        0.0, (sum, c) => sum + c.grossProfit);
    final totalSales = selectedCalculations.fold<double>(
        0.0, (sum, c) => sum + c.salesWithoutTax);
    final combinedMargin =
        totalSales > 0 ? (totalProfit / totalSales) * 100 : 0.0;
    final isProfitable = totalProfit >= 0;

    final allFilteredSelected = filtered.isNotEmpty &&
        filtered.every((c) => _selectedCalcIds.contains(c.id));

    return SafeArea(
      child: Container(
        margin: EdgeInsets.fromLTRB(10, 0, 10, isMobile ? 8 : 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? FuturisticColors.bgElevated : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: tealColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: tealColor.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isMobile
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: tealColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(LucideIcons.checkSquare,
                            size: 16, color: tealColor),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedCalcIds.length} Selected',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          if (allFilteredSelected) {
                            setState(() {
                              for (final c in filtered) {
                                _selectedCalcIds.remove(c.id);
                              }
                            });
                          } else {
                            _selectAll(filtered);
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          allFilteredSelected ? 'Deselect All' : 'Select All',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tealColor,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _clearSelection,
                        icon: const Icon(LucideIcons.x, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Cancel',
                        color: AppTheme.textMuted(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Combined: ${_fmt.format(totalProfit)} (${combinedMargin.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isProfitable
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                      if (_selectedCalcIds.length > 1)
                        IconButton(
                          onPressed: () =>
                              _saveCombinedCalculation(allCalculations),
                          tooltip: 'Save combined calculation',
                          icon: const Icon(LucideIcons.save, size: 17),
                          color: tealColor,
                        ),
                      if (_selectedCalcIds.isNotEmpty)
                        IconButton(
                          onPressed: _isExportingCombined
                              ? null
                              : () => _exportSelectedCalculationsPdf(
                                    allCalculations,
                                  ),
                          tooltip: 'Export selected calculations as one PDF',
                          icon: _isExportingCombined
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf_rounded,
                                  size: 17),
                          color: const Color(0xFFF59E0B),
                        ),
                      if (_selectedCalcIds.isNotEmpty)
                        IconButton(
                          onPressed: _isExportingArabic
                              ? null
                              : () => _exportSelectedCalculationsArabicPdf(
                                    allCalculations,
                                  ),
                          tooltip: 'Export selected calculations in Arabic',
                          icon: _isExportingArabic
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.translate_rounded, size: 17),
                          color: const Color(0xFF0F766E),
                        ),
                      ElevatedButton.icon(
                        onPressed: () => _openCombinedDetails(allCalculations),
                        icon: Icon(
                          _selectedCalcIds.length > 1
                              ? LucideIcons.layers
                              : LucideIcons.arrowRight,
                          size: 15,
                        ),
                        label: Text(
                          _selectedCalcIds.length > 1
                              ? 'Combine'
                              : 'Details',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: tealColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(LucideIcons.checkSquare,
                        size: 18, color: tealColor),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_selectedCalcIds.length} calculation${_selectedCalcIds.length == 1 ? '' : 's'} selected',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      Text(
                        'Select multiple calculations to produce a consolidated statement',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  // Combined Profit preview pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10
                        , vertical: 5),
                    decoration: BoxDecoration(
                      color: (isProfitable
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444))
                          .withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Combined Profit: ',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                        Text(
                          '${_fmt.format(totalProfit)} (${combinedMargin.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isProfitable
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Select All / Deselect All
                  TextButton.icon(
                    onPressed: () {
                      if (allFilteredSelected) {
                        setState(() {
                          for (final c in filtered) {
                            _selectedCalcIds.remove(c.id);
                          }
                        });
                      } else {
                        _selectAll(filtered);
                      }
                    },
                    icon: Icon(
                      allFilteredSelected
                          ? LucideIcons.checkCheck
                          : LucideIcons.listChecks,
                      size: 15,
                    ),
                    label: Text(
                      allFilteredSelected
                          ? 'Deselect Visible'
                          : 'Select Visible (${filtered.length})',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: tealColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Cancel / Clear
                  TextButton.icon(
                    onPressed: _clearSelection,
                    icon: const Icon(LucideIcons.x, size: 15),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textMuted(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_selectedCalcIds.length > 1) ...[
                    OutlinedButton.icon(
                      onPressed: () =>
                          _saveCombinedCalculation(allCalculations),
                      icon: const Icon(LucideIcons.save, size: 15),
                      label: const Text('Save Combined'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tealColor,
                        side: BorderSide(color: tealColor),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: _isExportingCombined
                        ? null
                        : () => _exportSelectedCalculationsPdf(allCalculations),
                    icon: _isExportingCombined
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_rounded, size: 15),
                    label: const Text('Export PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isExportingArabic
                        ? null
                        : () => _exportSelectedCalculationsArabicPdf(
                              allCalculations,
                            ),
                    icon: _isExportingArabic
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.translate_rounded, size: 15),
                    label: const Text('عربي PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Combine CTA button
                  ElevatedButton.icon(
                    onPressed: () => _openCombinedDetails(allCalculations),
                    icon: Icon(
                      _selectedCalcIds.length > 1
                          ? LucideIcons.layers
                          : LucideIcons.eye,
                      size: 16,
                    ),
                    label: Text(
                      _selectedCalcIds.length > 1
                          ? 'View Combined Details (${_selectedCalcIds.length})'
                          : 'View Statement Details',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

