import 'package:entryon/providers/auth_Provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer_model.dart';
import '../models/service_model.dart';
import '../models/transaction_model.dart';
import '../providers/service_entry_provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/app_theme.dart';

class CustomerwiseMakeTransactionScreen extends StatefulWidget {
  final Customer customer;
  final String? branchName;

  const CustomerwiseMakeTransactionScreen({
    super.key,
    required this.customer,
    this.branchName,
  });

  @override
  State<CustomerwiseMakeTransactionScreen> createState() =>
      _CustomerwiseMakeTransactionScreenState();
}

class _CustomerwiseMakeTransactionScreenState
    extends State<CustomerwiseMakeTransactionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceEntryProvider>().fetchServices();
      context.read<TransactionProvider>().fetchTransactions();
    });
  }

  Future<void> _showPaymentDialog(
    BuildContext context,
    ServiceEntry service,
  ) async {
    final sMessenger = ScaffoldMessenger.of(context);
    final globalServiceProvider = context.read<ServiceEntryProvider>();
    final globalTxnProvider = context.read<TransactionProvider>();
    final isDark = AppTheme.isDark(context);

    final amountController = TextEditingController(
      text: service.balanceAmount.toStringAsFixed(2),
    );
    String paymentType = 'Cash';
    final cardNumberController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.dialogBg(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.cardBorderColor(context)),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Record Payment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.title,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary(context),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Balance highlight
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            (isDark
                                    ? FuturisticColors.neonAmber
                                    : Colors.orange)
                                .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              (isDark
                                      ? FuturisticColors.neonAmber
                                      : Colors.orange)
                                  .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Outstanding Balance',
                            style: TextStyle(
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                          Text(
                            service.balanceAmount.toStringAsFixed(2),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? FuturisticColors.neonAmber
                                  : Colors.orange,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(color: AppTheme.textPrimary(context)),
                      decoration: _dialogInputDecoration(
                        context,
                        'Amount to Pay',
                      ),
                      validator: (v) {
                        final val = double.tryParse(v ?? '0') ?? 0;
                        if (val <= 0) return 'Enter a valid amount';
                        if (val > service.balanceAmount) {
                          return 'Cannot exceed balance';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      initialValue: paymentType,
                      dropdownColor: AppTheme.cardBg(context),
                      style: TextStyle(color: AppTheme.textPrimary(context)),
                      decoration: _dialogInputDecoration(
                        context,
                        'Payment Type',
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'Cash',
                          child: Text(
                            'Cash',
                            style: TextStyle(
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Card',
                          child: Text(
                            'Card',
                            style: TextStyle(
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setDialogState(() => paymentType = v ?? 'Cash');
                      },
                    ),

                    if (paymentType == 'Card') ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: cardNumberController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: AppTheme.textPrimary(context)),
                        decoration: _dialogInputDecoration(
                          context,
                          'Card Number',
                        ),
                        validator: (v) {
                          if (paymentType == 'Card' &&
                              (v == null || v.trim().isEmpty)) {
                            return 'Enter card number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textSecondary(context)),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? FuturisticColors.neonCyan
                        : Colors.teal,
                    foregroundColor: isDark
                        ? FuturisticColors.bgVoid
                        : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final amt =
                        double.tryParse(amountController.text.trim()) ?? 0;
                    final balanceAfterPayment = service.balanceAmount - amt;
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    final txnProvider = context.read<TransactionProvider>();
                    final serviceProvider = context
                        .read<ServiceEntryProvider>();

                    final txn = TransactionModel(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      serviceId: service.id,
                      customerId: service.customerId,
                      customerName: service.customerName,
                      branchName: widget.branchName,
                      amount: amt,
                      balanceAmount: balanceAfterPayment,
                      purchaseAmount: service.amount,
                      pendingAmount: service.customerPaidAmount == 0.00
                          ? service.amount
                          : service.balanceAmount,
                      paymentType: paymentType,
                      paymentDetails: {
                        if (paymentType == 'Card')
                          'cardNumber': cardNumberController.text.trim(),
                        'balanceAmount': balanceAfterPayment,
                      },
                      createdAt: DateTime.now(),
                      addedById: authProvider.currentUserId,
                      addedByName: authProvider.currentUserName,
                    );

                    final ok = await txnProvider.addTransaction(txn);

                    if (ok) {
                      final newPaid = service.customerPaidAmount + amt;
                      final newStatus = newPaid >= service.amount
                          ? 'Paid'
                          : 'Partial';

                      await serviceProvider.updateService(
                        paymentType: newStatus,
                        id: service.id,
                        title: service.title,
                        customerName: service.customerName,
                        customerId: service.customerId,
                        branchName: service.branchName,
                        description: service.description,
                        serviceDate: service.serviceDate,
                        amount: service.amount,
                        serviceFee: service.serviceFee,
                        customerPaidAmount: newPaid,
                        paymentStatus: newStatus,
                        serviceStatus: service.serviceStatus,
                        paymentExpiryDate: service.paymentExpiryDate,
                        purchaseLines: service.purchaseLines,
                      );

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } else {
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, false);
                      }
                    }
                  },
                  child: const Text('Confirm Payment'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      sMessenger.showSnackBar(
        const SnackBar(
          content: Text('Payment recorded successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await globalServiceProvider.fetchServices();
      await globalTxnProvider.fetchTransactions();
    }
  }

  InputDecoration _dialogInputDecoration(BuildContext context, String label) {
    final isDark = AppTheme.isDark(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: AppTheme.textSecondary(context),
        fontSize: 13,
      ),
      filled: true,
      fillColor: AppTheme.inputBg(context),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          color: isDark ? FuturisticColors.neonCyan : Colors.teal,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = context.watch<ServiceEntryProvider>().services;
    final isLoading = context.watch<ServiceEntryProvider>().isLoading;
    final isDark = AppTheme.isDark(context);

    final pending = services.where((service) {
      final matchesCustomer = service.customerId != null
          ? service.customerId == widget.customer.id
          : service.customerName.toLowerCase() ==
                widget.customer.name.toLowerCase();

      final matchesBranch =
          widget.branchName == null ||
          service.branchName?.toLowerCase() == widget.branchName!.toLowerCase();

      return matchesCustomer &&
          matchesBranch &&
          service.paymentStatus.toLowerCase() != 'paid' &&
          (service.amount - service.customerPaidAmount) > 0;
    }).toList();

    // Total outstanding for this customer
    final totalOutstanding = pending.fold<double>(
      0,
      (sum, s) => sum + (s.amount - s.customerPaidAmount),
    );

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          widget.customer.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(context),
          ),
        ),
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppTheme.textPrimary(context)),
      ),
      body: isLoading && services.isEmpty
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? FuturisticColors.neonCyan : Colors.teal,
              ),
            )
          : Column(
              children: [
                // Customer summary header
                if (pending.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.cardBorderColor(context),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.25 : 0.04,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                (isDark
                                        ? FuturisticColors.neonCyan
                                        : Colors.teal)
                                    .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  (isDark
                                          ? FuturisticColors.neonCyan
                                          : Colors.teal)
                                      .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.person_outline,
                            color: isDark
                                ? FuturisticColors.neonCyan
                                : Colors.teal,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${pending.length} pending service${pending.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Total Due: ${totalOutstanding.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? FuturisticColors.neonAmber
                                      : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // List
                Expanded(
                  child: pending.isEmpty
                      ? _EmptyState(customerName: widget.customer.name)
                      : ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: pending.length,
                          itemBuilder: (context, index) {
                            final service = pending[index];
                            final balance =
                                service.amount - service.customerPaidAmount;
                            final paidPercent = service.amount > 0
                                ? (service.customerPaidAmount / service.amount)
                                      .clamp(0.0, 1.0)
                                : 0.0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBg(context),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.cardBorderColor(context),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark ? 0.25 : 0.04,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title + Status
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            service.title,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textPrimary(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ),
                                        _StatusChip(
                                          label: service.paymentStatus,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    // Amount boxes
                                    Row(
                                      children: [
                                        _AmountBox(
                                          label: 'Total',
                                          value: service.amount,
                                        ),
                                        const SizedBox(width: 8),
                                        _AmountBox(
                                          label: 'Paid',
                                          value: service.customerPaidAmount,
                                          color: isDark
                                              ? FuturisticColors.neonTeal
                                              : Colors.green,
                                        ),
                                        const SizedBox(width: 8),
                                        _AmountBox(
                                          label: 'Balance',
                                          value: balance,
                                          color: isDark
                                              ? FuturisticColors.neonAmber
                                              : Colors.orange,
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // Progress
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: paidPercent,
                                        minHeight: 6,
                                        backgroundColor: isDark
                                            ? FuturisticColors.bgSurface
                                            : Colors.grey.shade200,
                                        color: paidPercent >= 1
                                            ? (isDark
                                                  ? FuturisticColors.neonTeal
                                                  : Colors.green)
                                            : (isDark
                                                  ? FuturisticColors.neonCyan
                                                  : Colors.teal),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(paidPercent * 100).toStringAsFixed(0)}% paid',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted(context),
                                      ),
                                    ),

                                    const SizedBox(height: 14),

                                    // Pay button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 42,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _showPaymentDialog(
                                          context,
                                          service,
                                        ),
                                        icon: const Icon(
                                          Icons.payment_outlined,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Pay Now',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark
                                              ? FuturisticColors.neonCyan
                                              : Colors.teal,
                                          foregroundColor: isDark
                                              ? FuturisticColors.bgVoid
                                              : Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String customerName;
  const _EmptyState({required this.customerName});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 70,
            color: isDark ? FuturisticColors.neonTeal : Colors.green.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'All payments are up to date',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No pending balances for $customerName',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted(context)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  const _StatusChip({required this.label});

  Color _color(bool isDark) {
    switch (label.toLowerCase()) {
      case 'paid':
        return isDark ? FuturisticColors.neonTeal : Colors.green;
      case 'partial':
        return isDark ? FuturisticColors.neonAmber : Colors.orange;
      default:
        return isDark ? FuturisticColors.neonCrimson : Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final col = _color(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: col.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AmountBox extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;

  const _AmountBox({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? FuturisticColors.bgSurface : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorderColor(context)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color ?? AppTheme.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
