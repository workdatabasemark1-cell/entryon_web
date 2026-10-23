import 'package:entryon/providers/auth_Provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/service_model.dart';
import '../models/transaction_model.dart';
import '../providers/service_entry_provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/app_theme.dart';

class ServicewiseMakeTransactionScreen extends StatefulWidget {
  final ServiceEntry service;

  const ServicewiseMakeTransactionScreen({super.key, required this.service});

  @override
  State<ServicewiseMakeTransactionScreen> createState() =>
      _ServicewiseMakeTransactionScreenState();
}

class _ServicewiseMakeTransactionScreenState
    extends State<ServicewiseMakeTransactionScreen> {
  late ServiceEntry _service;

  @override
  void initState() {
    super.initState();
    _service = widget.service;
  }

  Future<void> _showPaymentDialog(BuildContext context) async {
    final sMessenger = ScaffoldMessenger.of(context);
    final globalServiceProvider = context.read<ServiceEntryProvider>();
    final globalTxnProvider = context.read<TransactionProvider>();
    final isDark = AppTheme.isDark(context);

    final amountController =
        TextEditingController(text: _service.balanceAmount.toStringAsFixed(2));
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
                    _service.title,
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
                        color: (isDark ? FuturisticColors.neonAmber : Colors.orange).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (isDark ? FuturisticColors.neonAmber : Colors.orange).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Outstanding Balance',
                              style: TextStyle(color: AppTheme.textSecondary(context))),
                          Text(
                            _service.balanceAmount.toStringAsFixed(2),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? FuturisticColors.neonAmber : Colors.orange,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppTheme.textPrimary(context)),
                      decoration: _dialogInputDecoration(context, 'Amount to Pay'),
                      validator: (v) {
                        final val = double.tryParse(v ?? '0') ?? 0;
                        if (val <= 0) return 'Enter a valid amount';
                        if (val > _service.balanceAmount) {
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
                      decoration: _dialogInputDecoration(context, 'Payment Type'),
                      items: [
                        DropdownMenuItem(
                          value: 'Cash',
                          child: Text('Cash', style: TextStyle(color: AppTheme.textPrimary(context))),
                        ),
                        DropdownMenuItem(
                          value: 'Card',
                          child: Text('Card', style: TextStyle(color: AppTheme.textPrimary(context))),
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
                        decoration: _dialogInputDecoration(context, 'Card Number'),
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
                  child: Text('Cancel',
                      style: TextStyle(color: AppTheme.textSecondary(context))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? FuturisticColors.neonCyan : Colors.teal,
                    foregroundColor: isDark ? FuturisticColors.bgVoid : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final amt =
                        double.tryParse(amountController.text.trim()) ?? 0;
                    final balanceAfterPayment = _service.balanceAmount - amt;
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final txnProvider = context.read<TransactionProvider>();
                    final serviceProvider = context.read<ServiceEntryProvider>();

                    final txn = TransactionModel(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      serviceId: _service.id,
                      customerId: _service.customerId,
                      customerName: _service.customerName,
                      amount: amt,
                      balanceAmount: balanceAfterPayment,
                      purchaseAmount: _service.amount,
                      pendingAmount: _service.customerPaidAmount == 0.00 ? _service.amount : _service.balanceAmount,
                      paymentType: paymentType,
                      paymentDetails: {
                        if (paymentType == 'Card')
                          'cardNumber': cardNumberController.text.trim() == '0',
                        'balanceAmount': balanceAfterPayment,
                      },
                      createdAt: DateTime.now(),
                      addedById: authProvider.currentUserId,
                      addedByName: authProvider.currentUserName,
                    );

                    final ok = await txnProvider.addTransaction(txn);

                    if (ok) {
                      final newPaid = _service.customerPaidAmount + amt;
                      final newStatus =
                          newPaid >= _service.amount ? 'Paid' : 'Partial';

                      await serviceProvider.updateService(
                        paymentType: _service.paymentType,
                        id: _service.id,
                        title: _service.title,
                        customerName: _service.customerName,
                        customerId: _service.customerId,
                        description: _service.description,
                        serviceDate: _service.serviceDate,
                        amount: _service.amount,
                        serviceFee: _service.serviceFee,
                        customerPaidAmount: newPaid,
                        paymentStatus: newStatus,
                        serviceStatus: _service.serviceStatus,
                        paymentExpiryDate: _service.paymentExpiryDate,
                        purchaseLines: _service.purchaseLines,
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

      // Refresh local service data
      await globalServiceProvider.fetchServices();
      final updated = globalServiceProvider.services
          .where((s) => s.id == _service.id)
          .toList();

      if (updated.isNotEmpty && mounted) {
        setState(() => _service = updated.first);
      }

      await globalTxnProvider.fetchTransactions();
    }
  }

  InputDecoration _dialogInputDecoration(BuildContext context, String label) {
    final isDark = AppTheme.isDark(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
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
    final isDark = AppTheme.isDark(context);
    final balance = _service.amount - _service.customerPaidAmount;
    final paidPercent = _service.amount > 0
        ? (_service.customerPaidAmount / _service.amount).clamp(0.0, 1.0)
        : 0.0;
    final isFullyPaid = balance <= 0;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: const Text(
          'Service Payment',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Header Card ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardBg(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorderColor(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _service.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ),
                      _StatusChip(label: _service.paymentStatus),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: AppTheme.textSecondary(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _service.customerName,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppTheme.textMuted(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd MMM yyyy').format(_service.serviceDate),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Financial Summary ───────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorderColor(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      _AmountBox(label: 'Total', value: _service.amount),
                      const SizedBox(width: 10),
                      _AmountBox(
                        label: 'Paid',
                        value: _service.customerPaidAmount,
                        color: isDark ? FuturisticColors.neonTeal : Colors.green,
                      ),
                      const SizedBox(width: 10),
                      _AmountBox(
                        label: 'Balance',
                        value: balance,
                        color: isFullyPaid
                            ? (isDark ? FuturisticColors.neonTeal : Colors.green)
                            : (isDark ? FuturisticColors.neonAmber : Colors.orange),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: paidPercent,
                      minHeight: 8,
                      backgroundColor: isDark
                          ? FuturisticColors.bgSurface
                          : Colors.grey.shade200,
                      color: isFullyPaid
                          ? (isDark ? FuturisticColors.neonTeal : Colors.green)
                          : (isDark ? FuturisticColors.neonCyan : Colors.teal),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(paidPercent * 100).toStringAsFixed(0)}% paid',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Status message or Pay button ────────────────────────────
            if (isFullyPaid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (isDark ? FuturisticColors.neonTeal : Colors.green)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isDark ? FuturisticColors.neonTeal : Colors.green)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 48,
                      color: isDark ? FuturisticColors.neonTeal : Colors.green.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Fully Paid',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? FuturisticColors.neonTeal : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This service has no outstanding balance',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentDialog(context),
                  icon: const Icon(Icons.payment_outlined, size: 20),
                  label: const Text(
                    'Make Payment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? FuturisticColors.neonCyan : Colors.teal,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? FuturisticColors.bgSurface : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorderColor(context)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
            ),
            const SizedBox(height: 4),
            Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color ?? AppTheme.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}