import 'package:entryon/models/transaction_model.dart';
import 'package:entryon/providers/service_entry_provider.dart';
import 'package:entryon/views/makeTransactionScreen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_Provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/date_utils.dart';
import '../utils/responsive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/pdf_theme_helper.dart';
import '../utils/pdf_actions.dart';
import '../utils/app_theme.dart';

enum ViewMode { grid, table }

class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  ViewMode _viewMode = ViewMode.grid;
  String _receivedByFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().fetchTransactions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialStart = _fromDate ?? now.subtract(const Duration(days: 30));
    final initialEnd = _toDate ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D9488),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  String getServiceTitle(String serviceId) {
    final services =
        Provider.of<ServiceEntryProvider>(context, listen: false).services;

    for (final service in services) {
      if (service.id.toString() == serviceId) {
        return service.title.toString();
      }
    }

    return serviceId;
  }

  List<TransactionModel> _filteredTransactions(
      List<TransactionModel> transactions) {
    final query = _searchController.text.trim().toLowerCase();
    final start = _fromDate;
    final end = _toDate;

    return transactions.where((txn) {
      final matchesName = query.isEmpty ||
          txn.customerName.toLowerCase().contains(query) ||
          txn.paymentType.toLowerCase().contains(query) ||
          getServiceTitle(txn.serviceId).toLowerCase().contains(query) ||
          (txn.receivedByName?.toLowerCase().contains(query) ?? false);
      final matchesDate = isDateWithinRange(txn.createdAt, start, end);
      final matchesReceivedBy = _receivedByFilter == 'All' ||
          (_receivedByFilter == 'Pending'
              ? txn.receivedByName == null || txn.receivedByName!.isEmpty
              : txn.receivedByName == _receivedByFilter);
      return matchesName && matchesDate && matchesReceivedBy;
    }).toList();
  }

  List<String> _receivedByFilterOptions(
      List<TransactionModel> transactions) {
    final names = transactions
        .map((txn) => txn.receivedByName)
        .whereType<String>()
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', 'Pending', ...names];
  }

  int _getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 650) return 1;
    if (width < 1100) return 2;
    if (width < 1600) return 3;
    return 4;
  }

  void _openMakeTransactionDialog() {
    Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 650,
      maxHeight: 850,
      child: const MakeTransactionScreen(),
    ).then((_) {
      if (mounted) {
        context.read<TransactionProvider>().fetchTransactions();
        context.read<ServiceEntryProvider>().fetchServices();
      }
    });
  }

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    if (context.read<AuthProvider>().currentUserName != 'Administrator') return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceBg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppTheme.cardBorderColor(context)),
        ),
        title: Text('Delete Transaction',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
        content: Text(
            'Are you sure you want to delete the transaction of ${transaction.amount.toStringAsFixed(2)} for ${transaction.customerName}?',
            style: TextStyle(color: AppTheme.textSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary(context))),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              onTap: () => Navigator.pop(dialogContext, true),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text('Delete', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    final deleted =
        await context.read<TransactionProvider>().deleteTransaction(transaction.id);
    if (mounted) {
      if (deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaction deleted successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.accent(context),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete transaction'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _confirmPaymentReceived(TransactionModel transaction) async {
    final auth = context.read<AuthProvider>();
    final userName = auth.currentUserName;
    final userId = auth.currentUserId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceBg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppTheme.cardBorderColor(context)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.checkCircle2,
                  size: 18, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 10),
            Text('Confirm Payment Receipt',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary(context))),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary(context), height: 1.5),
            children: [
              const TextSpan(text: 'Mark payment of '),
              TextSpan(
                text: 'SAR ${transaction.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
              ),
              const TextSpan(text: ' from '),
              TextSpan(
                text: transaction.customerName,
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
              ),
              const TextSpan(text: ' as received by '),
              TextSpan(
                text: userName,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.accent(context)),
              ),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary(context))),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              onTap: () => Navigator.pop(dialogContext, true),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.checkCircle2, size: 15, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Confirm', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await context.read<TransactionProvider>().confirmPaymentReceived(
          transactionId: transaction.id,
          receivedByName: userName,
          receivedById: userId,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Payment marked as received by $userName'
              : 'Could not confirm payment receipt'),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              success ? const Color(0xFF10B981) : Colors.redAccent,
        ),
      );
    }
  }

  /// Reusable widget: green badge if received, teal button if not.
  Widget _buildReceivedWidget(TransactionModel txn, {bool compact = false}) {
    if (txn.receivedAt != null && txn.receivedByName != null) {
      // Already confirmed — show badge
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.checkCircle2,
                size: 11, color: Color(0xFF10B981)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${txn.receivedByName} • ${DateFormat('dd MMM HH:mm').format(txn.receivedAt!)}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF10B981),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Not yet confirmed — show action button
    return InkWell(
      onTap: () => _confirmPaymentReceived(txn),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
        decoration: BoxDecoration(
          color: const Color(0xFF0D9488).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: const Color(0xFF0D9488).withValues(alpha: 0.4), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.checkSquare,
                size: 11, color: Color(0xFF0D9488)),
            const SizedBox(width: 4),
            Text(
              'Mark Received',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D9488),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
      decoration: InputDecoration(
        hintText: 'Search customer or service...',
        hintStyle: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary(context)),
        prefixIcon: Icon(LucideIcons.search, size: 15, color: AppTheme.textSecondary(context)),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(LucideIcons.x, size: 14, color: AppTheme.textSecondary(context)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() => _searchController.clear());
                },
              )
            : null,
        filled: true,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        fillColor: AppTheme.inputBg(context),
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
      ),
    );
  }

  Widget _buildDatePickerButton() {
    final hasDate = _fromDate != null || _toDate != null;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: hasDate ? AppTheme.accent(context).withValues(alpha: 0.08) : AppTheme.cardBg(context),
        border: Border.all(
          color: hasDate ? AppTheme.accent(context) : AppTheme.cardBorderColor(context),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: _pickDateRange,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.calendar,
              size: 15,
              color: hasDate ? AppTheme.accent(context) : AppTheme.textSecondary(context),
            ),
            const SizedBox(width: 6),
            Text(
              !hasDate
                  ? 'Date Filter'
                  : '${_fromDate != null ? DateFormat('dd MMM').format(_fromDate!) : ""}'
                    '${_fromDate != null && _toDate != null ? ' - ' : ''}'
                    '${_toDate != null ? DateFormat('dd MMM').format(_toDate!) : ""}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: hasDate ? FontWeight.w700 : FontWeight.w500,
                color: hasDate ? AppTheme.accent(context) : AppTheme.textPrimary(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedByFilter(List<TransactionModel> transactions) {
    final options = _receivedByFilterOptions(transactions);
    final value = options.contains(_receivedByFilter) ? _receivedByFilter : 'All';

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: value == 'All'
            ? AppTheme.cardBg(context)
            : AppTheme.accent(context).withValues(alpha: 0.08),
        border: Border.all(
          color: value == 'All'
              ? AppTheme.cardBorderColor(context)
              : AppTheme.accent(context),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(LucideIcons.chevronDown,
              size: 14, color: AppTheme.textSecondary(context)),
          style: TextStyle(
            fontSize: 12.5,
            color: value == 'All'
                ? AppTheme.textPrimary(context)
                : AppTheme.accent(context),
            fontWeight: value == 'All' ? FontWeight.w500 : FontWeight.w700,
          ),
          onChanged: (selected) {
            if (selected != null) {
              setState(() => _receivedByFilter = selected);
            }
          },
          items: options
              .map((option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option == 'All' ? 'Received by' : option),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return InkWell(
      onTap: () => setState(() {
        _searchController.clear();
        _fromDate = null;
        _toDate = null;
        _receivedByFilter = 'All';
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surfaceBg(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.cardBorderColor(context)),
        ),
        child: Text(
          'Reset',
          style: TextStyle(
            color: AppTheme.textSecondary(context),
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton(List<TransactionModel> filteredTransactions) {
    return OutlinedButton.icon(
      onPressed: filteredTransactions.isEmpty ? null : () => _exportToPdf(filteredTransactions),
      icon: const Icon(LucideIcons.fileDown, size: 15),
      label: const Text('Export PDF',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.accent(context),
        side: BorderSide(color: AppTheme.accent(context)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildCreatePaymentButton() {final isDark = AppTheme.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.accent(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: _openMakeTransactionDialog,
        borderRadius: BorderRadius.circular(8),
        child:  Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.plus, size: 16, color: isDark==true?Colors.black: Colors.white,),
              SizedBox(width: 6),
              Text('Create Payment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: isDark==true?Colors.black: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final isAdministrator =
        context.read<AuthProvider>().currentUserName == 'Administrator';
    final filteredTransactions = _filteredTransactions(provider.transactions);
    final isWide = MediaQuery.of(context).size.width >= 1100;
    final isMobile = context.isMobile;
    final hasActiveFilter = _searchController.text.trim().isNotEmpty ||
        _fromDate != null ||
      _toDate != null ||
      _receivedByFilter != 'All';

    final viewModeToggleWidget = _ViewModeToggle(
      viewMode: _viewMode,
      onChanged: (mode) => setState(() => _viewMode = mode),
    );

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          'Transactions',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.textPrimary(context),
          ),
        ),
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh transactions',
            icon: Icon(LucideIcons.refreshCw, color: AppTheme.accent(context), size: 17),
            onPressed: provider.isLoading ? null : () => provider.fetchTransactions(),
          ),
          if (isWide) ...[
            viewModeToggleWidget,
            const SizedBox(width: 8),
            SizedBox(
              width: 220,
              height: 38,
              child: _buildSearchField(),
            ),
            const SizedBox(width: 8),
            _buildDatePickerButton(),
            const SizedBox(width: 8),
            _buildReceivedByFilter(provider.transactions),
            if (hasActiveFilter) ...[
              const SizedBox(width: 8),
              _buildResetButton(),
            ],
            const SizedBox(width: 8),
            _buildExportButton(filteredTransactions),
            const SizedBox(width: 8),
            _buildCreatePaymentButton(),
            const SizedBox(width: 14),
          ] else ...[
            viewModeToggleWidget,
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Export PDF',
              icon: Icon(LucideIcons.fileDown, size: 18, color: AppTheme.accent(context)),
              onPressed: filteredTransactions.isEmpty ? null : () => _exportToPdf(filteredTransactions),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 6),
              _buildCreatePaymentButton(),
              const SizedBox(width: 8),
            ],
          ],
        ],
      ),
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: _openMakeTransactionDialog,
              backgroundColor: AppTheme.accent(context),
              foregroundColor: Colors.white,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text(
                'Payment',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            )
          : null,
      body: Column(
        children: [
          if (!isWide)
            Container(
              color: AppTheme.surfaceBg(context),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSearchField()),
                      const SizedBox(width: 6),
                      _buildDatePickerButton(),
                      const SizedBox(width: 6),
                      _buildReceivedByFilter(provider.transactions),
                      if (hasActiveFilter) ...[
                        const SizedBox(width: 6),
                        _buildResetButton(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: Consumer<TransactionProvider>(
              builder: (context, prov, _) {
                if (prov.isLoading && prov.transactions.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(color: AppTheme.accent(context)),
                  );
                }

                if (filteredTransactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceBg(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.receipt,
                              size: 38, color: AppTheme.textSecondary(context)),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          hasActiveFilter
                              ? 'No matching transactions found'
                              : 'No transactions found',
                          style: TextStyle(
                            color: AppTheme.textSecondary(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: _viewMode == ViewMode.table
                          ? _TransactionsTableView(
                              transactions: filteredTransactions,
                              getServiceTitle: getServiceTitle,
                              isAdministrator: isAdministrator,
                              onDelete: _deleteTransaction,
                              onConfirmReceived: _confirmPaymentReceived,
                              buildReceivedWidget: _buildReceivedWidget,
                            )
                          : _buildGridView(
                              filteredTransactions, isAdministrator),
                    ),
                    _buildSummaryBar(context, filteredTransactions),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Grid View ─────────────────────────────────────────────────────────────
  Widget _buildGridView(
      List<TransactionModel> filteredTransactions, bool isAdministrator) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: filteredTransactions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getGridColumns(context),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 116,
      ),
      itemBuilder: (context, index) {
        final txn = filteredTransactions[index];
        final createdAt = txn.createdAt;

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.cardBorderColor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.accent(context).withValues(alpha: 0.12),
                    child: Text(
                      txn.customerName.isNotEmpty
                          ? txn.customerName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      txn.customerName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      txn.paymentType,
                      style: TextStyle(
                        color: AppTheme.accent(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Service: ${getServiceTitle(txn.serviceId)}',
                      style: TextStyle(
                        color: AppTheme.textSecondary(context),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (txn.addedByName.isNotEmpty)
                    Text(
                      'By: ${txn.addedByName}',
                      style: TextStyle(
                        color: AppTheme.textSecondary(context),
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              const SizedBox(height: 2),

              // const Spacer(),
              Row(
                children: [
                  Text(
                    'SAR ${txn.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('dd MMM yyyy • HH:mm').format(createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  if (isAdministrator) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Delete transaction',
                      icon: const Icon(LucideIcons.trash2,
                          color: Colors.redAccent, size: 15),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _deleteTransaction(txn),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              // Payment received confirmation row
              Row(
                children: [
                  Expanded(child: _buildReceivedWidget(txn, compact: true)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Summary Bar ───────────────────────────────────────────────────────────
  Widget _buildSummaryBar(BuildContext context, List<TransactionModel> filteredTransactions) {
    final totalPaidAmount = filteredTransactions.fold<double>(
        0.0, (sum, txn) => sum + txn.amount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg(context),
        border: Border(top: BorderSide(color: AppTheme.cardBorderColor(context), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Spacer(),
          _SummaryItem(
            label: 'Transactions',
            value: filteredTransactions.length.toString(),
            color: AppTheme.accent(context),
          ),
          Container(
            height: 32,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppTheme.cardBorderColor(context),
          ),
          _SummaryItem(
            label: 'Total Paid',
            value: 'SAR ${totalPaidAmount.toStringAsFixed(2)}',
            color: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPdf(List<TransactionModel> transactions) async {
    final totalPaid = transactions.fold<double>(0, (sum, t) => sum + t.amount);
    final cashTotal = transactions
        .where((t) => t.paymentType.toLowerCase().contains('cash'))
        .fold<double>(0, (sum, t) => sum + t.amount);
    final cardOrBankTotal = totalPaid - cashTotal;

    final dateRangeStr = (_fromDate != null && _toDate != null)
        ? '${DateFormat('dd MMM yyyy').format(_fromDate!)} - ${DateFormat('dd MMM yyyy').format(_toDate!)}'
        : 'All Time Records';

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        footer: (context) => PdfThemeHelper.buildPageFooter(
          context: context,
          documentName: 'Transactions Report | Total: SAR ${totalPaid.toStringAsFixed(2)}',
        ),
        build: (context) => [
          // Header
          PdfThemeHelper.buildDocumentHeader(
            title: 'TRANSACTIONS & PAYMENT REPORT',
            subtitle: 'Detailed ledger of receipts, customer collections, and payment methods',
            dateText: 'Period: $dateRangeStr',
            badgeText: '${transactions.length} Transactions',
          ),

          // KPI Metric Summary
          PdfThemeHelper.buildKpiCardsRow([
            PdfKpiItem(
              label: 'Total Collected',
              value: 'SAR ${totalPaid.toStringAsFixed(2)}',
              color: PdfThemeHelper.emeraldGreen,
            ),
            PdfKpiItem(
              label: 'Cash Receipts',
              value: 'SAR ${cashTotal.toStringAsFixed(2)}',
              color: PdfThemeHelper.primaryTealDark,
            ),
            PdfKpiItem(
              label: 'Card / Electronic',
              value: 'SAR ${cardOrBankTotal.toStringAsFixed(2)}',
              color: PdfThemeHelper.indigoAccent,
            ),
            PdfKpiItem(
              label: 'Total Records',
              value: '${transactions.length}',
              color: PdfThemeHelper.darkSlate,
            ),
          ]),

          PdfThemeHelper.buildSectionHeader(
            'TRANSACTION ENTRIES',
            countText: '${transactions.length} entries',
          ),

          // Modern Table
          pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfThemeHelper.borderColor, width: 0.8),
            ),
            child: pw.ClipRRect(
              horizontalRadius: 6,
              verticalRadius: 6,
              child: pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(26), // #
                  1: const pw.FlexColumnWidth(2.6), // Customer
                  2: const pw.FlexColumnWidth(2.2), // Service
                  3: const pw.FlexColumnWidth(1.6), // Method
                  4: const pw.FlexColumnWidth(1.6), // Amount
                  5: const pw.FlexColumnWidth(1.8), // Recorded By
                  6: const pw.FlexColumnWidth(1.8), // Received By
                  7: const pw.FlexColumnWidth(2.2), // Date
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfThemeHelper.darkSlate,
                    ),
                    children: [
                      _pdfCell('#', isHeader: true, alignCenter: true),
                      _pdfCell('Customer', isHeader: true),
                      _pdfCell('Service', isHeader: true),
                      _pdfCell('Method', isHeader: true),
                      _pdfCell('Amount (SAR)', isHeader: true, alignRight: true),
                      _pdfCell('Recorded By', isHeader: true),
                      _pdfCell('Received By', isHeader: true),
                      _pdfCell('Date & Time', isHeader: true),
                    ],
                  ),

                  // Data Rows
                  ...transactions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final t = entry.value;
                    final isEven = index % 2 == 0;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isEven ? PdfColors.white : PdfThemeHelper.surfaceBg,
                      ),
                      children: [
                        _pdfCell('${index + 1}', alignCenter: true, fontSize: 8),
                        _pdfCell(t.customerName, isBold: true, fontSize: 8),
                        _pdfCell(getServiceTitle(t.serviceId), fontSize: 8),
                        _pdfBadgeCell(t.paymentType),
                        _pdfCell(
                          t.amount.toStringAsFixed(2),
                          alignRight: true,
                          isBold: true,
                          fontSize: 8.5,
                          color: PdfThemeHelper.emeraldGreen,
                        ),
                        _pdfCell(t.addedByName.isEmpty ? '-' : t.addedByName, fontSize: 8),
                        _pdfCell(
                          t.receivedByName != null ? t.receivedByName! : 'Pending',
                          fontSize: 8,
                          color: t.receivedByName != null
                              ? PdfThemeHelper.emeraldGreen
                              : PdfThemeHelper.amberWarning,
                          isBold: t.receivedByName != null,
                        ),
                        _pdfCell(
                          DateFormat('dd/MM/yy HH:mm').format(t.createdAt),
                          fontSize: 7.5,
                          color: PdfThemeHelper.textMuted,
                        ),
                      ],
                    );
                  }),

                  // Subtotal Footer Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfThemeHelper.zebraBg,
                      border: pw.Border(
                        top: pw.BorderSide(color: PdfThemeHelper.borderColor, width: 1),
                      ),
                    ),
                    children: [
                      _pdfCell(''),
                      _pdfCell('Total Paid Amount', isBold: true),
                      _pdfCell(''),
                      _pdfCell(''),
                      _pdfCell(
                        'SAR ${totalPaid.toStringAsFixed(2)}',
                        alignRight: true,
                        isBold: true,
                        color: PdfThemeHelper.emeraldGreen,
                      ),
                      _pdfCell(''),
                      _pdfCell(''),
                      _pdfCell(''),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final filename =
        'transactions_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    if (!mounted) return;
    await showPdfActionsSheet(context: context, bytes: bytes, filename: filename);
  }

  static pw.Widget _pdfCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    bool alignRight = false,
    bool alignCenter = false,
    double fontSize = 8.5,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(
        text,
        textAlign: alignRight
            ? pw.TextAlign.right
            : (alignCenter ? pw.TextAlign.center : pw.TextAlign.left),
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : fontSize,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : (color ?? PdfThemeHelper.darkSlate),
        ),
      ),
    );
  }

  static pw.Widget _pdfBadgeCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: PdfThemeHelper.buildStatusBadge(text),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View Mode Toggle Control
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
        color: AppTheme.surfaceBg(context),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (AppTheme.isDark(context) ? FuturisticColors.bgCardHover : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? AppTheme.accent(context) : AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modern Transactions Table View
// ─────────────────────────────────────────────────────────────────────────────

class _TransactionsTableView extends StatelessWidget {
  final List<TransactionModel> transactions;
  final String Function(String) getServiceTitle;
  final bool isAdministrator;
  final Function(TransactionModel) onDelete;
  final Function(TransactionModel) onConfirmReceived;
  final Widget Function(TransactionModel, {bool compact}) buildReceivedWidget;

  const _TransactionsTableView({
    required this.transactions,
    required this.getServiceTitle,
    required this.isAdministrator,
    required this.onDelete,
    required this.onConfirmReceived,
    required this.buildReceivedWidget,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorderColor(context), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.surfaceBg(context)),
              headingRowHeight: 35,
              dataRowMinHeight: 35,
              dataRowMaxHeight: 40,
              horizontalMargin: 18,
              columnSpacing: 26,
              dividerThickness: 1,
              columns: [
                DataColumn(
                  label: Text(
                    'CUSTOMER NAME',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'SERVICE ASSIGNED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'PAYMENT METHOD',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'AMOUNT PAID',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'RECORDED BY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'RECEIVED BY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'DATE & TIME',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (isAdministrator)
                  DataColumn(
                    label: Text(
                      'ACTIONS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary(context),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
              ],
              rows: transactions.map((txn) {
                return DataRow(
                  color: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return isDark ? FuturisticColors.bgCardHover : const Color(0xFFF8FAFC);
                    }
                    return AppTheme.cardBg(context);
                  }),
                  cells: [
                    // Customer Name & Avatar
                    DataCell(
                      Row(
                        children: [
                          // CircleAvatar(
                          //   radius: 15,
                          //   backgroundColor: AppTheme.accent(context).withValues(alpha: 0.12),
                          //   child: Text(
                          //     txn.customerName.isNotEmpty
                          //         ? txn.customerName[0].toUpperCase()
                          //         : '?',
                          //     style: TextStyle(
                          //       fontSize: 12.5,
                          //       fontWeight: FontWeight.bold,
                          //       color: AppTheme.accent(context),
                          //     ),
                          //   ),
                          // ),
                          // const SizedBox(width: 10),
                          Text(
                            txn.customerName,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Service Assigned
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? FuturisticColors.bgVoid : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          getServiceTitle(txn.serviceId),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.textPrimary(context) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),

                    // Payment Type
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accent(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          txn.paymentType,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accent(context),
                          ),
                        ),
                      ),
                    ),

                    // Amount
                    DataCell(
                      Text(
                        'SAR ${txn.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),

                    // Recorded By
                    DataCell(
                      Text(
                        txn.addedByName.isEmpty ? '—' : txn.addedByName,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Received By
                    DataCell(buildReceivedWidget(txn)),

                    // Date & Time
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.calendar,
                              size: 13, color: AppTheme.textSecondary(context)),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd MMM yyyy • HH:mm')
                                .format(txn.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Actions
                    if (isAdministrator)
                      DataCell(
                        IconButton(
                          icon: const Icon(LucideIcons.trash2, size: 16),
                          color: Colors.red.shade500,
                          tooltip: 'Delete Transaction',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          onPressed: () => onDelete(txn),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary Box Widget
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary(context),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}