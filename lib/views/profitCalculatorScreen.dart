import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:entryon/models/customer_model.dart';
import 'package:entryon/providers/customer_provider.dart';
import 'package:entryon/providers/auth_Provider.dart';
import 'package:entryon/providers/profit_calculation_provider.dart';
import 'package:entryon/models/profit_calculation_model.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:entryon/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:entryon/utils/app_theme.dart';
import 'package:entryon/utils/pdf_actions.dart';
import 'package:entryon/utils/profit_calculator_pdf_generator.dart';
import 'package:entryon/views/profitCalculationsListScreen.dart';

// ── Design Tokens ──────────────────────────────────────────────────────────────
const Color _teal = Color(0xFF0D9488);
const Color _tealLight = Color(0xFFCCFBF1);
const Color _slate = Color(0xFF0F172A);
const Color _slateLight = Color(0xFF334155);
const Color _green = Color(0xFF10B981);
const Color _greenLight = Color(0xFFD1FAE5);
const Color _amber = Color(0xFFF59E0B);
const Color _amberLight = Color(0xFFFEF3C7);
const Color _red = Color(0xFFEF4444);
const Color _redLight = Color(0xFFFEE2E2);
const Color _indigo = Color(0xFF6366F1);
const Color _indigoLight = Color(0xFFE0E7FF);

enum OutputViewMode { table, cards }

class ProfitCalculatorScreen extends StatefulWidget {
  const ProfitCalculatorScreen({super.key});

  @override
  State<ProfitCalculatorScreen> createState() => _ProfitCalculatorScreenState();
}

class _ProfitCalculatorScreenState extends State<ProfitCalculatorScreen>
    with SingleTickerProviderStateMixin {
  final _taxCtrl = TextEditingController(text: '15');
  final _profitPctCtrl = TextEditingController();
  final _profitAmtCtrl = TextEditingController();
  final _salesCtrl = TextEditingController();
  final _purchasesCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  bool _includeVat = true;
  _CustomerOption? _selectedCustomer;
  String? _selectedPeriodId;
  List<Map<String, String>> _periods = [];
  bool _periodsLoading = true;
  late TabController _tabCtrl;
  final _fmt = NumberFormat('#,##0.00');
  OutputViewMode _outputViewMode = OutputViewMode.table;
  bool _isExportingPdf = false;
  ProfitCalculation? _selectedPreviousCalculation;
  List<ProfitCalculation> _selectedPreviousCalculations = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().fetchCustomers();
      context.read<ProfitCalculationProvider>().fetchCalculations();
      _fetchPeriods();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _taxCtrl.dispose();
    _profitPctCtrl.dispose();
    _profitAmtCtrl.dispose();
    _salesCtrl.dispose();
    _purchasesCtrl.dispose();
    _customerNameCtrl.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────
  Future<void> _fetchPeriods() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('period_sections')
          .orderBy('name')
          .get();
      if (!mounted) return;
      setState(() {
        _periods = snap.docs
            .map((d) => {
                  'id': d.id,
                  'name': (d.data()['name'] ?? 'Unnamed').toString(),
                  'startDate': _pDate(d.data()['startDate']),
                  'endDate': _pDate(d.data()['endDate']),
                })
            .toList();
        _periodsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _periodsLoading = false);
    }
  }

  String _pDate(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is DateTime) return v.toIso8601String();
    return v?.toString() ?? '';
  }

  String _pLabel(Map<String, String> p) {
    final start = DateTime.tryParse(p['startDate'] ?? '');
    final end = DateTime.tryParse(p['endDate'] ?? '');
    if (start != null && end != null) {
      final title = p['name']?.trim().isNotEmpty == true ? p['name']!.trim() : 'Unnamed';
      return '$title (${DateFormat('d/M/yy').format(start)} To ${DateFormat('d/M/yy').format(end)})';
    }
    return p['name'] ?? 'Unnamed';
  }

  String? get _periodLabel {
    for (final p in _periods) {
      if (p['id'] == _selectedPeriodId) return _pLabel(p);
    }
    return null;
  }

  void _loadPreviousCalculation(
    ProfitCalculation? calculation,
    List<_CustomerOption> customerOptions,
  ) {
    if (calculation == null) {
      setState(() {
        _selectedPreviousCalculation = null;
        _selectedPreviousCalculations = [];
      });
      return;
    }

    _CustomerOption? customer;
    for (final option in customerOptions) {
      if (option.customer.id == calculation.customerId &&
          option.branchName == calculation.branchName) {
        customer = option;
        break;
      }
    }

    final periodExists = _periods.any((p) => p['id'] == calculation.periodId);
    setState(() {
      _selectedPreviousCalculation = calculation;
      _selectedPreviousCalculations = [calculation];
      _selectedCustomer = customer;
      _customerNameCtrl.clear();
      _selectedPeriodId = periodExists ? calculation.periodId : null;
      _taxCtrl.text = calculation.taxPercent.toString();
      _includeVat = calculation.enteredValuesIncludeVat;
      _profitPctCtrl.text = calculation.targetProfitPercent == 0
          ? ''
          : calculation.targetProfitPercent.toString();
      _profitAmtCtrl.text = calculation.targetProfitAmount == 0
          ? ''
          : calculation.targetProfitAmount.toString();
      _salesCtrl.text = calculation.enteredSales == 0
          ? ''
          : calculation.enteredSales.toString();
      _purchasesCtrl.text = calculation.enteredPurchases == 0
          ? ''
          : calculation.enteredPurchases.toString();
    });
  }

  Future<void> _selectPreviousCalculations(
    List<ProfitCalculation> calculations,
    List<_CustomerOption> customerOptions,
  ) async {
    final selectedIds = <String>{
      ..._selectedPreviousCalculations.map((calculation) => calculation.id),
    };
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select previous calculations'),
          content: SizedBox(
            width: 520,
            child: calculations.isEmpty
                ? const Text('No saved calculations found.')
                : ListView(
                    shrinkWrap: true,
                    children: calculations.map((calculation) {
                      final selected = selectedIds.contains(calculation.id);
                      return CheckboxListTile(
                        value: selected,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          '${calculation.customerName ?? 'General'} • '
                          '${calculation.periodName ?? 'No period'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${DateFormat('d/M/yy').format(calculation.createdAt)} '
                          '• ${_fmt.format(calculation.grossProfit)} profit',
                        ),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selectedIds.add(calculation.id);
                            } else {
                              selectedIds.remove(calculation.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selectedIds),
              child: const Text('Load selected'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || result == null) return;
    final selected = calculations
        .where((calculation) => result.contains(calculation.id))
        .toList();
    if (selected.isEmpty) {
      _loadPreviousCalculation(null, customerOptions);
      return;
    }
    if (selected.length == 1) {
      _loadPreviousCalculation(selected.first, customerOptions);
      return;
    }

    final combined = ProfitCalculation.combine(selected);
    _loadPreviousCalculation(combined, customerOptions);
    setState(() {
      _selectedPreviousCalculation = null;
      _selectedPreviousCalculations = selected;
      _customerNameCtrl.text = combined.customerName ?? '';
    });
  }

  String? get _effectiveCustomerName {
    final enteredName = _customerNameCtrl.text.trim();
    if (enteredName.isNotEmpty) return enteredName;
    return _selectedCustomer?.displayName;
  }

  // ── Computed ─────────────────────────────────────────────────────────────────
  double _n(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0.0;

  double get taxPct => _n(_taxCtrl);
  double get taxRate => taxPct / 100;
  double get profitPct => _n(_profitPctCtrl);
  double get profitRate => (profitPct / 100).clamp(0.0, 0.9999);
  double get profitAmt => _n(_profitAmtCtrl);
  bool get hasProfitAmt => _profitAmtCtrl.text.trim().isNotEmpty && profitAmt > 0;
  bool get hasTarget => hasProfitAmt || profitPct > 0;

  double get rawSales => _n(_salesCtrl);
  double get rawPurchases => _n(_purchasesCtrl);
  bool get hasSales => _salesCtrl.text.trim().isNotEmpty && rawSales > 0;
  bool get hasPurchases => _purchasesCtrl.text.trim().isNotEmpty && rawPurchases > 0;

  double get salesExVat =>
      _includeVat ? (taxRate <= 0 ? rawSales : rawSales / (1 + taxRate)) : rawSales;
  double get purchasesExVat => _includeVat
      ? (taxRate <= 0 ? rawPurchases : rawPurchases / (1 + taxRate))
      : rawPurchases;

  double get salesExTax => hasSales
      ? salesExVat
      : hasPurchases && hasTarget
          ? reqSalesExTax
          : 0;
  double get salesInTax => salesExTax * (1 + taxRate);
  double get vatSales => salesInTax - salesExTax;

  double get purchasesExTax => hasPurchases
      ? purchasesExVat
      : hasSales && hasTarget
          ? allowPurchasesExTax
          : 0;
  double get purchasesInTax => purchasesExTax * (1 + taxRate);
  double get vatPurchases => purchasesInTax - purchasesExTax;

  double get grossProfit => salesExTax - purchasesExTax;
  double get netVat => vatSales - vatPurchases;
  double get margin => salesExTax == 0 ? 0 : (grossProfit / salesExTax) * 100;
  double get grossProfitInTax => salesInTax - purchasesInTax;

  double get reqSalesExTax {
    if (!hasPurchases) return 0;
    if (hasProfitAmt) return purchasesExVat + profitAmt;
    if (profitRate >= 1) return 0;
    return purchasesExVat / (1 - profitRate);
  }

  double get targetProfit {
    if (hasProfitAmt) return profitAmt;
    if (profitRate > 0) {
      return (hasPurchases && !hasSales)
          ? reqSalesExTax - purchasesExTax
          : salesExTax * profitRate;
    }
    return grossProfit;
  }

  double get reqSalesInTax => reqSalesExTax * (1 + taxRate);
  double get allowPurchasesExTax {
    if (!hasSales || !hasTarget) return 0;
    if (hasProfitAmt) return salesExTax - profitAmt;
    return salesExTax * (1 - profitRate);
  }

  double get allowPurchasesInTax => allowPurchasesExTax * (1 + taxRate);
  double get targetDiff => grossProfit - targetProfit;

  void _recalc() => setState(() {});

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final calc = ProfitCalculation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerId: _selectedCustomer?.customer.id,
      customerName: _effectiveCustomerName,
      branchName: _selectedCustomer?.branchName,
      periodId: _selectedPeriodId,
      periodName: _periodLabel,
      vatNumber: _selectedCustomer?.customer.taxNumber,
      taxPercent: taxPct,
      enteredValuesIncludeVat: _includeVat,
      targetProfitPercent: profitPct,
      targetProfitAmount: profitAmt,
      enteredSales: rawSales,
      enteredPurchases: rawPurchases,
      salesWithoutTax: salesExTax,
      salesWithTax: salesInTax,
      purchasesWithoutTax: purchasesExTax,
      purchasesWithTax: purchasesInTax,
      grossProfit: grossProfit,
      profitMargin: margin,
      netVatDue: netVat,
      targetProfit: targetProfit,
      createdAt: DateTime.now(),
      createdById: auth.currentUserId,
      createdByName: auth.currentUserName,
    );
    final ok = await context.read<ProfitCalculationProvider>().saveCalculation(calc);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(ok
            ? 'Calculation saved!'
            : context.read<ProfitCalculationProvider>().errorMessage ??
                'Unable to save'),
      ]),
      backgroundColor: ok ? _green : _red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _reset() => setState(() {
        _taxCtrl.text = '15';
        _profitPctCtrl.clear();
        _profitAmtCtrl.clear();
        _salesCtrl.clear();
        _purchasesCtrl.clear();
        _includeVat = true;
        _selectedCustomer = null;
        _customerNameCtrl.clear();
        _selectedPeriodId = null;
        _selectedPreviousCalculation = null;
        _selectedPreviousCalculations = [];
      });

  Future<void> _exportPdf() async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);
    try {
      final bytes = await ProfitCalculatorPdfGenerator.generate(
        customerName: _effectiveCustomerName,
        periodName: _periodLabel,
        vatNumber: _selectedCustomer?.customer.taxNumber,
        taxPct: taxPct,
        enteredValuesIncludeVat: _includeVat,
        salesExTax: salesExTax,
        vatSales: vatSales,
        salesInTax: salesInTax,
        purchasesExTax: purchasesExTax,
        vatPurchases: vatPurchases,
        purchasesInTax: purchasesInTax,
        grossProfit: grossProfit,
        grossProfitInTax: grossProfitInTax,
        netVat: netVat,
        margin: margin,
        hasTarget: hasTarget,
        targetProfit: targetProfit,
        targetDiff: targetDiff,
        hasSales: hasSales,
        hasPurchases: hasPurchases,
        reqSalesExTax: reqSalesExTax,
        allowPurchasesExTax: allowPurchasesExTax,
      );

      final periodSafe = (_periodLabel ?? 'summary')
          .replaceAll(RegExp(r'[\\/<>:"|?*\x00-\x1f\s]+'), '_');
      final fileName = 'profit_statement_$periodSafe.pdf';

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
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Desktop wide two-column layout when width >= 880
          if (width >= 880) {
            return _wideLayout(constraints);
          }
          // Responsive tabbed layout for tablet and mobile (< 880)
          return _mobileLayout(constraints);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Wide Layout (>= 880px) – Adaptive sidebar + main content
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _wideLayout(BoxConstraints constraints) {
    final sidebarWidth = constraints.maxWidth >= 1200 ? 330.0 : 295.0;

    return Column(
      children: [
        _AppHeader(
          onSave: _save,
          onReset: _reset,
          onExportPdf: _exportPdf,
          isExportingPdf: _isExportingPdf,
          selectedCustomer: _selectedCustomer,
          selectedPeriod: _periodLabel,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Input sidebar ──
                Container(
                  width: sidebarWidth,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorderColor(context)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        _buildContextCard(),
                        const SizedBox(height: 10),
                        _buildInputsCard(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // ── Results panel ──
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildKpiRow(),
                        const SizedBox(height: 10),
                        _buildOutputViewToggle(),
                        const SizedBox(height: 10),
                        _outputViewMode == OutputViewMode.table
                            ? _buildOutputTableView()
                            : _buildBreakdowns(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Responsive Mobile & Tablet Layout (< 880px) – Tabs: Inputs | Results
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _mobileLayout(BoxConstraints constraints) {
    final isDark = AppTheme.isDark(context);
    final isTabletWidth = constraints.maxWidth >= 660;

    return Column(
      children: [
        _AppHeader(
          onSave: _save,
          onReset: _reset,
          onExportPdf: _exportPdf,
          isExportingPdf: _isExportingPdf,
          selectedCustomer: _selectedCustomer,
          selectedPeriod: _periodLabel,
          compact: !isTabletWidth,
        ),
        // KPI strip (always visible on top)
        _buildKpiStrip(),
        // Tab bar
        Container(
          color: AppTheme.cardBg(context),
          child: TabBar(
            controller: _tabCtrl,
            labelColor: isDark ? FuturisticColors.neonCyan : _teal,
            unselectedLabelColor: AppTheme.textSecondary(context),
            indicatorColor: isDark ? FuturisticColors.neonCyan : _teal,
            indicatorWeight: 2.5,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Inputs & Context', icon: Icon(Icons.tune_rounded, size: 16)),
              Tab(
                  text: 'Statement & Results',
                  icon: Icon(Icons.bar_chart_rounded, size: 16)),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              // Tab 1: Inputs
              SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: isTabletWidth
                    ? Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildContextCard()),
                              const SizedBox(width: 10),
                              Expanded(child: _buildInputsCard()),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildQuickProfitBanner(),
                        ],
                      )
                    : Column(
                        children: [
                          _buildContextCard(),
                          const SizedBox(height: 10),
                          _buildInputsCard(),
                          const SizedBox(height: 10),
                          _buildQuickProfitBanner(),
                        ],
                      ),
              ),
              // Tab 2: Results
              SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    _buildOutputViewToggle(),
                    const SizedBox(height: 10),
                    _outputViewMode == OutputViewMode.table
                        ? _buildOutputTableView()
                        : _buildBreakdowns(),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Quick Profit Banner for Mobile / Tablet Inputs Tab ──────────────────────
  Widget _buildQuickProfitBanner() {
    final isDark = AppTheme.isDark(context);
    final isProfitable = grossProfit >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gross Operating Profit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmt.format(grossProfit),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isProfitable
                          ? (isDark ? FuturisticColors.neonTeal : _green)
                          : _red,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Commercial Margin',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${margin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isProfitable
                          ? (isDark ? FuturisticColors.neonTeal : _green)
                          : _red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _tabCtrl.animateTo(1),
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: const Text('View Full Financial Statement'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? FuturisticColors.neonCyan : _teal,
                side: BorderSide(
                  color: (isDark ? FuturisticColors.neonCyan : _teal)
                      .withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  KPI Row (Responsive: 4 columns or 2x2 grid)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildKpiRow() {
    final items = [
      _KpiData('Gross Profit', grossProfitInTax, _green, _greenLight,
          Icons.trending_up_rounded, isNeg: grossProfitInTax < 0),
      _KpiData('Net Profit', grossProfit, _teal, _tealLight,
          Icons.account_balance_wallet_outlined,
          isNeg: grossProfit < 0),
      _KpiData('Net VAT Due', netVat, _indigo, _indigoLight,
          Icons.receipt_long_rounded),
      _KpiData('Margin %', margin, _amber, _amberLight, Icons.donut_small_rounded,
          isPercent: true, isNeg: margin < 0),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _KpiCard(data: items[0], fmt: _fmt)),
                  const SizedBox(width: 8),
                  Expanded(child: _KpiCard(data: items[1], fmt: _fmt)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _KpiCard(data: items[2], fmt: _fmt)),
                  const SizedBox(width: 8),
                  Expanded(child: _KpiCard(data: items[3], fmt: _fmt)),
                ],
              ),
            ],
          );
        }

        return Row(
          children: items
              .map((d) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: items.indexOf(d) < items.length - 1 ? 8 : 0),
                      child: _KpiCard(data: d, fmt: _fmt),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  // KPI strip for mobile / tablet (horizontal scroll or distributed)
  Widget _buildKpiStrip() {
    final items = [
      _KpiData('Net Profit', grossProfit, _green, _greenLight, Icons.trending_up_rounded,
          isNeg: grossProfit < 0),
      _KpiData('Net VAT', netVat, _indigo, _indigoLight, Icons.receipt_long_rounded),
      _KpiData('Margin', margin, _amber, _amberLight, Icons.donut_small_rounded,
          isPercent: true),
      if (hasTarget)
        _KpiData('Target', targetProfit, _teal, _tealLight,
            Icons.flag_rounded),
    ];

    final isDark = AppTheme.isDark(context);
    return Container(
      color: isDark ? FuturisticColors.bgSurface : _slate,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 600) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.map((d) => _buildKpiStripItem(d)).toList(),
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items.map((d) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _buildKpiStripItem(d),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiStripItem(_KpiData d) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          d.label,
          style: const TextStyle(color: Colors.white60, fontSize: 10.5),
        ),
        const SizedBox(height: 2),
        Text(
          d.isPercent ? '${d.value.toStringAsFixed(1)}%' : _fmt.format(d.value),
          style: TextStyle(
            color: d.isNeg ? const Color(0xFFFCA5A5) : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Context Card (Customer + Period)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildContextCard() {
    final customers = context.watch<CustomerProvider>().customers;
    final previousCalculations =
        context.watch<ProfitCalculationProvider>().calculations;
    final opts = [
      for (final c in customers) ...[
        _CustomerOption(customer: c),
        ...c.branches
            .where((b) => b.name.trim().isNotEmpty)
            .map((b) => _CustomerOption(customer: c, branchName: b.name.trim())),
      ]
    ];

    return _Card(
      label: 'Calculation Context',
      icon: Icons.business_center_outlined,
      accent: _indigo,
      child: Column(children: [
        DropdownSearch<_CustomerOption>(
          items: (filter, _) => opts,
          selectedItem: _selectedCustomer,
          compareFn: (a, b) =>
              a.customer.id == b.customer.id && a.branchName == b.branchName,
          onChanged: (v) => setState(() {
            _selectedCustomer = v;
            _customerNameCtrl.clear();
          }),
          filterFn: (o, filter) {
            final q = filter.trim().toLowerCase();
            final c = o.customer;
            return c.name.toLowerCase().contains(q) ||
                (o.branchName?.toLowerCase().contains(q) ?? false) ||
                c.phone.toLowerCase().contains(q) ||
                c.taxNumber.toLowerCase().contains(q);
          },
          itemAsString: (o) => o.displayName,
          dropdownBuilder: (_, s) => s == null
              ? Text('',
                  style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13))
              : Text(s.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary(context))),
          decoratorProps: DropDownDecoratorProps(
              decoration: _deco('Customer',
                  hint: 'Search by name, phone, VAT...',
                  icon: Icons.person_search_outlined)),
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
                decoration:
                    _deco('Search', icon: Icons.search_rounded)),
            itemBuilder: (_, opt, disabled, selected) {
              final c = opt.customer;
              final isDark = AppTheme.isDark(context);
              return ListTile(
                dense: true,
                selected: selected,
                selectedTileColor: isDark ? FuturisticColors.bgCardHover : const Color(0xFFF0FDFA),
                leading: CircleAvatar(
                  radius: 10,
                  backgroundColor: _teal.withValues(alpha: isDark ? 0.25 : 0.1),
                  child: Text(
                    c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: isDark ? FuturisticColors.neonCyan : _teal,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
                title: Text(opt.isBranch ? opt.branchName! : c.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13.5, color: AppTheme.textPrimary(context))),
                subtitle: c.phone.isNotEmpty
                    ? Text(c.phone,
                        style: TextStyle(
                            fontSize: 11.5, color: AppTheme.textSecondary(context)))
                    : null,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        if (_selectedPreviousCalculations.length > 1) ...[
          TextFormField(
            controller: _customerNameCtrl,
            onChanged: (_) => setState(() {}),
            decoration: _deco(
              'Customer name',
              hint: 'Enter a name for the combined calculation',
              icon: Icons.edit_outlined,
            ),
          ),
          const SizedBox(height: 10),
        ],
        DropdownButtonFormField<ProfitCalculation>(
          initialValue: _selectedPreviousCalculation,
          isExpanded: true,
          decoration: _deco(
            'Previous calculation',
            hint: previousCalculations.isEmpty
                ? 'No saved calculations'
                : 'Select to restore saved values',
            icon: Icons.history_rounded,
          ),
          items: previousCalculations
              .map((calculation) => DropdownMenuItem<ProfitCalculation>(
                    value: calculation,
                    child: Text(
                      '${calculation.customerName ?? 'General'} • '
                      '${calculation.periodName ?? 'No period'} • '
                      '${DateFormat('d/M/yy').format(calculation.createdAt)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: previousCalculations.isEmpty
              ? null
              : (calculation) =>
                  _loadPreviousCalculation(calculation, opts),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: previousCalculations.isEmpty
                ? null
                : () => _selectPreviousCalculations(
                      previousCalculations,
                      opts,
                    ),
            icon: const Icon(Icons.playlist_add_check_rounded, size: 17),
            label: Text(
              _selectedPreviousCalculations.length > 1
                  ? '${_selectedPreviousCalculations.length} previous calculations selected'
                  : 'Select multiple previous calculations',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _selectedPeriodId,
          isExpanded: true,
          decoration: _deco('Period',
              hint: _periodsLoading ? 'Loading...' : 'Select period (optional)',
              icon: Icons.calendar_month_outlined),
          items: _periods
              .map((p) => DropdownMenuItem<String>(
                  value: p['id'], child: Text(_pLabel(p))))
              .toList(),
          onChanged: (v) => setState(() => _selectedPeriodId = v),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Inputs Card
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildInputsCard() {
    return _Card(
      label: 'Values & Targets',
      icon: Icons.tune_rounded,
      accent: _teal,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // VAT toggle
        _ToggleRow(
          value: _includeVat,
          onChanged: (v) => setState(() => _includeVat = v),
        ),
        const SizedBox(height: 14),
        _dividerLabel('Tax & Targets'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _Input(
                ctrl: _taxCtrl,
                label: 'VAT Rate (%)',
                hint: 'e.g. 15',
                icon: Icons.percent_rounded,
                onChanged: _recalc,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Input(
                ctrl: _profitPctCtrl,
                label: 'Target Profit % (optional)',
                hint: 'e.g. 20 — as % of sales',
                icon: Icons.trending_up_rounded,
                onChanged: _recalc,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _Input(
          ctrl: _profitAmtCtrl,
          label: 'Target Profit Amount (optional)',
          hint: 'e.g. 25,000 — ex-VAT, overrides %',
          icon: Icons.attach_money_rounded,
          onChanged: _recalc,
        ),
        const SizedBox(height: 10),
        _dividerLabel(_includeVat ? 'Amounts (incl. VAT)' : 'Amounts (excl. VAT)'),
        const SizedBox(height: 8),
        _Input(
          ctrl: _salesCtrl,
          label: _includeVat ? 'Total Sales (with VAT)' : 'Sales (excl. VAT)',
          hint: _includeVat ? 'e.g. 1,022,056.58' : 'e.g. 889,179.63',
          icon: Icons.point_of_sale_outlined,
          accentColor: _green,
          onChanged: _recalc,
        ),
        const SizedBox(height: 10),
        _Input(
          ctrl: _purchasesCtrl,
          label:
              _includeVat ? 'Total Purchases (with VAT)' : 'Purchases (excl. VAT)',
          hint: _includeVat ? 'e.g. 959,608.93' : 'e.g. 834,442.55',
          icon: Icons.shopping_cart_outlined,
          accentColor: _amber,
          onChanged: _recalc,
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Breakdowns
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildBreakdowns() {
    return LayoutBuilder(builder: (context, constraints) {
      final isTwoCol = constraints.maxWidth >= 640;

      final salesCard = _Card(
        label: 'Sales',
        icon: Icons.show_chart_rounded,
        accent: _green,
        child: Column(children: [
          _ResultRow(
              label: hasSales ? 'Entered Sales' : 'Calculated Sales',
              value: salesInTax,
              color: _green,
              isBig: true,
              fmt: _fmt),
          _Sep(),
          _ResultRow(
              label: 'Excl. VAT', value: salesExTax, fmt: _fmt),
          _Sep(),
          _ResultRow(
              label: 'Incl. VAT', value: salesInTax, fmt: _fmt),
          _Sep(),
          _ResultRow(
              label: 'VAT on Sales',
              value: vatSales,
              color: _amber,
              fmt: _fmt),
        ]),
      );

      final purchasesCard = _Card(
        label: 'Purchases',
        icon: Icons.shopping_bag_outlined,
        accent: _amber,
        child: Column(children: [
          _ResultRow(
              label: hasPurchases ? 'Entered Purchases' : 'Calculated Purchases',
              value: purchasesInTax,
              color: _amber,
              isBig: true,
              fmt: _fmt),
          _Sep(),
          _ResultRow(
              label: 'Excl. VAT', value: purchasesExTax, fmt: _fmt),
          _Sep(),
          _ResultRow(
              label: 'Incl. VAT', value: purchasesInTax, fmt: _fmt),
          _Sep(),
          _ResultRow(
              label: 'VAT on Purchases',
              value: vatPurchases,
              color: _amber,
              fmt: _fmt),
        ]),
      );

      final resultsCard = _Card(
        label: 'Final Results',
        icon: Icons.auto_awesome_rounded,
        accent: _teal,
        child: Column(children: [
          Row(
            children: [
              Expanded(
                child: _BigResultBox(
                  label: 'Gross Profit',
                  label2: '(incl. VAT)',
                  value: grossProfitInTax,
                  color: grossProfitInTax >= 0 ? _green : _red,
                  lightColor: grossProfitInTax >= 0 ? _greenLight : _redLight,
                  fmt: _fmt,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BigResultBox(
                  label: 'Gross Profit',
                  label2: '(excl. VAT)',
                  value: grossProfit,
                  color: grossProfit >= 0 ? _teal : _red,
                  lightColor: grossProfit >= 0 ? _tealLight : _redLight,
                  fmt: _fmt,
                ),
              ),
            ],
          ),
          // const SizedBox(height: 10),
          _Sep(),
          _ResultRow(
              label: 'Profit Margin',
              value: margin,
              color: margin >= 0 ? _green : _red,
              isPercent: true,
              isBold: true,
              fmt: _fmt),
          _Sep(),
          _ResultRow(
              label: 'Net VAT Due',
              value: netVat,
              color: netVat >= 0 ? _indigo : _amber,
              isBold: true,
              fmt: _fmt),
          // ── Target helpers ──
          if (hasTarget && hasPurchases && !hasSales) ...[
            _Sep(),
            _ResultRow(
                label: 'Target Profit',
                value: targetProfit,
                color: _green,
                isBold: true,
                fmt: _fmt),
            _Sep(),
            _ResultRow(
                label: 'Required Sales (excl. VAT)',
                value: reqSalesExTax,
                color: _teal,
                isBold: true,
                fmt: _fmt),
            _Sep(),
            _ResultRow(
                label: 'Required Sales (incl. VAT)',
                value: reqSalesInTax,
                color: _teal,
                isBold: true,
                fmt: _fmt),
          ],
          if (hasTarget && hasSales && !hasPurchases) ...[
            _Sep(),
            _ResultRow(
                label: 'Target Profit',
                value: targetProfit,
                color: _green,
                isBold: true,
                fmt: _fmt),
            _Sep(),
            _ResultRow(
                label: 'Allowable Purchases (excl. VAT)',
                value: allowPurchasesExTax,
                color: _teal,
                isBold: true,
                fmt: _fmt),
            _Sep(),
            _ResultRow(
                label: 'Allowable Purchases (incl. VAT)',
                value: allowPurchasesInTax,
                color: _teal,
                isBold: true,
                fmt: _fmt),
          ],
          if (hasTarget && hasSales && hasPurchases) ...[
            _Sep(),
            _ResultRow(
                label: 'Target Profit',
                value: targetProfit,
                color: _green,
                isBold: true,
                fmt: _fmt),
            _Sep(),
            _ResultRow(
                label: 'Actual vs Target',
                value: targetDiff,
                color: targetDiff >= 0 ? _green : _red,
                isBold: true,
                fmt: _fmt),
          ],
        ]),
      );

      return Column(
        children: [
          if (isTwoCol)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: salesCard),
                const SizedBox(width: 10),
                Expanded(child: purchasesCard),
              ],
            )
          else ...[
            salesCard,
            const SizedBox(height: 10),
            purchasesCard,
          ],
          const SizedBox(height: 10),
          resultsCard,
        ],
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Output View Toggle & Table View UI
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildOutputViewToggle() {
    final isDark = AppTheme.isDark(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _outputViewMode == OutputViewMode.table
                  ? Icons.table_chart_rounded
                  : Icons.dashboard_outlined,
              size: 16,
              color: isDark ? FuturisticColors.neonCyan : _teal,
            ),
            const SizedBox(width: 6),
            Text(
              _outputViewMode == OutputViewMode.table
                  ? 'Financial Statement Table'
                  : 'Cards Breakdown View',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppTheme.cardBorderColor(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toggleOption(
                mode: OutputViewMode.table,
                label: 'Table View',
                icon: Icons.table_chart_rounded,
              ),
              const SizedBox(width: 4),
              _toggleOption(
                mode: OutputViewMode.cards,
                label: 'Cards View',
                icon: Icons.dashboard_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toggleOption({
    required OutputViewMode mode,
    required String label,
    required IconData icon,
  }) {
    final isDark = AppTheme.isDark(context);
    final isSelected = _outputViewMode == mode;
    final activeColor = isDark ? FuturisticColors.neonCyan : _teal;

    return InkWell(
      onTap: () => setState(() => _outputViewMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? activeColor.withValues(alpha: 0.18) : _tealLight)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(
                  color: isDark ? activeColor : _teal.withValues(alpha: 0.5),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? activeColor : AppTheme.textSecondary(context),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputTableView() {
    final isDark = AppTheme.isDark(context);
    final isProfitable = grossProfit >= 0;
    final costRatio = salesExTax > 0 ? (purchasesExTax / salesExTax) * 100 : 0.0;
    final isNetVatPayable = netVat >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Main Financial Statement Table Container ──
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.cardBorderColor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Table Card Header ──
                LayoutBuilder(builder: (context, headerConstraints) {
                  final isCompact = headerConstraints.maxWidth < 560;
                  final isVeryCompact = headerConstraints.maxWidth < 420;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? FuturisticColors.bgSurface : const Color(0xFFF8FAFC),
                      border: Border(
                        bottom: BorderSide(color: AppTheme.cardBorderColor(context)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (isDark ? FuturisticColors.neonCyan : _teal)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                            color: isDark ? FuturisticColors.neonCyan : _teal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Financial Statement & Tax Reconciliation',
                                style: TextStyle(
                                  fontSize: isCompact ? 13 : 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              if (!isVeryCompact)
                                Text(
                                  'Full breakdown of turnover, direct purchases, margins, and VAT liability',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.textMuted(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isCompact)
                          Tooltip(
                            message: 'Export Profit & Loss Statement as PDF',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: _isExportingPdf ? null : _exportPdf,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: (isDark ? FuturisticColors.neonCyan : _teal)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: (isDark ? FuturisticColors.neonCyan : _teal)
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: _isExportingPdf
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: isDark ? FuturisticColors.neonCyan : _teal,
                                        ),
                                      )
                                    : Icon(
                                        Icons.picture_as_pdf_rounded,
                                        size: 16,
                                        color: isDark ? FuturisticColors.neonCyan : _teal,
                                      ),
                              ),
                            ),
                          )
                        else
                          Tooltip(
                            message: 'Export Profit & Loss Statement as PDF',
                            child: ElevatedButton.icon(
                              onPressed: _isExportingPdf ? null : _exportPdf,
                              icon: _isExportingPdf
                                  ? SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: isDark ? FuturisticColors.neonCyan : _teal,
                                      ),
                                    )
                                  : const Icon(Icons.picture_as_pdf_rounded, size: 15),
                              label: Text(
                                _isExportingPdf ? 'Generating...' : 'Export PDF',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? FuturisticColors.neonCyan.withValues(alpha: 0.15)
                                    : _teal.withValues(alpha: 0.1),
                                foregroundColor: isDark ? FuturisticColors.neonCyan : _teal,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: (isDark ? FuturisticColors.neonCyan : _teal)
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Copy statement summary',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _copyStatementSummary,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? FuturisticColors.bgElevated
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.cardBorderColor(context),
                                ),
                              ),
                              child: Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                            // ── Responsive Flexible Horizontal Table ──
                LayoutBuilder(
                  builder: (context, tableConstraints) {
                    final availableWidth =
                        math.max(tableConstraints.maxWidth, 540.0);
                    const horizontalMargin = 12.0;
                    const columnSpacing = 14.0;
                    final contentWidth = availableWidth -
                        (horizontalMargin * 2) -
                        (columnSpacing * 4);

                    // 5 Columns proportional flex allocation:
                    // 1. Line Item: 3.0 (icon + title + subtitle)
                    // 2. Excl. VAT: 1.8 (numerical)
                    // 3. VAT: 1.6 (numerical)
                    // 4. Incl. VAT: 1.8 (numerical)
                    // 5. Type: 1.2 (badge)
                    const totalFlex = 3.0 + 1.8 + 1.6 + 1.8 + 1.2; // 9.4
                    final w1 = contentWidth * (3.0 / totalFlex);
                    final w2 = contentWidth * (1.8 / totalFlex);
                    final w3 = contentWidth * (1.6 / totalFlex);
                    final w4 = contentWidth * (1.8 / totalFlex);
                    final w5 = contentWidth - (w1 + w2 + w3 + w4);

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: availableWidth,
                        child: DataTable(
                          headingRowHeight: 38,
                          dataRowMinHeight: 46,
                          dataRowMaxHeight: 54,
                          horizontalMargin: horizontalMargin,
                          columnSpacing: columnSpacing,
                          dividerThickness: 1,
                          headingRowColor: WidgetStateProperty.all(
                            isDark
                                ? FuturisticColors.bgElevated.withValues(alpha: 0.5)
                                : const Color(0xFFF1F5F9),
                          ),
                          columns: [
                            DataColumn(
                              label: SizedBox(
                                width: w1,
                                child: Text(
                                  'LINE ITEM',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                    color: AppTheme.textSecondary(context),
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              numeric: true,
                              label: SizedBox(
                                width: w2,
                                child: Text(
                                  'EXCL. VAT',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                    color: AppTheme.textSecondary(context),
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              numeric: true,
                              label: SizedBox(
                                width: w3,
                                child: Text(
                                  'VAT (${taxPct.toStringAsFixed(0)}%)',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                    color: AppTheme.textSecondary(context),
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              numeric: true,
                              label: SizedBox(
                                width: w4,
                                child: Text(
                                  'INCL. VAT',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                    color: AppTheme.textSecondary(context),
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: SizedBox(
                                width: w5,
                                child: Text(
                                  'TYPE',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                    color: AppTheme.textSecondary(context),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          rows: [
                            // Row 1: Sales / Revenue
                            _buildDataRow(
                              context: context,
                              w1: w1,
                              w2: w2,
                              w3: w3,
                              w4: w4,
                              w5: w5,
                              icon: Icons.trending_up_rounded,
                              iconColor:
                                  isDark ? FuturisticColors.neonTeal : _green,
                              title: hasSales
                                  ? 'Sales Turnover'
                                  : 'Calculated Sales',
                              subtitle: hasSales
                                  ? 'Gross recognized revenue'
                                  : 'Derived from target',
                              exclVat: salesExTax,
                              vat: vatSales,
                              inclVat: salesInTax,
                              ratioText: '100.0%',
                              badgeText: 'REVENUE',
                              badgeColor:
                                  isDark ? FuturisticColors.neonTeal : _green,
                            ),
                            // Row 2: Purchases / Cost
                            _buildDataRow(
                              context: context,
                              w1: w1,
                              w2: w2,
                              w3: w3,
                              w4: w4,
                              w5: w5,
                              icon: Icons.shopping_bag_outlined,
                              iconColor:
                                  isDark ? FuturisticColors.neonAmber : _amber,
                              title: hasPurchases
                                  ? 'Purchases / COGS'
                                  : 'Allowable Purchases',
                              subtitle: hasPurchases
                                  ? 'Direct cost of supplies'
                                  : 'Derived from target',
                              exclVat: purchasesExTax,
                              vat: vatPurchases,
                              inclVat: purchasesInTax,
                              ratioText: '${costRatio.toStringAsFixed(1)}%',
                              badgeText: 'EXPENSE',
                              badgeColor:
                                  isDark ? FuturisticColors.neonAmber : _amber,
                            ),
                            // Row 3: Gross Profit (Highlighted)
                            _buildDataRow(
                              context: context,
                              w1: w1,
                              w2: w2,
                              w3: w3,
                              w4: w4,
                              w5: w5,
                              icon: isProfitable
                                  ? Icons.verified_rounded
                                  : Icons.warning_amber_rounded,
                              iconColor: isProfitable
                                  ? (isDark ? FuturisticColors.neonCyan : _teal)
                                  : _red,
                              title: 'Gross Commercial Profit',
                              subtitle: isProfitable
                                  ? 'Net operating margin'
                                  : 'Deficit on transactions',
                              exclVat: grossProfit,
                              vat: netVat,
                              inclVat: grossProfitInTax,
                              ratioText: '${margin.toStringAsFixed(1)}%',
                              badgeText: isProfitable ? 'PROFIT' : 'DEFICIT',
                              badgeColor: isProfitable
                                  ? (isDark ? FuturisticColors.neonCyan : _teal)
                                  : _red,
                              isHighlight: true,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // ── VAT Summary Strip Inside Card ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FuturisticColors.bgSurface.withValues(alpha: 0.7)
                        : const Color(0xFFF8FAFC),
                    border: Border(
                      top: BorderSide(color: AppTheme.cardBorderColor(context)),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildTaxPill(
                        context,
                        label: 'Output VAT (Sales)',
                        amount: vatSales,
                        color: isDark ? FuturisticColors.neonTeal : _green,
                      ),
                      _buildTaxPill(
                        context,
                        label: 'Input VAT (Purchases)',
                        amount: vatPurchases,
                        color: isDark ? FuturisticColors.neonAmber : _amber,
                      ),
                      _buildTaxPill(
                        context,
                        label: isNetVatPayable ? 'Net VAT Due to ZATCA' : 'Net VAT Refundable',
                        amount: netVat.abs(),
                        color: isNetVatPayable
                            ? (isDark ? FuturisticColors.neonCyan : _indigo)
                            : _green,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ── Additional Target Comparison Table (if target exists) ──
        if (hasTarget) _buildTargetComparisonCard(),
      ],
    );
  }

  DataRow _buildDataRow({
    required BuildContext context,
    required double w1,
    required double w2,
    required double w3,
    required double w4,
    required double w5,
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
          ? WidgetStateProperty.all(
              badgeColor.withValues(alpha: isDark ? 0.12 : 0.08),
            )
          : null,
      cells: [
        // 1. Line Item Name & Icon (Flexible with Expanded)
        DataCell(
          SizedBox(
            width: w1,
            child: Row(
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
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isHighlight ? FontWeight.w800 : FontWeight.w700,
                          color: isHighlight
                              ? badgeColor
                              : AppTheme.textPrimary(context),
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // 2. Excl. VAT (Flexible)
        DataCell(
          SizedBox(
            width: w2,
            child: Text(
              _fmt.format(exclVat),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                color: isHighlight ? badgeColor : AppTheme.textPrimary(context),
              ),
            ),
          ),
        ),
        // 3. VAT (Flexible)
        DataCell(
          SizedBox(
            width: w3,
            child: Text(
              _fmt.format(vat),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isHighlight
                    ? badgeColor
                    : (isDark ? FuturisticColors.neonAmber : _amber),
              ),
            ),
          ),
        ),
        // 4. Incl. VAT (Flexible)
        DataCell(
          SizedBox(
            width: w4,
            child: Text(
              _fmt.format(inclVat),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                color: isHighlight ? badgeColor : AppTheme.textPrimary(context),
              ),
            ),
          ),
        ),
        // 5. Type Badge (Flexible)
        DataCell(
          SizedBox(
            width: w5,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badgeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: badgeColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaxPill(
    BuildContext context, {
    required String label,
    required double amount,
    required Color color,
    bool isBold = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary(context),
          ),
        ),
        Text(
          _fmt.format(amount),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTargetComparisonCard() {
    final isDark = AppTheme.isDark(context);
    final targetMet = targetDiff >= 0;
    final statusColor = targetMet ? (isDark ? FuturisticColors.neonTeal : _green) : _red;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? FuturisticColors.bgSurface : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: AppTheme.cardBorderColor(context)),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.track_changes_rounded,
                        size: 18,
                        color: isDark ? FuturisticColors.neonAmber : _amber,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Target vs. Actual Performance Table',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      targetMet ? 'TARGET ACHIEVED' : 'TARGET SHORTFALL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            LayoutBuilder(
              builder: (context, tableConstraints) {
                final availableWidth =
                    math.max(tableConstraints.maxWidth, 480.0);
                const horizontalMargin = 12.0;
                const columnSpacing = 14.0;
                final contentWidth = availableWidth -
                    (horizontalMargin * 2) -
                    (columnSpacing * 4);

                // 5 Columns:
                // 1. TARGET METRIC: flex 2.8
                // 2. TARGET GOAL: flex 1.8
                // 3. ACTUAL RESULT: flex 1.8
                // 4. VARIANCE: flex 1.8
                // 5. STATUS: flex 1.0
                const totalFlex = 2.8 + 1.8 + 1.8 + 1.8 + 1.0; // 9.2
                final tw1 = contentWidth * (2.8 / totalFlex);
                final tw2 = contentWidth * (1.8 / totalFlex);
                final tw3 = contentWidth * (1.8 / totalFlex);
                final tw4 = contentWidth * (1.8 / totalFlex);
                final tw5 = contentWidth - (tw1 + tw2 + tw3 + tw4);

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: availableWidth,
                    child: DataTable(
                      headingRowHeight: 36,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 46,
                      horizontalMargin: horizontalMargin,
                      columnSpacing: columnSpacing,
                      headingRowColor: WidgetStateProperty.all(
                        isDark
                            ? FuturisticColors.bgElevated.withValues(alpha: 0.4)
                            : const Color(0xFFF1F5F9),
                      ),
                      columns: [
                        DataColumn(
                          label: SizedBox(
                            width: tw1,
                            child: Text(
                              'TARGET METRIC',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          numeric: true,
                          label: SizedBox(
                            width: tw2,
                            child: Text(
                              'TARGET GOAL',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          numeric: true,
                          label: SizedBox(
                            width: tw3,
                            child: Text(
                              'ACTUAL RESULT',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          numeric: true,
                          label: SizedBox(
                            width: tw4,
                            child: Text(
                              'VARIANCE',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: tw5,
                            child: Text(
                              'STATUS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                      rows: [
                        DataRow(cells: [
                          DataCell(SizedBox(
                            width: tw1,
                            child: Text(
                              'Profit Target',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                          )),
                          DataCell(SizedBox(
                            width: tw2,
                            child: Text(
                              _fmt.format(targetProfit),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                          )),
                          DataCell(SizedBox(
                            width: tw3,
                            child: Text(
                              _fmt.format(grossProfit),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          )),
                          DataCell(SizedBox(
                            width: tw4,
                            child: Text(
                              '${targetDiff >= 0 ? '+' : ''}${_fmt.format(targetDiff)}',
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          )),
                          DataCell(SizedBox(
                            width: tw5,
                            child: Center(
                              child: Icon(
                                targetMet
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                size: 16,
                                color: statusColor,
                              ),
                            ),
                          )),
                        ]),
                        if (hasPurchases && !hasSales)
                          DataRow(cells: [
                            DataCell(SizedBox(
                              width: tw1,
                              child: Text(
                                'Required Sales (excl. VAT)',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: tw2,
                              child: Text(
                                _fmt.format(reqSalesExTax),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? FuturisticColors.neonCyan
                                      : _teal,
                                ),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: tw3,
                              child: Text(
                                '0.00',
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textMuted(context),
                                ),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: tw4,
                              child: Text(
                                '-${_fmt.format(reqSalesExTax)}',
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: _red,
                                ),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: tw5,
                              child: const Center(
                                child: Icon(
                                  Icons.hourglass_empty_rounded,
                                  size: 16,
                                  color: _amber,
                                ),
                              ),
                            )),
                          ]),
                        if (hasSales && !hasPurchases)
                          DataRow(cells: [
                            DataCell(SizedBox(
                              width: tw1,
                              child: Text(
                                'Max Allowable Purchases',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: tw2,
                              child: Text(
                                _fmt.format(allowPurchasesExTax),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? FuturisticColors.neonCyan
                                      : _teal,
                                ),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: tw3,
                              child: Text(
                                '0.00',
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textMuted(context),
                                ),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: tw4,
                              child: Text(
                                '+${_fmt.format(allowPurchasesExTax)}',
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: statusColor,
                                ),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: tw5,
                              child: const Center(
                                child: Icon(
                                  Icons.hourglass_empty_rounded,
                                  size: 16,
                                  color: _amber,
                                ),
                              ),
                            )),
                          ]),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _copyStatementSummary() {
    final text = '''
--- PROFIT & TAX STATEMENT ---
Period: ${_periodLabel ?? 'N/A'}
  Customer: ${_effectiveCustomerName ?? 'General'}
VAT Rate: ${taxPct.toStringAsFixed(0)}%

1. Sales:
   - Excl. VAT: ${_fmt.format(salesExTax)}
   - VAT: ${_fmt.format(vatSales)}
   - Incl. VAT: ${_fmt.format(salesInTax)}

2. Purchases:
   - Excl. VAT: ${_fmt.format(purchasesExTax)}
   - VAT: ${_fmt.format(vatPurchases)}
   - Incl. VAT: ${_fmt.format(purchasesInTax)}

3. Profit & Tax:
   - Gross Profit (Excl. VAT): ${_fmt.format(grossProfit)}
   - Gross Profit (Incl. VAT): ${_fmt.format(grossProfitInTax)}
   - Profit Margin: ${margin.toStringAsFixed(2)}%
   - Net VAT Due: ${_fmt.format(netVat)}
${hasTarget ? '\n4. Target Variance: ${_fmt.format(targetDiff)}' : ''}
''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Financial statement copied to clipboard!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  InputDecoration _deco(String label, {String? hint, IconData? icon}) {
    final isDark = AppTheme.isDark(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 12.5),
      prefixIcon:
          icon != null ? Icon(icon, size: 18, color: AppTheme.textSecondary(context)) : null,
      filled: true,
      fillColor: AppTheme.inputBg(context),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.cardBorderColor(context))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.cardBorderColor(context))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? FuturisticColors.neonCyan : _teal, width: 1.8)),
    );
  }

  Widget _dividerLabel(String label) => Row(children: [
        Expanded(child: Divider(color: AppTheme.divider(context))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary(context),
                  letterSpacing: 0.4)),
        ),
        Expanded(child: Divider(color: AppTheme.divider(context))),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
//  App Header
// ─────────────────────────────────────────────────────────────────────────────
class _AppHeader extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onReset;
  final VoidCallback? onExportPdf;
  final bool isExportingPdf;
  final _CustomerOption? selectedCustomer;
  final String? selectedPeriod;
  final bool compact;

  const _AppHeader({
    required this.onSave,
    required this.onReset,
    this.onExportPdf,
    this.isExportingPdf = false,
    this.selectedCustomer,
    this.selectedPeriod,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = compact || constraints.maxWidth < 620;
      final isVeryNarrow = constraints.maxWidth < 420;

      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [FuturisticColors.bgSurface, FuturisticColors.bgElevated]
                : [const Color(0xFF0D9488), const Color(0xFF0891B2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: isDark ? Border(bottom: BorderSide(color: AppTheme.cardBorderColor(context))) : null,
        ),
        padding: EdgeInsets.fromLTRB(
            10, MediaQuery.of(context).padding.top + 10, 10, 10),
        child: Row(
          children: [
            // Back arrow if applicable
            if (Navigator.of(context).canPop())
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            if (Navigator.of(context).canPop()) const SizedBox(width: 8),
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profit Calculator',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: isVeryNarrow ? 15 : 17,
                          fontWeight: FontWeight.w800)),
                  if (!isVeryNarrow)
                    if (!isNarrow &&
                        (selectedCustomer != null || selectedPeriod != null))
                      Text(
                        [
                          if (selectedCustomer != null) selectedCustomer!.displayName,
                          if (selectedPeriod != null) selectedPeriod!,
                        ].join(' | '),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      const Text('Real-time VAT & profit analysis',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 11.5)),
                ],
              ),
            ),
            // Reset
            Tooltip(
              message: 'Reset all',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onReset,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Saved Calculations
            Tooltip(
              message: 'View Saved Calculations',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 1100,
      maxHeight: 700,
      child: const ProfitCalculationsListScreen(),
    );
                  // Navigator.of(context).push(
                  //   MaterialPageRoute(
                  //     builder: (_) => const ProfitCalculationsListScreen(),
                  //   ),
                  // );
                },
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.format_list_bulleted_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Export PDF
            if (isNarrow)
              Tooltip(
                message: 'Export Statement as PDF',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: isExportingPdf ? null : onExportPdf,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isExportingPdf
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              )
            else
              Tooltip(
                message: 'Export Statement as PDF (Print & Download)',
                child: ElevatedButton.icon(
                  onPressed: isExportingPdf ? null : onExportPdf,
                  icon: isExportingPdf
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('Export PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 6),
            // Save
            Consumer<ProfitCalculationProvider>(
              builder: (_, prov, __) => ElevatedButton.icon(
                onPressed: prov.isSaving ? null : onSave,
                icon: prov.isSaving
                    ? SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: isDark ? FuturisticColors.bgVoid : _teal))
                    : const Icon(Icons.save_outlined, size: 15),
                label: isVeryNarrow ? const SizedBox.shrink() : const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? FuturisticColors.neonCyan : Colors.white,
                  foregroundColor: isDark ? FuturisticColors.bgVoid : _teal,
                  elevation: 0,
                  padding:
                      EdgeInsets.symmetric(horizontal: isVeryNarrow ? 8 : 10, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  KPI Card
// ─────────────────────────────────────────────────────────────────────────────
class _KpiData {
  final String label;
  final double value;
  final Color color;
  final Color lightColor;
  final IconData icon;
  final bool isPercent;
  final bool isNeg;
  const _KpiData(this.label, this.value, this.color, this.lightColor, this.icon,
      {this.isPercent = false, this.isNeg = false});
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  final NumberFormat fmt;
  const _KpiCard({required this.data, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final c = data.isNeg ? _red : data.color;
    final lc = isDark
        ? c.withValues(alpha: 0.18)
        : (data.isNeg ? _redLight : data.lightColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
      ),
      child: Row(
        children: [
          Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                    color: lc, borderRadius: BorderRadius.circular(8)),
                child: Icon(data.icon, color: c, size: 17),
              ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
             
          
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  data.isPercent
                      ? '${data.value.toStringAsFixed(1)}%'
                      : fmt.format(data.value),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c,
                  ),
                ),
              ),
              // const SizedBox(height: 2),
              Text(data.label,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section Card Wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final Widget child;

  const _Card({
    required this.label,
    required this.icon,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.15 : 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: accent.withValues(alpha: isDark ? 0.25 : 0.15))),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: accent, size: 15),
                ),
                const SizedBox(width: 10),
                Text(label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: accent)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  VAT Toggle Row
// ─────────────────────────────────────────────────────────────────────────────
class _ToggleRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: isDark ? FuturisticColors.bgSurface : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(11)),
      child: Row(
        children: [
          _tab(context, 'Incl. VAT', Icons.receipt_long_outlined, true),
          _tab(context, 'Excl. VAT', Icons.receipt_outlined, false),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, String label, IconData icon, bool tabVal) {
    final isDark = AppTheme.isDark(context);
    final selected = value == tabVal;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(tabVal),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppTheme.cardBg(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: selected && isDark ? Border.all(color: AppTheme.cardBorderColor(context)) : null,
            boxShadow: selected && !isDark
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? (isDark ? FuturisticColors.neonCyan : _teal) : AppTheme.textSecondary(context)),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? (isDark ? FuturisticColors.neonCyan : _teal) : AppTheme.textSecondary(context))),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Input Field
// ─────────────────────────────────────────────────────────────────────────────
class _Input extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final Color? accentColor;
  final VoidCallback onChanged;

  const _Input({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onChanged,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final accent = accentColor ?? (isDark ? FuturisticColors.neonCyan : _teal);
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: TextStyle(fontSize: 14, color: AppTheme.textPrimary(context)),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 12.5),
        prefixIcon: Container(
          margin: const EdgeInsets.all(4),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: accent),
        ),
        filled: true,
        fillColor: AppTheme.inputBg(context),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.cardBorderColor(context))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.cardBorderColor(context))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: accent, width: 1)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Result Row
// ─────────────────────────────────────────────────────────────────────────────
class _ResultRow extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;
  final bool isPercent;
  final bool isBold;
  final bool isBig;
  final NumberFormat fmt;

  const _ResultRow({
    required this.label,
    required this.value,
    required this.fmt,
    this.color,
    this.isPercent = false,
    this.isBold = false,
    this.isBig = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final c = color ?? (isDark ? AppTheme.textPrimary(context) : _slateLight);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: isBig ? 13 : 12.5,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  color: isBig ? c : AppTheme.textSecondary(context))),
        ),
        const SizedBox(width: 8),
        Text(
          isPercent ? '${value.toStringAsFixed(2)}%' : fmt.format(value),
          style: TextStyle(
            fontSize: isBig ? 15 : isBold ? 14 : 13,
            fontWeight: FontWeight.w700,
            color: c,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Big Result Box
// ─────────────────────────────────────────────────────────────────────────────
class _BigResultBox extends StatelessWidget {
  final String label;
  final String label2;
  final double value;
  final Color color;
  final Color lightColor;
  final NumberFormat fmt;

  const _BigResultBox({
    required this.label,
    required this.label2,

    required this.value,
    required this.color,
    required this.lightColor,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.15) : lightColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  value >= 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color)),
                Text(label2,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
                ],
              ),
            ],
          ),
          Text(
            fmt.format(value),
            style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Separator ─────────────────────────────────────────────────────────────────
class _Sep extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 16, color: AppTheme.divider(context));
}

// ── Customer Option ────────────────────────────────────────────────────────────
class _CustomerOption {
  final Customer customer;
  final String? branchName;
  const _CustomerOption({required this.customer, this.branchName});
  bool get isBranch => branchName != null;
  String get displayName =>
      isBranch ? '$branchName' : customer.name;
}