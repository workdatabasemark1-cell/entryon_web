import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense_model.dart';
import '../models/customer_model.dart';
import '../providers/expense_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/auth_Provider.dart';
import '../utils/app_theme.dart';

class ExpenseEntryScreen extends StatefulWidget {
  final ExpenseModel? existingExpense;
  final VoidCallback? onSaved;

  const ExpenseEntryScreen({
    super.key,
    this.existingExpense,
    this.onSaved,
  });

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────────────────────
  late TextEditingController _titleController;
  late TextEditingController _amountExVatController;
  late TextEditingController _vatRateController;
  late TextEditingController _vatAmountController;
  late TextEditingController _totalAmountController;
  late TextEditingController _paidToController;
  late TextEditingController _referenceNoController;
  late TextEditingController _notesController;
  late TextEditingController _customCategoryController;

  // ── Form State ────────────────────────────────────────────────────────────
  late DateTime _selectedDate;
  late String _selectedCategory;
  late String _selectedPaymentMethod;
  String? _selectedPeriodId;
  String? _selectedPeriodName;
  Customer? _selectedCustomer;

  /// true  → user enters the TOTAL amount (inc. VAT) — back-calculate ex-VAT
  /// false → user enters the AMOUNT excl. VAT — forward-calculate total (default)
  bool _amountIsInclusive = false;

  List<Map<String, String>> _periodSections = [];
  bool _isLoadingPeriods = false;
  bool _isSaving = false;

  bool get isEditMode => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    final exp = widget.existingExpense;

    _titleController = TextEditingController(text: exp?.title ?? '');
    _amountExVatController = TextEditingController(
      text: exp != null ? exp.amountExVat.toStringAsFixed(2) : '',
    );
    _vatRateController = TextEditingController(
      text: exp != null ? exp.vatRate.toStringAsFixed(1) : '15',
    );
    _vatAmountController = TextEditingController(
      text: exp != null ? exp.vatAmount.toStringAsFixed(2) : '',
    );
    _totalAmountController = TextEditingController(
      text: exp != null ? exp.totalAmount.toStringAsFixed(2) : '',
    );
    _paidToController = TextEditingController(text: exp?.paidTo ?? '');
    _referenceNoController = TextEditingController(text: exp?.referenceNo ?? '');
    _notesController = TextEditingController(text: exp?.notes ?? '');
    _customCategoryController = TextEditingController();

    _selectedDate = exp?.date ?? DateTime.now();
    _selectedCategory = exp?.category ?? 'General & Miscellaneous';
    _selectedPaymentMethod = exp?.paymentMethod ?? 'Cash';
    _selectedPeriodId = exp?.periodSectionId;
    _selectedPeriodName = exp?.periodSectionName;

    _amountExVatController.addListener(_calculateAmounts);
    _totalAmountController.addListener(_calculateAmounts);
    _vatRateController.addListener(_calculateAmounts);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPeriodSections();
      context.read<CustomerProvider>().fetchCustomers();
      if (exp != null && exp.customerId != null) {
        final custProv = context.read<CustomerProvider>();
        try {
          _selectedCustomer = custProv.customers.firstWhere(
            (c) => c.id == exp.customerId,
          );
          if (mounted) setState(() {});
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _amountExVatController.removeListener(_calculateAmounts);
    _totalAmountController.removeListener(_calculateAmounts);
    _vatRateController.removeListener(_calculateAmounts);
    _titleController.dispose();
    _amountExVatController.dispose();
    _vatRateController.dispose();
    _vatAmountController.dispose();
    _totalAmountController.dispose();
    _paidToController.dispose();
    _referenceNoController.dispose();
    _notesController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadPeriodSections() async {
    setState(() => _isLoadingPeriods = true);
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
          _isLoadingPeriods = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading periods: $e');
      if (mounted) setState(() => _isLoadingPeriods = false);
    }
  }

  void _calculateAmounts() {
    final double vatRate = double.tryParse(_vatRateController.text.trim()) ?? 0.0;

    if (_amountIsInclusive) {
      // Back-calculate from total (inc. VAT)
      final double total = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
      final double exVat = vatRate > 0
          ? total / (1.0 + vatRate / 100.0)
          : total;
      final double vatAmount = total - exVat;

      // Update ex-VAT and VAT without triggering this listener again
      _amountExVatController.removeListener(_calculateAmounts);
      _amountExVatController.text = exVat.toStringAsFixed(2);
      _amountExVatController.addListener(_calculateAmounts);

      _vatAmountController.text = vatAmount.toStringAsFixed(2);
    } else {
      // Forward-calculate from ex-VAT
      final double exVat = double.tryParse(_amountExVatController.text.trim()) ?? 0.0;
      final double vatAmount = exVat * (vatRate / 100.0);
      final double total = exVat + vatAmount;

      _vatAmountController.text = vatAmount.toStringAsFixed(2);

      // Update total without triggering this listener again
      _totalAmountController.removeListener(_calculateAmounts);
      _totalAmountController.text = total.toStringAsFixed(2);
      _totalAmountController.addListener(_calculateAmounts);
    }
  }

  void _toggleInclusiveMode(bool inclusive) {
    setState(() {
      _amountIsInclusive = inclusive;
      // Clear the 'other' field so the user re-enters the intended value
      if (inclusive) {
        _amountExVatController.text = '';
        _vatAmountController.text = '';
      } else {
        _totalAmountController.text = '';
        _vatAmountController.text = '';
      }
    });
  }

  void _setVatRate(double rate) {
    setState(() {
      _vatRateController.text = rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 1);
    });
    _calculateAmounts();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
                  dialogTheme: const DialogThemeData(
                    backgroundColor: FuturisticColors.bgCard,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF0D9488),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _showAddCustomCategoryDialog() async {
    _customCategoryController.clear();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: AppTheme.cardBg(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.cardBorderColor(ctx)),
          ),
          title: Text(
            'Add Custom Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary(ctx),
            ),
          ),
          content: TextField(
            controller: _customCategoryController,
            autofocus: true,
            style: TextStyle(color: AppTheme.textPrimary(ctx), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. Legal Consulting, Equipment Rental',
              hintStyle: TextStyle(color: AppTheme.textMuted(ctx), fontSize: 13),
              filled: true,
              fillColor: AppTheme.inputBg(ctx),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.cardBorderColor(ctx)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.cardBorderColor(ctx)),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted(ctx))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                foregroundColor: isDark ? FuturisticColors.bgVoid : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final cat = _customCategoryController.text.trim();
                if (cat.isNotEmpty) {
                  Navigator.pop(ctx, cat);
                }
              },
              child: const Text('Add Category'),
            ),
          ],
        );
      },
    );

    if (res != null && res.isNotEmpty) {
      setState(() => _selectedCategory = res);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final double vatRate = double.tryParse(_vatRateController.text.trim()) ?? 0.0;

    // ── Always recompute from primary input — never trust computed controller texts ──
    final double exVat;
    final double vatAmount;
    final double totalAmount;

    if (_amountIsInclusive) {
      // Primary input = total (gross). Back-calculate.
      final double gross = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
      if (gross <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a total amount greater than zero.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      totalAmount = gross;
      exVat = vatRate > 0 ? gross / (1.0 + vatRate / 100.0) : gross;
      vatAmount = totalAmount - exVat;
    } else {
      // Primary input = net (ex-VAT). Forward-calculate.
      final double net = double.tryParse(_amountExVatController.text.trim()) ?? 0.0;
      if (net <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter an amount greater than zero.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      exVat = net;
      vatAmount = net * (vatRate / 100.0);
      totalAmount = exVat + vatAmount;
    }

    final auth = context.read<AuthProvider>();
    final currentUserId = auth.currentUserId;
    final currentUserName = auth.currentUserName;

    setState(() => _isSaving = true);

    final expenseModel = ExpenseModel(
      id: widget.existingExpense?.id ?? '',
      title: _titleController.text.trim(),
      category: _selectedCategory,
      amountExVat: exVat,
      vatRate: vatRate,
      vatAmount: vatAmount,
      totalAmount: totalAmount,
      date: _selectedDate,
      paymentMethod: _selectedPaymentMethod,
      referenceNo: _referenceNoController.text.trim(),
      paidTo: _paidToController.text.trim(),
      notes: _notesController.text.trim(),
      periodSectionId: _selectedPeriodId,
      periodSectionName: _selectedPeriodName,
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name,
      addedById: widget.existingExpense?.addedById.isNotEmpty == true
          ? widget.existingExpense!.addedById
          : currentUserId,
      addedByName: widget.existingExpense?.addedByName.isNotEmpty == true
          ? widget.existingExpense!.addedByName
          : currentUserName,
      createdAt: widget.existingExpense?.createdAt ?? DateTime.now(),
      updatedAt: isEditMode ? DateTime.now() : null,
    );

    final provider = context.read<ExpenseProvider>();
    bool success = false;

    if (isEditMode) {
      success = await provider.updateExpense(expenseModel);
    } else {
      success = await provider.addExpense(expenseModel);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditMode
                ? 'Expense updated successfully!'
                : 'Expense created successfully!',
          ),
          backgroundColor: Colors.teal,
        ),
      );
      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.pop(context, true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Operation failed. Try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Expense', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${widget.existingExpense?.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted && widget.existingExpense != null) {
      final success = await context.read<ExpenseProvider>().deleteExpense(widget.existingExpense!.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted successfully'), backgroundColor: Colors.redAccent),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete expense'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  void _clearForm() {
    setState(() {
      _titleController.clear();
      _amountExVatController.clear();
      _vatRateController.text = '15';
      _vatAmountController.clear();
      _totalAmountController.clear();
      _paidToController.clear();
      _referenceNoController.clear();
      _notesController.clear();
      _selectedDate = DateTime.now();
      _selectedCategory = 'General & Miscellaneous';
      _selectedPaymentMethod = 'Cash';
      _selectedPeriodId = null;
      _selectedPeriodName = null;
      _selectedCustomer = null;
      _amountIsInclusive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 900;
    final provider = context.watch<ExpenseProvider>();
    final categories = provider.allCategories;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            LucideIcons.arrowLeft,
            color: AppTheme.textPrimary(context),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
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
                isEditMode ? LucideIcons.fileEdit : LucideIcons.receipt,
                color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditMode ? 'Edit Expense' : 'New Expense Entry',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                Text(
                  isEditMode
                      ? 'Update expense details and tax records'
                      : 'Record business expenditure with VAT calculation',
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
          if (isEditMode)
            IconButton(
              tooltip: 'Delete Expense',
              icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20),
              onPressed: _confirmDelete,
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
              onPressed: _isSaving ? null : _saveExpense,
              icon: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? FuturisticColors.bgVoid : Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.save, size: 16),
              label: Text(
                isEditMode ? 'Update' : 'Save Expense',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- LIVE SUMMARY / KPI CARDS ---
                    _buildCalculatedSummaryBar(isDark),
                    const SizedBox(height: 20),

                    // --- MAIN FORM LAYOUT ---
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildPrimaryDetailsCard(context, isDark, categories),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildFinancialCard(context, isDark),
                                const SizedBox(height: 20),
                                _buildAdditionalDetailsCard(context, isDark),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildPrimaryDetailsCard(context, isDark, categories),
                          const SizedBox(height: 20),
                          _buildFinancialCard(context, isDark),
                          const SizedBox(height: 20),
                          _buildAdditionalDetailsCard(context, isDark),
                        ],
                      ),

                    const SizedBox(height: 24),
                    // Action Buttons Bottom
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textMuted(context),
                            side: BorderSide(color: AppTheme.cardBorderColor(context)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _clearForm,
                          icon: const Icon(LucideIcons.rotateCcw, size: 16),
                          label: const Text('Reset Form'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                            foregroundColor: isDark ? FuturisticColors.bgVoid : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: _isSaving ? null : _saveExpense,
                          icon: _isSaving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark ? FuturisticColors.bgVoid : Colors.white,
                                  ),
                                )
                              : const Icon(LucideIcons.check, size: 18),
                          label: Text(
                            isEditMode ? 'Save Changes' : 'Confirm & Save Expense',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── LIVE CALCULATION BAR ──────────────────────────────────────────────────
  Widget _buildCalculatedSummaryBar(bool isDark) {
    // Always compute live from the primary input so the bar is never stale
    final double vatRate = double.tryParse(_vatRateController.text) ?? 0.0;
    final double exVat;
    final double vatAmt;
    final double total;
    if (_amountIsInclusive) {
      final double gross = double.tryParse(_totalAmountController.text) ?? 0.0;
      exVat = vatRate > 0 ? gross / (1.0 + vatRate / 100.0) : gross;
      vatAmt = gross - exVat;
      total = gross;
    } else {
      exVat = double.tryParse(_amountExVatController.text) ?? 0.0;
      vatAmt = exVat * (vatRate / 100.0);
      total = exVat + vatAmt;
    }

    final accentColor = isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488);
    final amberColor = isDark ? FuturisticColors.neonAmber : Colors.amber.shade800;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F2027), const Color(0xFF1A1A2E)]
              : [const Color(0xFFF0FDF4), const Color(0xFFECFDF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark ? FuturisticColors.cyberBorder : Colors.teal.shade200,
          width: 1.2,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: FuturisticColors.neonCyan.withValues(alpha: 0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.teal.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        children: [
          // Top row — mode badge + heading
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(LucideIcons.zap, size: 14, color: accentColor),
                const SizedBox(width: 6),
                Text(
                  'LIVE BREAKDOWN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: accentColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _amountIsInclusive
                        ? amberColor.withValues(alpha: 0.12)
                        : accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _amountIsInclusive ? amberColor : accentColor,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    _amountIsInclusive ? '⊕ Tax Inclusive' : '⊖ Tax Exclusive',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: _amountIsInclusive ? amberColor : accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: _summaryItem(
                    label: 'NET (EX. VAT)',
                    amount: exVat,
                    color: isDark ? FuturisticColors.textPrimary : const Color(0xFF1E293B),
                    icon: LucideIcons.badgePercent,
                    isInput: !_amountIsInclusive,
                  ),
                ),
                _summaryDivider(context),
                Expanded(
                  child: _summaryItem(
                    label: 'VAT AMOUNT',
                    amount: vatAmt,
                    color: amberColor,
                    icon: LucideIcons.coins,
                  ),
                ),
                _summaryDivider(context),
                Expanded(
                  child: _summaryItem(
                    label: 'GROSS (INC. VAT)',
                    amount: total,
                    color: accentColor,
                    icon: LucideIcons.wallet,
                    isHighlight: true,
                    isInput: _amountIsInclusive,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider(BuildContext context) {
    return Container(height: 44, width: 1, color: AppTheme.divider(context));
  }

  Widget _summaryItem({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
    bool isHighlight = false,
    bool isInput = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppTheme.textMuted(context),
                ),
              ),
              if (isInput) ...[  
                const SizedBox(width: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            NumberFormat('#,##0.00').format(amount),
            style: TextStyle(
              fontSize: isHighlight ? 16 : 14,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            'SAR',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── CARD 1: PRIMARY EXPENSE DETAILS ───────────────────────────────────────
  Widget _buildPrimaryDetailsCard(
    BuildContext context,
    bool isDark,
    List<String> categories,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: LucideIcons.fileSpreadsheet,
            title: 'Expense Information',
            subtitle: 'Essential title, category, and date parameters',
          ),
          const SizedBox(height: 20),

          // Title
          _buildLabel('Expense Title / Purpose *'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Please enter expense title' : null,
            style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
            decoration: _inputDecoration(
              hint: 'e.g. Office Stationery, Annual Software License, Van Service',
              prefixIcon: LucideIcons.edit3,
            ),
          ),
          const SizedBox(height: 18),

          // Category Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLabel('Category *'),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _showAddCustomCategoryDialog,
                icon: Icon(
                  LucideIcons.plusCircle,
                  size: 14,
                  color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                ),
                label: Text(
                  'Custom Category',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: categories.contains(_selectedCategory) ? _selectedCategory : categories.first,
            isExpanded: true,
            dropdownColor: AppTheme.cardBg(context),
            style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
            decoration: _inputDecoration(
              hint: 'Select Category',
              prefixIcon: LucideIcons.tag,
            ),
            items: categories.map((cat) {
              return DropdownMenuItem<String>(
                value: cat,
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(cat),
                      size: 16,
                      color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                    ),
                    const SizedBox(width: 8),
                    Text(cat),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCategory = val);
            },
          ),
          const SizedBox(height: 18),

          // Date Picker & Reference No Row
          Row(
            children: [
              // Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Expense Date *'),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.inputBg(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cardBorderColor(context)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.calendar,
                              size: 16,
                              color: isDark ? FuturisticColors.neonCyan : Colors.teal,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('dd MMM yyyy').format(_selectedDate),
                              style: TextStyle(
                                color: AppTheme.textPrimary(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Reference / Voucher No
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Receipt / Ref No'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _referenceNoController,
                      style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                      decoration: _inputDecoration(
                        hint: 'e.g. REC-8491, VCH-10',
                        prefixIcon: LucideIcons.hash,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Paid To / Beneficiary
          _buildLabel('Paid To / Beneficiary / Supplier'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _paidToController,
            style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
            decoration: _inputDecoration(
              hint: 'e.g. Jarir Bookstore, Saudi Telecom, Landlord, Contractor',
              prefixIcon: LucideIcons.building,
            ),
          ),
        ],
      ),
    );
  }

  // ── CARD 2: FINANCIAL & VAT BREAKDOWN ─────────────────────────────────────
  Widget _buildFinancialCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: LucideIcons.coins,
            title: 'Financial Breakdown',
            subtitle: 'Enter amounts and tax configuration',
          ),
          const SizedBox(height: 20),

          // ── Tax Mode Toggle: pill-style segmented selector ───────────────
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? FuturisticColors.bgVoid.withValues(alpha: 0.5)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.cardBorderColor(context),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(5),
            child: Row(
              children: [
                _taxModeButton(
                  label: 'Excl. Tax',
                  subtitle: 'Enter net amount',
                  icon: LucideIcons.arrowUpRight,
                  isSelected: !_amountIsInclusive,
                  onTap: () => _toggleInclusiveMode(false),
                  isDark: isDark,
                ),
                const SizedBox(width: 5),
                _taxModeButton(
                  label: 'Incl. Tax',
                  subtitle: 'Enter gross total',
                  icon: LucideIcons.arrowDownLeft,
                  isSelected: _amountIsInclusive,
                  onTap: () => _toggleInclusiveMode(true),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Primary Amount Field
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: SizeTransition(sizeFactor: animation, child: child)),
            child: _amountIsInclusive
                ? Column(
                    key: const ValueKey('inclusive'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildLabel('Total Amount Incl. VAT (SAR)'),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Required',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isDark ? FuturisticColors.neonAmber : Colors.amber.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _totalAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter the total amount including VAT';
                          if (double.tryParse(v.trim()) == null) return 'Invalid number';
                          return null;
                        },
                        style: TextStyle(
                          color: isDark ? FuturisticColors.neonAmber : Colors.amber.shade900,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: _inputDecoration(
                          hint: '0.00',
                          prefixIcon: LucideIcons.wallet,
                          suffixLabel: 'GROSS',
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('exclusive'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildLabel('Amount Excl. VAT (SAR)'),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488)).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Required',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountExVatController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter the net amount before VAT';
                          if (double.tryParse(v.trim()) == null) return 'Invalid number';
                          return null;
                        },
                        style: TextStyle(
                          color: AppTheme.textPrimary(context),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: _inputDecoration(
                          hint: '0.00',
                          prefixIcon: LucideIcons.dollarSign,
                          suffixLabel: 'NET',
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),

          // VAT Rate quick selector chips
          _buildLabel('VAT Tax Rate (%)'),
          const SizedBox(height: 8),
          Row(
            children: [
              _vatChip(label: '15% Standard', rate: 15.0, isDark: isDark),
              const SizedBox(width: 8),
              _vatChip(label: '0% Zero-Tax', rate: 0.0, isDark: isDark),
              const SizedBox(width: 8),
              _vatChip(label: '5%', rate: 5.0, isDark: isDark),
            ],
          ),
          const SizedBox(height: 12),

          // Rate field + read-only VAT Amount pill
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Rate %'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _vatRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                      decoration: _inputDecoration(hint: '15', prefixIcon: LucideIcons.percent),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Auto-Computed VAT (SAR)'),
                    const SizedBox(height: 6),
                    // Read-only amber badge-style container
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? FuturisticColors.neonAmber.withValues(alpha: 0.07)
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? FuturisticColors.neonAmber.withValues(alpha: 0.35)
                              : Colors.amber.shade300,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.coins,
                            size: 15,
                            color: isDark ? FuturisticColors.neonAmber : Colors.amber.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              double.tryParse(_vatAmountController.text) != null
                                  ? NumberFormat('#,##0.00').format(
                                      double.parse(_vatAmountController.text))
                                  : '0.00',
                              style: TextStyle(
                                color: isDark ? FuturisticColors.neonAmber : Colors.amber.shade900,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            'SAR',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? FuturisticColors.neonAmber.withValues(alpha: 0.6)
                                  : Colors.amber.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Computed breakdown row (shown in both modes)
          (() {
            final double vr = double.tryParse(_vatRateController.text) ?? 0.0;
            final double exVatLive;
            final double vatLive;
            final double totalLive;
            if (_amountIsInclusive) {
              final double g = double.tryParse(_totalAmountController.text) ?? 0.0;
              exVatLive = vr > 0 ? g / (1.0 + vr / 100.0) : g;
              vatLive = g - exVatLive;
              totalLive = g;
            } else {
              exVatLive = double.tryParse(_amountExVatController.text) ?? 0.0;
              vatLive = exVatLive * (vr / 100.0);
              totalLive = exVatLive + vatLive;
            }
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? FuturisticColors.borderSubtle
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  _miniBreakdownChip(
                    label: 'Net',
                    value: exVatLive,
                    color: AppTheme.textPrimary(context),
                    isDark: isDark,
                    isInput: !_amountIsInclusive,
                  ),
                  _miniDivider(isDark),
                  _miniBreakdownChip(
                    label: 'VAT',
                    value: vatLive,
                    color: isDark ? FuturisticColors.neonAmber : Colors.amber.shade700,
                    isDark: isDark,
                  ),
                  _miniDivider(isDark),
                  _miniBreakdownChip(
                    label: 'Total',
                    value: totalLive,
                    color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                    isDark: isDark,
                    isBold: true,
                    isInput: _amountIsInclusive,
                  ),
                ],
              ),
            );
          })(),
          const SizedBox(height: 16),

          // Payment Method
          _buildLabel('Payment Method *'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedPaymentMethod,
            isExpanded: true,
            dropdownColor: AppTheme.cardBg(context),
            style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
            decoration: _inputDecoration(
              hint: 'Select Method',
              prefixIcon: LucideIcons.creditCard,
            ),
            items: ExpenseProvider.paymentMethods.map((m) {
              return DropdownMenuItem<String>(
                value: m,
                child: Row(
                  children: [
                    Icon(_getPaymentIcon(m), size: 16, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(m),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedPaymentMethod = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _miniDivider(bool isDark) {
    return Container(
      height: 30,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0),
    );
  }

  Widget _miniBreakdownChip({
    required String label,
    required double value,
    required Color color,
    required bool isDark,
    bool isBold = false,
    bool isInput = false,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.textMuted(context),
                ),
              ),
              if (isInput) ...[  
                const SizedBox(width: 3),
                Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            NumberFormat('#,##0.00').format(value),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isBold ? 13 : 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── CARD 3: ADDITIONAL ATTRIBUTES (PERIOD, CUSTOMER, NOTES) ───────────────
  Widget _buildAdditionalDetailsCard(BuildContext context, bool isDark) {
    final customerProvider = context.watch<CustomerProvider>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: LucideIcons.layers,
            title: 'Reporting & Linking',
            subtitle: 'Optional period section, client link, and remarks',
          ),
          const SizedBox(height: 20),

          // Period Section
          _buildLabel('Period Section (Optional)'),
          const SizedBox(height: 8),
          if (_isLoadingPeriods)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<String?>(
              initialValue: _selectedPeriodId,
              isExpanded: true,
              dropdownColor: AppTheme.cardBg(context),
              style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
              decoration: _inputDecoration(
                hint: 'Link to Period Section (e.g. Q1 2026)',
                prefixIcon: LucideIcons.calendarRange,
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('No Period Section', style: TextStyle(color: AppTheme.textMuted(context))),
                ),
                ..._periodSections.map((p) {
                  return DropdownMenuItem<String?>(
                    value: p['id'],
                    child: Text(p['name'] ?? ''),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedPeriodId = val;
                  if (val != null) {
                    final item = _periodSections.firstWhere(
                      (p) => p['id'] == val,
                      orElse: () => {'name': ''},
                    );
                    _selectedPeriodName = item['name'];
                  } else {
                    _selectedPeriodName = null;
                  }
                });
              },
            ),
          const SizedBox(height: 18),

          // Optional Customer Link
          _buildLabel('Associated Customer (Optional)'),
          const SizedBox(height: 8),
          DropdownButtonFormField<Customer?>(
            initialValue: _selectedCustomer,
            isExpanded: true,
            dropdownColor: AppTheme.cardBg(context),
            style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
            decoration: _inputDecoration(
              hint: 'Select customer if billable',
              prefixIcon: LucideIcons.user,
            ),
            items: [
              DropdownMenuItem<Customer?>(
                value: null,
                child: Text('None (Internal Business Expense)', style: TextStyle(color: AppTheme.textMuted(context))),
              ),
              ...customerProvider.customers.map((c) {
                return DropdownMenuItem<Customer?>(
                  value: c,
                  child: Text(c.name),
                );
              }),
            ],
            onChanged: (val) {
              setState(() => _selectedCustomer = val);
            },
          ),
          const SizedBox(height: 18),

          // Notes
          _buildLabel('Notes & Description'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
            decoration: _inputDecoration(
              hint: 'Additional information, authorization remarks, invoice notes...',
              prefixIcon: LucideIcons.alignLeft,
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPER WIDGETS ────────────────────────────────────────────────────────
  Widget _cardHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? FuturisticColors.neonCyan.withValues(alpha: 0.12)
                : const Color(0xFF0D9488).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _vatChip({
    required String label,
    required double rate,
    required bool isDark,
  }) {
    final currentRate = double.tryParse(_vatRateController.text.trim()) ?? -1.0;
    final isSelected = (currentRate == rate);

    return InkWell(
      onTap: () => _setVatRate(rate),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? FuturisticColors.neonCyan.withValues(alpha: 0.2) : const Color(0xFF0D9488).withValues(alpha: 0.15))
              : AppTheme.inputBg(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488))
                : AppTheme.cardBorderColor(context),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488))
                : AppTheme.textPrimary(context),
          ),
        ),
      ),
    );
  }

  /// Tax mode toggle button (Excl. Tax / Incl. Tax)
  Widget _taxModeButton({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final accentColor = isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? accentColor.withValues(alpha: 0.15)
                    : accentColor.withValues(alpha: 0.09))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? accentColor : Colors.transparent,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.15)
                      : AppTheme.cardBg(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: isSelected ? accentColor : AppTheme.textMuted(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? accentColor : AppTheme.textPrimary(context),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary(context),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    IconData? prefixIcon,
    String? suffixLabel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 13),
      prefixIcon: prefixIcon != null
          ? Icon(
              prefixIcon,
              size: 16,
              color: isDark ? FuturisticColors.neonCyan.withValues(alpha: 0.8) : const Color(0xFF0D9488),
            )
          : null,
      suffixIcon: suffixLabel != null
          ? Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? FuturisticColors.neonCyan.withValues(alpha: 0.12)
                    : const Color(0xFF0D9488).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                suffixLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                ),
              ),
            )
          : null,
      suffixIconConstraints: const BoxConstraints(),
      filled: true,
      fillColor: AppTheme.inputBg(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
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

  IconData _getPaymentIcon(String method) {
    final m = method.toLowerCase();
    if (m.contains('cash')) return LucideIcons.banknote;
    if (m.contains('transfer') || m.contains('bank')) return LucideIcons.arrowRightLeft;
    if (m.contains('card')) return LucideIcons.creditCard;
    if (m.contains('cheque')) return LucideIcons.fileCheck;
    return LucideIcons.wallet;
  }
}
