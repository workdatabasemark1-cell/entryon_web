import 'package:entryon/providers/service_entry_provider.dart';
import 'package:entryon/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';

class ServiceTransactionsListScreen extends StatelessWidget {
  final String serviceId;

  const ServiceTransactionsListScreen({super.key, required this.serviceId});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          'Service Transactions',
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

          final transactions = provider.transactions
              .where((txn) => txn.serviceId.toLowerCase() == serviceId.toLowerCase())
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final services = context.read<ServiceEntryProvider>().services;
          final matchingIndex = services.indexWhere((s) => s.id.toLowerCase() == serviceId.toLowerCase());
          final totalAmount = matchingIndex != -1 ? services[matchingIndex].amount : 0.0;
          final totalPaidAmount = matchingIndex != -1 ? services[matchingIndex].customerPaidAmount : 0.0;
          final totalBalanceAmount = totalAmount - totalPaidAmount;

          if (transactions.isEmpty) {
            return Column(
              children: [
                Expanded(
                  child: Center(
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
                          'No transactions found for this service',
                          style: TextStyle(
                            color: AppTheme.textSecondary(context),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
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
                        child: _SummaryBox(
                          label: 'Total Amount',
                          value: totalAmount,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryBox(
                          label: 'Total Paid',
                          value: totalPaidAmount,
                          color: isDark ? FuturisticColors.neonTeal : Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryBox(
                          label: 'Balance Amount',
                          value: totalBalanceAmount,
                          color: totalBalanceAmount > 0
                              ? (isDark ? FuturisticColors.neonCrimson : Colors.red)
                              : (isDark ? FuturisticColors.neonTeal : Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final txn = transactions[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.cardBorderColor(context)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isDark ? FuturisticColors.neonCyan : Colors.teal).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: (isDark ? FuturisticColors.neonCyan : Colors.teal).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  txn.paymentType,
                                  style: TextStyle(
                                    color: isDark ? FuturisticColors.neonCyan : Colors.teal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Service: ${txn.serviceId}',
                            style: TextStyle(color: AppTheme.textSecondary(context)),
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
                                      'Balance: ${txn.balanceAmount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: txn.balanceAmount > 0
                                            ? (isDark ? FuturisticColors.neonCrimson : Colors.red.shade700)
                                            : (isDark ? FuturisticColors.neonTeal : Colors.green),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                DateFormat('dd MMM yyyy • HH:mm').format(txn.createdAt),
                                style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
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
                      child: _SummaryBox(
                        label: 'Total Amount',
                        value: totalAmount,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryBox(
                        label: 'Total Paid',
                        value: totalPaidAmount,
                        color: isDark ? FuturisticColors.neonTeal : Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryBox(
                        label: 'Total Balance',
                        value: totalBalanceAmount,
                        color: totalBalanceAmount > 0
                            ? (isDark ? FuturisticColors.neonCrimson : Colors.red)
                            : (isDark ? FuturisticColors.neonTeal : Colors.green),
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

class _SummaryBox extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SummaryBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgCard : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
