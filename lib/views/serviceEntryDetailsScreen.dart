import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:entryon/utils/responsive.dart';
import 'package:entryon/views/editServiceEntryScreen.dart';
import 'package:entryon/views/serviceTransactionsListScreen.dart';
import 'package:entryon/views/servicewiseMakeTransactionScreen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/service_model.dart';
import '../utils/service_pdf_generator.dart';
import '../utils/pdf_actions.dart';
import '../utils/app_theme.dart';

class ServiceEntryDetailsScreen extends StatelessWidget {
  final ServiceEntry service;

  const ServiceEntryDetailsScreen({super.key, required this.service});

  Color _getStatusColor(String status, [bool isDark = false]) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed':
        return isDark ? FuturisticColors.neonTeal : const Color(0xFF10B981);
      case 'free':
        return isDark ? FuturisticColors.neonCyan : const Color(0xFF0EA5E9);
      case 'partial':
      case 'in progress':
      case 'work in progress':
        return isDark ? FuturisticColors.neonAmber : const Color(0xFFF59E0B);
      case 'pending':
        return isDark ? FuturisticColors.neonViolet : const Color(0xFF6366F1);
      default:
        return isDark ? FuturisticColors.textMuted : Colors.grey.shade600;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed':
        return LucideIcons.checkCircle2;
      case 'free':
        return LucideIcons.gift;
      case 'partial':
        return LucideIcons.alertCircle;
      case 'in progress':
      case 'work in progress':
        return LucideIcons.wrench;
      case 'pending':
        return LucideIcons.clock;
      default:
        return LucideIcons.helpCircle;
    }
  }

  Future<String?> _getCustomerPhone() async {
    final customerId = service.customerId?.trim();
    if (customerId == null || customerId.isEmpty) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .get();
    final phone = snapshot.data()?['phone']?.toString().trim();
    return phone?.isNotEmpty == true ? phone : null;
  }

  Future<void> _shareAsPdf(BuildContext context) async {
    try {
      final customerPhone = await _getCustomerPhone();
      final bytes = await ServicePdfGenerator.generate(
        service,
        customerPhone: customerPhone,
      );
      if (!context.mounted) return;
      await showPdfActionsSheet(
        context: context,
        bytes: bytes,
        filename: 'service_${service.id}.pdf',
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to export PDF: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isWideScreen = MediaQuery.of(context).size.width >= 960;
    final purchaseTotal = service.purchaseLines.fold<double>(0.0, (total, line) => total + line.cost);
    final balanceAmount = service.amount - service.customerPaidAmount;
    final isFree = service.paymentStatus.toLowerCase() == 'free';
    final isFullyPaid = balanceAmount <= 0;

    return Scaffold(
      backgroundColor: isDark ? FuturisticColors.bgVoid : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Service Details',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
              ),
            ),
            Text(
              service.customerName,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? FuturisticColors.bgSurface : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF334155)),
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.fileText, size: 18, color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488)),
            tooltip: 'Share as PDF',
            onPressed: () => _shareAsPdf(context),
          ),
          IconButton(
            icon: Icon(LucideIcons.edit3, size: 18, color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488)),
            tooltip: 'Edit Service',
            onPressed: () {
              Responsive.showAdaptiveDialog(
                context: context,
                maxWidth: 950,
                maxHeight: 850,
                child: EditServiceEntryScreen(serviceId: service.id),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isWideScreen
          ? _buildWideLayout(context, purchaseTotal, balanceAmount, isFree, isFullyPaid)
          : _buildNarrowLayout(context, purchaseTotal, balanceAmount, isFree, isFullyPaid),
    );
  }

  /// Wide layout (Desktop / Tablet Landscape)
  Widget _buildWideLayout(
    BuildContext context,
    double purchaseTotal,
    double balanceAmount,
    bool isFree,
    bool isFullyPaid,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Column(
            children: [
              _buildHeaderHeroCard(isFree),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Scope, Description, Purchase Lines, Audit
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        if (service.softwareName != null || service.branchName != null || service.staffName != null) ...[
                          _buildScopeCard(),
                          const SizedBox(height: 10),
                        ],
                        _buildDescriptionCard(),
                        const SizedBox(height: 10),
                        _buildPurchaseLinesCard(purchaseTotal),
                        if (service.createdAt != null || service.updatedAt != null) ...[
                          const SizedBox(height: 10),
                          _buildAuditCard(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Right Column: Financial Breakdown & Quick Actions
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildFinancialSummaryCard(purchaseTotal, balanceAmount, isFree, isFullyPaid),
                        const SizedBox(height: 10),
                        _buildActionCenterCard(context),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Narrow layout (Mobile / Portrait Tablet)
  Widget _buildNarrowLayout(
    BuildContext context,
    double purchaseTotal,
    double balanceAmount,
    bool isFree,
    bool isFullyPaid,
  ) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              _buildHeaderHeroCard(isFree),
              const SizedBox(height: 10),
              if (service.softwareName != null || service.branchName != null || service.staffName != null) ...[
                _buildScopeCard(),
                const SizedBox(height: 10),
              ],
              _buildDescriptionCard(),
              const SizedBox(height: 10),
              _buildPurchaseLinesCard(purchaseTotal),
              const SizedBox(height: 10),
              _buildFinancialSummaryCard(purchaseTotal, balanceAmount, isFree, isFullyPaid),
              if (service.createdAt != null || service.updatedAt != null) ...[
                const SizedBox(height: 10),
                _buildAuditCard(),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
        _buildBottomStickyActions(context),
      ],
    );
  }

  // ── 1. Hero Header Card ───────────────────────────────────────────────────

  Widget _buildHeaderHeroCard(bool isFree) {
    return Builder(
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? FuturisticColors.bgCard : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Category Icon Badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? FuturisticColors.neonCyan.withValues(alpha: 0.15)
                          : const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? FuturisticColors.neonCyan : const Color(0xFF99F6E4),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.wrench,
                      color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.title,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(LucideIcons.user, size: 13, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              service.customerName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
              const SizedBox(height: 10),
              // Badges Row: Payment Status, Service Status, Payment Method, Dates
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildBadgePill(
                    label: 'Payment: ${service.paymentStatus}',
                    icon: _getStatusIcon(service.paymentStatus),
                    color: _getStatusColor(service.paymentStatus, isDark),
                  ),
                  _buildBadgePill(
                    label: 'Service: ${service.serviceStatus}',
                    icon: _getStatusIcon(service.serviceStatus),
                    color: _getStatusColor(service.serviceStatus, isDark),
                  ),
                  _buildBadgePill(
                    label: 'Method: ${service.paymentType}',
                    icon: LucideIcons.wallet,
                    color: isDark ? FuturisticColors.neonCyan : const Color(0xFF3B82F6),
                  ),
                  _buildBadgePill(
                    label: 'Date: ${DateFormat('dd MMM yyyy').format(service.serviceDate)}',
                    icon: LucideIcons.calendar,
                    color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
                  ),
                  if (service.paymentExpiryDate != null)
                    _buildBadgePill(
                      label: 'Expiry: ${DateFormat('dd MMM yyyy').format(service.paymentExpiryDate!)}',
                      icon: LucideIcons.clock,
                      color: isDark ? FuturisticColors.neonAmber : const Color(0xFFD97706),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadgePill({required String label, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Scope & Context Card ───────────────────────────────────────────────

  Widget _buildScopeCard() {
    return Builder(
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        return _buildSectionCard(
          title: 'Scope & Terminal Context',
          subtitle: 'Associated software terminal, branch site, and staff assigned',
          icon: LucideIcons.cpu,
          accentColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
          child: Row(
            children: [
              if (service.softwareName != null && service.softwareName!.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? FuturisticColors.neonCyan.withValues(alpha: 0.08)
                          : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? FuturisticColors.neonCyan.withValues(alpha: 0.25)
                            : const Color(0xFF99F6E4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? FuturisticColors.neonCyan.withValues(alpha: 0.15)
                                : const Color(0xFFCCFBF1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            LucideIcons.laptop,
                            color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Software Terminal',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                service.softwareName!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (service.branchName != null && service.branchName!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.08)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.25)
                            : const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                                : const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            LucideIcons.store,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Branch Location',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                service.branchName!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (service.staffName != null && service.staffName!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? FuturisticColors.neonViolet.withValues(alpha: 0.08)
                          : const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? FuturisticColors.neonViolet.withValues(alpha: 0.25)
                            : const Color(0xFFE9D5FF),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? FuturisticColors.neonViolet.withValues(alpha: 0.15)
                                : const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            LucideIcons.user,
                            color: isDark ? FuturisticColors.neonViolet : const Color(0xFF7E22CE),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer Staff',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? FuturisticColors.neonViolet : const Color(0xFF7E22CE),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${service.staffName!}${service.staffPhone != null && service.staffPhone!.isNotEmpty ? " (${service.staffPhone!})" : ""}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── 3. Description Card ───────────────────────────────────────────────────

  Widget _buildDescriptionCard() {
    return Builder(
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        final hasDescription = (service.description ?? '').trim().isNotEmpty;

        return _buildSectionCard(
          title: 'Service Description & Remarks',
          subtitle: 'Internal notes and service instructions',
          icon: LucideIcons.alignLeft,
          accentColor: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
            ),
            child: Text(
              hasDescription ? service.description! : 'No additional description or remarks provided for this service.',
              style: TextStyle(
                fontSize: 13,
                color: hasDescription
                    ? (isDark ? FuturisticColors.textPrimary : const Color(0xFF1E293B))
                    : (isDark ? FuturisticColors.textMuted : Colors.grey.shade500),
                fontStyle: hasDescription ? FontStyle.normal : FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 4. Purchase Lines Card ────────────────────────────────────────────────

  Widget _buildPurchaseLinesCard(double purchaseTotal) {
    return Builder(
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        return _buildSectionCard(
          title: 'Purchase & Replacement Lines',
          subtitle: 'Itemized replacement parts, materials, and licenses',
          icon: LucideIcons.shoppingBag,
          accentColor: isDark ? FuturisticColors.neonViolet : const Color(0xFF6366F1),
          headerTrailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: service.purchaseLines.isNotEmpty
                  ? (isDark ? FuturisticColors.neonViolet.withValues(alpha: 0.15) : const Color(0xFFEEF2FF))
                  : (isDark ? FuturisticColors.bgInput : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${service.purchaseLines.length} Item${service.purchaseLines.length == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: service.purchaseLines.isNotEmpty
                    ? (isDark ? FuturisticColors.neonViolet : const Color(0xFF4F46E5))
                    : (isDark ? FuturisticColors.textMuted : const Color(0xFF64748B)),
              ),
            ),
          ),
          child: service.purchaseLines.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.packageOpen, size: 18, color: isDark ? FuturisticColors.textMuted : Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Text(
                          'No itemized purchase lines recorded',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: service.purchaseLines.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final line = service.purchaseLines[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? FuturisticColors.neonViolet.withValues(alpha: 0.15)
                                      : const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '#${index + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? FuturisticColors.neonViolet : const Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  line.purchaseName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isDark ? FuturisticColors.textPrimary : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              Text(
                                'SAR ${line.cost.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? FuturisticColors.bgElevated : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: isDark ? Border.all(color: FuturisticColors.borderSubtle) : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Parts Subtotal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            'SAR ${purchaseTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? FuturisticColors.neonViolet : const Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // ── 5. Financial Summary Hero Card ────────────────────────────────────────

  Widget _buildFinancialSummaryCard(
    double purchaseTotal,
    double balanceAmount,
    bool isFree,
    bool isFullyPaid,
  ) {
    return Builder(
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        return _buildSectionCard(
          title: 'Financial Breakdown',
          subtitle: 'Service cost, labor charges, and payment balance',
          icon: LucideIcons.dollarSign,
          accentColor: isDark ? FuturisticColors.neonTeal : const Color(0xFF059669),
          child: Column(
            children: [
              // Hero KPI Total Cost Display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF064E3B), Color(0xFF0F766E)]
                        : const [Color(0xFF047857), Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? FuturisticColors.neonTeal : const Color(0xFF0D9488)).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Service Amount',
                          style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isFree ? 'FREE' : 'SAR',
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isFree ? 'Free of Charge' : 'SAR ${service.amount.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Paid: ${service.customerPaidAmount.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Detailed breakdown table
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildMoneyRow(
                      label: 'Labor / Service Fee',
                      value: service.serviceFee,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 6),
                    _buildMoneyRow(
                      label: 'Parts & Purchase Total',
                      value: purchaseTotal,
                      isDark: isDark,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Divider(
                        height: 1,
                        color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0),
                      ),
                    ),
                    _buildMoneyRow(
                      label: 'Total Net Cost',
                      value: service.amount,
                      isBold: true,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 6),
                    _buildMoneyRow(
                      label: 'Customer Amount Paid',
                      value: service.customerPaidAmount,
                      color: isDark ? FuturisticColors.neonTeal : const Color(0xFF059669),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Settlement Status Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: isFree
                      ? (isDark ? FuturisticColors.neonCyan.withValues(alpha: 0.12) : const Color(0xFFF0F9FF))
                      : isFullyPaid
                          ? (isDark ? FuturisticColors.neonTeal.withValues(alpha: 0.12) : const Color(0xFFECFDF5))
                          : (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.12) : const Color(0xFFFEF2F2)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFree
                        ? (isDark ? FuturisticColors.neonCyan.withValues(alpha: 0.3) : const Color(0xFFBAE6FD))
                        : isFullyPaid
                            ? (isDark ? FuturisticColors.neonTeal.withValues(alpha: 0.3) : const Color(0xFFA7F3D0))
                            : (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFFFECACA)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isFree
                              ? LucideIcons.gift
                              : isFullyPaid
                                  ? LucideIcons.checkCircle2
                                  : LucideIcons.alertCircle,
                          size: 16,
                          color: isFree
                              ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF0284C7))
                              : isFullyPaid
                                  ? (isDark ? FuturisticColors.neonTeal : const Color(0xFF059669))
                                  : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isFree
                              ? 'Free of Charge'
                              : isFullyPaid
                                  ? 'Fully Settled'
                                  : 'Outstanding Balance Due',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: isFree
                                ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF0369A1))
                                : isFullyPaid
                                    ? (isDark ? FuturisticColors.neonTeal : const Color(0xFF065F46))
                                    : (isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B)),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      isFree ? 'SAR 0.00' : 'SAR ${balanceAmount.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isFree
                            ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF0284C7))
                            : isFullyPaid
                                ? (isDark ? FuturisticColors.neonTeal : const Color(0xFF059669))
                                : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoneyRow({
    required String label,
    required double value,
    bool isBold = false,
    Color? color,
    bool isDark = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold
                ? (isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A))
                : (isDark ? FuturisticColors.textSecondary : Colors.grey.shade600),
            fontSize: isBold ? 13 : 12.5,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          'SAR ${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? (isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
            fontSize: isBold ? 13.5 : 12.5,
          ),
        ),
      ],
    );
  }

  // ── 6. Action Center Card (Desktop) ───────────────────────────────────────

  Widget _buildActionCenterCard(BuildContext context) {
    return Builder(
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        return _buildSectionCard(
          title: 'Action Center',
          subtitle: 'Register customer payments and inspect transaction logs',
          icon: LucideIcons.zap,
          accentColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Responsive.showAdaptiveDialog(
                      context: context,
                      maxWidth: 600,
                      maxHeight: 900,
                      child: ServicewiseMakeTransactionScreen(service: service),
                    );
                  },
                  icon: const Icon(LucideIcons.creditCard, size: 16),
                  label: const Text('Make Payment', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                    foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Responsive.showAdaptiveDialog(
                      context: context,
                      maxWidth: 600,
                      maxHeight: 900,
                      child: ServiceTransactionsListScreen(serviceId: service.id),
                    );
                  },
                  icon: Icon(
                    LucideIcons.receipt,
                    size: 16,
                    color: isDark ? FuturisticColors.textSecondary : const Color(0xFF334155),
                  ),
                  label: Text(
                    'View Transactions',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? FuturisticColors.textPrimary : const Color(0xFF334155),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? FuturisticColors.textPrimary : const Color(0xFF334155),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(
                      color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 7. Bottom Sticky Actions (Mobile) ─────────────────────────────────────

  Widget _buildBottomStickyActions(BuildContext context) {
    return Builder(
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? FuturisticColors.bgSurface : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Responsive.showAdaptiveDialog(
                      context: context,
                      maxWidth: 600,
                      maxHeight: 900,
                      child: ServicewiseMakeTransactionScreen(service: service),
                    );
                  },
                  icon: const Icon(LucideIcons.creditCard, size: 16),
                  label: const Text('Make Payment', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                    foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Responsive.showAdaptiveDialog(
                      context: context,
                      maxWidth: 600,
                      maxHeight: 900,
                      child: ServiceTransactionsListScreen(serviceId: service.id),
                    );
                  },
                  icon: Icon(
                    LucideIcons.receipt,
                    size: 16,
                    color: isDark ? FuturisticColors.textSecondary : const Color(0xFF334155),
                  ),
                  label: Text(
                    'Transactions',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? FuturisticColors.textPrimary : const Color(0xFF334155),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? FuturisticColors.textPrimary : const Color(0xFF334155),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(
                      color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 8. Audit & Timestamps Card ────────────────────────────────────────────

  Widget _buildAuditCard() {
    return Builder(
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        return _buildSectionCard(
          title: 'Audit & System Logs',
          subtitle: 'Record history, creation timestamps, and editor log',
          icon: LucideIcons.history,
          accentColor: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
          child: Column(
            children: [
              if (service.createdAt != null)
                _buildAuditRow(
                  icon: LucideIcons.calendarPlus,
                  label: 'Created At',
                  value: DateFormat('dd MMM yyyy • HH:mm').format(service.createdAt!),
                  user: service.addedByName,
                ),
              if (service.updatedAt != null) ...[
                if (service.createdAt != null) const SizedBox(height: 6),
                _buildAuditRow(
                  icon: LucideIcons.calendarCheck,
                  label: 'Last Updated',
                  value: DateFormat('dd MMM yyyy • HH:mm').format(service.updatedAt!),
                  user: service.editedByName,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuditRow({
    required IconData icon,
    required String label,
    required String value,
    String? user,
  }) {
    return Builder(
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                ': $value',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                ),
              ),
              if (user != null && user.isNotEmpty) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? FuturisticColors.bgElevated : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.user, size: 10, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        user,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Unified Section Card Builder ──────────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color accentColor,
    Widget? headerTrailing,
    required Widget child,
  }) {
    return Builder(
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        final effectiveAccent = isDark && accentColor == const Color(0xFF0D9488) ? FuturisticColors.neonCyan : accentColor;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? FuturisticColors.bgCard : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: effectiveAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 16, color: effectiveAccent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (headerTrailing != null) headerTrailing,
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
              Padding(
                padding: const EdgeInsets.all(10),
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}