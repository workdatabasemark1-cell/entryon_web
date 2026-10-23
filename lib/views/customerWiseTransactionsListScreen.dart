import 'package:entryon/models/transaction_model.dart';
import 'package:entryon/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';

List<MapEntry<String, List<TransactionModel>>> buildCustomerTransactionGroups(
  List<TransactionModel> transactions,
  String searchQuery,
) {
  final query = searchQuery.trim().toLowerCase();
  final filtered = query.isEmpty
      ? transactions
      : transactions.where((txn) {
          final customer = txn.customerName.toLowerCase();
          return customer.contains(query);
        }).toList();

  final grouped = <String, List<TransactionModel>>{};
  for (final transaction in filtered) {
    final key = transaction.customerName.trim().isEmpty ? 'Unknown Customer' : transaction.customerName;
    grouped.putIfAbsent(key, () => []).add(transaction);
  }

  final sortedEntries = grouped.entries.toList()
    ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

  return sortedEntries;
}

class CustomerWiseTransactionsListScreen extends StatefulWidget {
  const CustomerWiseTransactionsListScreen({super.key});

  @override
  State<CustomerWiseTransactionsListScreen> createState() => _CustomerWiseTransactionsListScreenState();
}

class _CustomerWiseTransactionsListScreenState extends State<CustomerWiseTransactionsListScreen> {
  final TextEditingController _searchController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          'Customer Wise Transactions',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(context),
          ),
        ),
        backgroundColor: AppTheme.surfaceBg(context),
        scrolledUnderElevation: 0,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary(context)),
        actions: [
          Container(
            width: 280,
            margin: const EdgeInsets.only(right: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search customer',
                hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 13),
                prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary(context), size: 20),
                filled: true,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
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
                    color: isDark ? FuturisticColors.neonCyan : Colors.teal,
                  ),
                ),
              ),
            ),
          ),
        ],
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

          final groups = buildCustomerTransactionGroups(
            provider.transactions,
            _searchController.text,
          );

          if (groups.isEmpty) {
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
                    'No transactions found',
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final entry = groups[index];
              final customerName = entry.key;
              final transactions = entry.value;
              final totalAmount = transactions.fold<double>(0, (sum, txn) => sum + txn.amount);

              return Card(
                color: AppTheme.cardBg(context),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppTheme.cardBorderColor(context)),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  textColor: isDark ? FuturisticColors.neonCyan : Colors.teal,
                  iconColor: isDark ? FuturisticColors.neonCyan : Colors.teal,
                  collapsedTextColor: AppTheme.textPrimary(context),
                  collapsedIconColor: AppTheme.textSecondary(context),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          customerName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary(context),
                          ),
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
                          '${transactions.length} txn',
                          style: TextStyle(
                            color: isDark ? FuturisticColors.neonCyan : Colors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Total: ${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(color: AppTheme.textSecondary(context)),
                  ),
                  children: transactions.map((txn) {
                    final createdAt = txn.createdAt;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? FuturisticColors.bgSurface : Colors.white,
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
                                  child: Text(
                                    'Amount: ${txn.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary(context),
                                    ),
                                  ),
                                ),
                                Text(
                                  DateFormat('dd MMM yyyy • HH:mm').format(createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
