import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/customer_model.dart';
import '../providers/service_entry_provider.dart';
import '../utils/app_theme.dart';
import 'serviceEntryDetailsScreen.dart';

class CustomerBasedServicesListScreen extends StatelessWidget {
  final Customer customer;
  final String? branchName;

  const CustomerBasedServicesListScreen({
    super.key,
    required this.customer,
    this.branchName,
  });

  Color _statusColor(String status, bool isDark) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed':
        return isDark ? FuturisticColors.neonTeal : Colors.green;
      case 'free':
        return isDark ? FuturisticColors.neonCyan : Colors.blue;
      case 'partial':
      case 'in progress':
      case 'work in progress':
        return isDark ? FuturisticColors.neonAmber : Colors.orange;
      default:
        return isDark ? FuturisticColors.neonCrimson : Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          '${customer.name} Services',
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
      body: Consumer<ServiceEntryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.services.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                color: isDark ? FuturisticColors.neonCyan : Colors.teal,
              ),
            );
          }

          final services = provider.services.where((service) {
            final matchesCustomer = service.customerId != null
                ? service.customerId == customer.id
                : service.customerName.toLowerCase() ==
                      customer.name.toLowerCase();
            return matchesCustomer &&
                (branchName == null ||
                    service.branchName?.toLowerCase() ==
                        branchName!.toLowerCase());
          }).toList()..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));

          if (services.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.handyman_outlined,
                    size: 70,
                    color: AppTheme.textSecondary(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No services found for this customer',
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final totalAmount = services.fold<double>(
            0.0,
            (sum, s) => sum + s.amount,
          );
          final totalPaidAmount = services.fold<double>(
            0.0,
            (sum, s) => sum + s.customerPaidAmount,
          );
          final totalBalanceAmount = totalAmount - totalPaidAmount;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];
                    final balance = service.amount - service.customerPaidAmount;

                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: AppTheme.dialogBg(context),
                            insetPadding: const EdgeInsets.all(20),
                            child: SizedBox(
                              width: 700,
                              height: 900,
                              child: ServiceEntryDetailsScreen(
                                service: service,
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
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
                                    service.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(service.serviceDate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              service.customerName,
                              style: TextStyle(
                                color: AppTheme.textSecondary(context),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _MiniChip(
                                  label: service.paymentStatus,
                                  header: 'Payment',
                                  color: _statusColor(
                                    service.paymentStatus,
                                    isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _MiniChip(
                                  label: service.serviceStatus,
                                  header: 'Service',
                                  color: _statusColor(
                                    service.serviceStatus,
                                    isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _AmountBox(
                                          label: 'Total',
                                          value: service.amount,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _AmountBox(
                                          label: 'Paid',
                                          value: service.customerPaidAmount,
                                          color: isDark
                                              ? FuturisticColors.neonTeal
                                              : Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _AmountBox(
                                          label: 'Balance',
                                          value: balance,
                                          color: balance > 0
                                              ? (isDark
                                                    ? FuturisticColors
                                                          .neonCrimson
                                                    : Colors.red)
                                              : (isDark
                                                    ? FuturisticColors.neonTeal
                                                    : Colors.green),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // const SizedBox(height: 8),
                          ],
                        ),
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
                        color: isDark
                            ? FuturisticColors.neonTeal
                            : Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryBox(
                        label: 'Total Balance',
                        value: totalBalanceAmount,
                        color: totalBalanceAmount > 0
                            ? (isDark
                                  ? FuturisticColors.neonCrimson
                                  : Colors.red)
                            : (isDark
                                  ? FuturisticColors.neonTeal
                                  : Colors.green),
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

class _MiniChip extends StatelessWidget {
  final String label;
  final String header;
  final Color color;

  const _MiniChip({
    required this.label,
    required this.header,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            header,
            style: TextStyle(
              color: AppTheme.textSecondary(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgSurface : Colors.grey.shade50,
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
          Text(
            value.toStringAsFixed(0),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? AppTheme.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SummaryBox({
    required this.label,
    required this.value,
    required this.color,
  });

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
