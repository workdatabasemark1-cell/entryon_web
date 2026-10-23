import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense_model.dart';
import '../providers/expense_provider.dart';
import '../utils/app_theme.dart';
import 'expense_entry_screen.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _periodSections = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().fetchExpenses();
      _loadPeriodSections();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPeriodSections() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('period_sections')
          .orderBy('sectionNumber')
          .get();

      final list = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': (data['name'] ?? '').toString(),
        };
      }).toList();

      if (mounted) {
        setState(() {
          _periodSections = list;
        });
      }
    } catch (e) {
      debugPrint('Error loading periods: $e');
    }
  }

  void _openExpenseEntry([ExpenseModel? existing]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseEntryScreen(existingExpense: existing),
      ),
    ).then((val) {
      if (val == true && mounted) {
        context.read<ExpenseProvider>().fetchExpenses();
      }
    });
  }

  void _deleteExpense(ExpenseModel exp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Expense', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${exp.title}" (${NumberFormat('#,##0.00').format(exp.totalAmount)} SAR)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await context.read<ExpenseProvider>().deleteExpense(exp.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Expense deleted' : 'Failed to delete expense'),
            backgroundColor: success ? Colors.teal : Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: FuturisticColors.neonCyan,
                    onPrimary: FuturisticColors.bgVoid,
                    surface: FuturisticColors.bgCard,
                    onSurface: FuturisticColors.textPrimary,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF0D9488),
                    onPrimary: Colors.white,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      context.read<ExpenseProvider>().setDateRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<ExpenseProvider>();
    final expenses = provider.filteredExpenses;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark
                    ? FuturisticColors.neonCyan.withValues(alpha: 0.15)
                    : const Color(0xFF0D9488).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                LucideIcons.walletCards,
                color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expenses',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                Text(
                  'Track, record & categorize company expenditures',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted(context),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(
              LucideIcons.refreshCw,
              size: 18,
              color: AppTheme.textPrimary(context),
            ),
            onPressed: () => provider.fetchExpenses(),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                foregroundColor: isDark ? FuturisticColors.bgVoid : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => _openExpenseEntry(),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text(
                'New Expense',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.fetchExpenses(),
          child: Column(
            children: [
              // Top KPI Metrics
              _buildMetricsHeader(context, isDark, provider),

              // Filter & Search Toolbar
              _buildFilterBar(context, isDark, provider),

              // Content Area
              Expanded(
                child: provider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : provider.errorMessage != null
                        ? _buildErrorView(provider)
                        : expenses.isEmpty
                            ? _buildEmptyView(isDark)
                            : _buildExpenseList(context, isDark, expenses),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── KPI METRICS HEADER ────────────────────────────────────────────────────
  Widget _buildMetricsHeader(
    BuildContext context,
    bool isDark,
    ExpenseProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.divider(context)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;

          final kpis = [
            _kpiCard(
              title: 'TOTAL EXPENDITURE',
              value: '${NumberFormat('#,##0.00').format(provider.totalFilteredAmount)} SAR',
              icon: LucideIcons.wallet,
              color: isDark ? FuturisticColors.neonTeal : const Color(0xFF0D9488),
              isDark: isDark,
            ),
            _kpiCard(
              title: 'AMOUNT (EX. VAT)',
              value: '${NumberFormat('#,##0.00').format(provider.totalFilteredExVat)} SAR',
              icon: LucideIcons.coins,
              color: isDark ? FuturisticColors.neonCyan : Colors.blue.shade700,
              isDark: isDark,
            ),
            _kpiCard(
              title: 'VAT TAX TOTAL',
              value: '${NumberFormat('#,##0.00').format(provider.totalFilteredVat)} SAR',
              icon: LucideIcons.badgePercent,
              color: isDark ? FuturisticColors.neonAmber : Colors.amber.shade800,
              isDark: isDark,
            ),
            _kpiCard(
              title: 'TOTAL ENTRIES',
              value: '${provider.totalFilteredCount}',
              icon: LucideIcons.fileText,
              color: isDark ? FuturisticColors.neonViolet : Colors.purple.shade700,
              isDark: isDark,
            ),
          ];

          if (isWide) {
            return Row(
              children: kpis.map((k) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: k))).toList(),
            );
          } else {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kpis.map((k) => SizedBox(width: (constraints.maxWidth - 24) / 2, child: k)).toList(),
            );
          }
        },
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppTheme.textMuted(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FILTER TOOLBAR ────────────────────────────────────────────────────────
  Widget _buildFilterBar(
    BuildContext context,
    bool isDark,
    ExpenseProvider provider,
  ) {
    final categories = ['All', ...provider.allCategories];
    final paymentMethods = ['All', ...ExpenseProvider.paymentMethods];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        border: Border(bottom: BorderSide(color: AppTheme.divider(context))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Search Input
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => provider.setSearchQuery(val),
                  style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by title, beneficiary, ref#, notes...',
                    hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 13),
                    prefixIcon: Icon(
                      LucideIcons.search,
                      size: 16,
                      color: isDark ? FuturisticColors.neonCyan : Colors.teal,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 14),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: AppTheme.inputBg(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.cardBorderColor(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.cardBorderColor(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Category Filter Dropdown
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.inputBg(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorderColor(context)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: categories.contains(provider.selectedCategory)
                        ? provider.selectedCategory
                        : 'All',
                    dropdownColor: AppTheme.cardBg(context),
                    icon: const Icon(LucideIcons.chevronDown, size: 14),
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 12, fontWeight: FontWeight.w600),
                    items: categories.map((c) {
                      return DropdownMenuItem<String>(
                        value: c,
                        child: Text(c == 'All' ? 'All Categories' : c),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) provider.setSelectedCategory(val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Payment Method Filter
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.inputBg(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorderColor(context)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: paymentMethods.contains(provider.selectedPaymentMethod)
                        ? provider.selectedPaymentMethod
                        : 'All',
                    dropdownColor: AppTheme.cardBg(context),
                    icon: const Icon(LucideIcons.chevronDown, size: 14),
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 12, fontWeight: FontWeight.w600),
                    items: paymentMethods.map((m) {
                      return DropdownMenuItem<String>(
                        value: m,
                        child: Text(m == 'All' ? 'All Modes' : m),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) provider.setSelectedPaymentMethod(val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Period Section Filter Dropdown
              if (_periodSections.isNotEmpty) ...[
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.inputBg(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorderColor(context)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: provider.selectedPeriodSectionId,
                      dropdownColor: AppTheme.cardBg(context),
                      icon: const Icon(LucideIcons.chevronDown, size: 14),
                      style: TextStyle(
                        color: AppTheme.textPrimary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Periods'),
                        ),
                        ..._periodSections.map((p) => DropdownMenuItem<String?>(
                              value: p['id'],
                              child: Text(p['name'] ?? ''),
                            )),
                      ],
                      onChanged: (val) => provider.setSelectedPeriodSection(val),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // Date Range Picker Button
              InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: provider.filterStartDate != null
                        ? (isDark ? FuturisticColors.neonCyan.withValues(alpha: 0.15) : Colors.teal.shade50)
                        : AppTheme.inputBg(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: provider.filterStartDate != null
                          ? (isDark ? FuturisticColors.neonCyan : Colors.teal)
                          : AppTheme.cardBorderColor(context),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.calendar,
                        size: 14,
                        color: isDark ? FuturisticColors.neonCyan : Colors.teal,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        provider.filterStartDate != null
                            ? '${DateFormat('dd MMM').format(provider.filterStartDate!)} - ${DateFormat('dd MMM').format(provider.filterEndDate!)}'
                            : 'Date Range',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Reset Filter button
              if (provider.searchQuery.isNotEmpty ||
                  provider.selectedCategory != 'All' ||
                  provider.selectedPaymentMethod != 'All' ||
                  provider.filterStartDate != null)
                IconButton(
                  tooltip: 'Reset Filters',
                  icon: const Icon(LucideIcons.rotateCcw, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    provider.resetFilters();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── EXPENSE LIST / CARDS ──────────────────────────────────────────────────
  Widget _buildExpenseList(
    BuildContext context,
    bool isDark,
    List<ExpenseModel> expenses,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final exp = expenses[index];
        return _buildExpenseCard(context, isDark, exp);
      },
    );
  }

  Widget _buildExpenseCard(
    BuildContext context,
    bool isDark,
    ExpenseModel exp,
  ) {
    final catColor = _getCategoryColor(exp.category, isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _openExpenseEntry(exp),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Date badge
                Container(
                  width: 50,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.inputBg(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorderColor(context)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('dd').format(exp.date),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(exp.date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Category tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_getCategoryIcon(exp.category), size: 12, color: catColor),
                                const SizedBox(width: 4),
                                Text(
                                  exp.category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: catColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Payment Mode tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.inputBg(context),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.cardBorderColor(context)),
                            ),
                            child: Text(
                              exp.paymentMethod,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMuted(context),
                              ),
                            ),
                          ),

                          if (exp.referenceNo.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Ref: ${exp.referenceNo}',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        exp.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Payee & Period / Notes
                      Row(
                        children: [
                          if (exp.paidTo.isNotEmpty) ...[
                            Icon(LucideIcons.building, size: 13, color: AppTheme.textMuted(context)),
                            const SizedBox(width: 4),
                            Text(
                              exp.paidTo,
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (exp.periodSectionName != null && exp.periodSectionName!.isNotEmpty) ...[
                            Icon(LucideIcons.calendarRange, size: 13, color: AppTheme.textMuted(context)),
                            const SizedBox(width: 4),
                            Text(
                              exp.periodSectionName!,
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (exp.customerName != null && exp.customerName!.isNotEmpty) ...[
                            Icon(LucideIcons.user, size: 13, color: AppTheme.textMuted(context)),
                            const SizedBox(width: 4),
                            Text(
                              exp.customerName!,
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Amount Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${NumberFormat('#,##0.00').format(exp.totalAmount)} SAR',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? FuturisticColors.neonTeal : const Color(0xFF0D9488),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Excl. VAT: ${NumberFormat('#,##0.00').format(exp.amountExVat)} SAR',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context)),
                    ),
                    Text(
                      'Tax (${exp.vatRate.toStringAsFixed(0)}%): ${NumberFormat('#,##0.00').format(exp.vatAmount)} SAR',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? FuturisticColors.neonAmber : Colors.amber.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Action Menu
                PopupMenuButton<String>(
                  icon: Icon(LucideIcons.moreVertical, size: 18, color: AppTheme.textMuted(context)),
                  color: AppTheme.cardBg(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _openExpenseEntry(exp);
                    } else if (val == 'delete') {
                      _deleteExpense(exp);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(LucideIcons.fileEdit, size: 16, color: AppTheme.textPrimary(context)),
                          const SizedBox(width: 8),
                          const Text('Edit Expense'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── EMPTY STATE ───────────────────────────────────────────────────────────
  Widget _buildEmptyView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? FuturisticColors.neonCyan.withValues(alpha: 0.08)
                    : const Color(0xFF0D9488).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.receipt,
                size: 56,
                color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Expenses Recorded Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Click below to create your first business expense entry\nwith automatic VAT calculation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                foregroundColor: isDark ? FuturisticColors.bgVoid : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _openExpenseEntry(),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text(
                'Record First Expense',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(ExpenseProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.alertTriangle, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage ?? 'An error occurred loading expenses',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => provider.fetchExpenses(),
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category, bool isDark) {
    final cat = category.toLowerCase();
    if (cat.contains('rent')) return isDark ? FuturisticColors.neonViolet : Colors.purple;
    if (cat.contains('util') || cat.contains('elect')) return isDark ? FuturisticColors.neonAmber : Colors.amber.shade800;
    if (cat.contains('suppl') || cat.contains('stat')) return isDark ? FuturisticColors.neonBlue : Colors.blue;
    if (cat.contains('salar')) return isDark ? FuturisticColors.neonTeal : Colors.green.shade700;
    if (cat.contains('fuel')) return isDark ? Colors.orangeAccent : Colors.orange.shade800;
    if (cat.contains('repair')) return isDark ? Colors.cyanAccent : Colors.teal;
    if (cat.contains('it') || cat.contains('tech')) return isDark ? Colors.indigoAccent : Colors.indigo;
    return isDark ? FuturisticColors.neonCyan : Colors.blueGrey;
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('rent')) return LucideIcons.building2;
    if (cat.contains('util') || cat.contains('elect') || cat.contains('water')) return LucideIcons.zap;
    if (cat.contains('stationery') || cat.contains('suppl')) return LucideIcons.paperclip;
    if (cat.contains('salar') || cat.contains('wage')) return LucideIcons.users;
    if (cat.contains('fuel') || cat.contains('transp')) return LucideIcons.truck;
    if (cat.contains('repair') || cat.contains('maint')) return LucideIcons.wrench;
    if (cat.contains('it') || cat.contains('soft') || cat.contains('tech')) return LucideIcons.laptop;
    if (cat.contains('market') || cat.contains('adver')) return LucideIcons.megaphone;
    if (cat.contains('gov') || cat.contains('legal') || cat.contains('fee')) return LucideIcons.scale;
    if (cat.contains('tea') || cat.contains('snack') || cat.contains('hosp')) return LucideIcons.coffee;
    return LucideIcons.tag;
  }
}
