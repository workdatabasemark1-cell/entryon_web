import 'package:entryon/models/transaction_model.dart';
import 'package:entryon/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';

double _resolveTxnBalanceAmount(TransactionModel txn) {
  final modelBalance = txn.balanceAmount;
  if (modelBalance != 0.0) {
    return modelBalance;
  }

  return (txn.paymentDetails?['balanceAmount'] as num?)?.toDouble() ?? 0.0;
}

List<TransactionModel> _latestTransactionsPerService(
  List<TransactionModel> transactions,
) {
  final latestByService = <String, TransactionModel>{};

  for (final txn in transactions) {
    final key = txn.serviceId.trim().toLowerCase();
    final existing = latestByService[key];

    if (existing == null || txn.createdAt.isAfter(existing.createdAt)) {
      latestByService[key] = txn;
    }
  }

  return latestByService.values.toList();
}

class CustomerTransactionsListScreen extends StatelessWidget {
  final String customerName;
  final String? customerId;
  final String? branchName;

  const CustomerTransactionsListScreen({
    super.key,
    required this.customerName,
    this.customerId,
    this.branchName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          'Transactions',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(context),
          ),
        ),
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary(context)),
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.transactions.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                color: isDark ? FuturisticColors.neonCyan : Colors.teal,
              ),
            );
          }

          final transactions = provider.transactions.where((txn) {
            final matchesById =
                customerId != null &&
                txn.customerId != null &&
                txn.customerId == customerId;
            final matchesByName = customerId == null
                ? txn.customerName.toLowerCase() == customerName.toLowerCase()
                : txn.customerId == null &&
                      txn.customerName.toLowerCase() ==
                          customerName.toLowerCase();
            final matchesBranch =
                branchName == null ||
                txn.branchName?.toLowerCase() == branchName!.toLowerCase();
            return (matchesById || matchesByName) && matchesBranch;
          }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 70,
                    color: AppTheme.textSecondary(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No transactions found for this customer',
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final latestTransactions = _latestTransactionsPerService(
            transactions,
          );
          final totalPaidAmount = transactions.fold<double>(
            0.0,
            (sum, txn) => sum + txn.amount,
          );
          final totalBalanceAmount = latestTransactions.fold<double>(
            0.0,
            (sum, txn) => sum + _resolveTxnBalanceAmount(txn),
          );
          final totalAmount = totalPaidAmount + totalBalanceAmount;
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final txn = transactions[index];
                    final balance = _resolveTxnBalanceAmount(txn);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg(context),
                        borderRadius: BorderRadius.circular(10),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  txn.customerName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (isDark
                                              ? FuturisticColors.neonCyan
                                              : Colors.teal)
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        (isDark
                                                ? FuturisticColors.neonCyan
                                                : Colors.teal)
                                            .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  txn.paymentType,
                                  style: TextStyle(
                                    color: isDark
                                        ? FuturisticColors.neonCyan
                                        : Colors.teal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Service: ${txn.serviceId}',
                            style: TextStyle(
                              color: AppTheme.textSecondary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Amount: ${txn.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Balance: ${balance.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: balance > 0
                                            ? (isDark
                                                  ? FuturisticColors.neonCrimson
                                                  : Colors.red.shade700)
                                            : (isDark
                                                  ? FuturisticColors.neonTeal
                                                  : Colors.green),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'dd MMM yyyy • HH:mm',
                                ).format(txn.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBg(context),
                  border: Border(
                    top: BorderSide(color: AppTheme.cardBorderColor(context)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total Amount: ${totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Total Paid: ${totalPaidAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark
                              ? FuturisticColors.neonTeal
                              : Colors.green,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Total Balance: ${totalBalanceAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: totalBalanceAmount > 0
                              ? (isDark
                                    ? FuturisticColors.neonCrimson
                                    : Colors.red)
                              : (isDark
                                    ? FuturisticColors.neonTeal
                                    : Colors.green),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
