import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/customer_model.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';
import 'branchWaiseMakeAPaymentScreen.dart';
import 'branchWaiseServicesListScreen.dart';
import 'branchWaiseTransactionListScreen.dart';
import 'createCustomerScreen.dart';

class BranchDetailsScreen extends StatefulWidget {
  final Branch branch;
  final int branchIndex;
  final Customer? parentCustomer;

  const BranchDetailsScreen({
    super.key,
    required this.branch,
    required this.branchIndex,
    this.parentCustomer,
  });

  @override
  State<BranchDetailsScreen> createState() => _BranchDetailsScreenState();
}

class _BranchDetailsScreenState extends State<BranchDetailsScreen> {
  Branch get branch => widget.branch;

  String _value(String? value) => value?.trim() ?? '';

  String _dateValue(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '';
    final parsed = DateTime.tryParse(value.toString());
    return parsed == null
        ? value.toString()
        : '${parsed.day.toString().padLeft(2, '0')} ${_monthName(parsed.month)} ${parsed.year}';
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String _branchDetailsText() {
    final lines = <String>[
      'Branch ${widget.branchIndex}: ${branch.name}',
      'Country = ${_value(branch.country).isEmpty ? 'SAUDI ARABIA' : _value(branch.country)}',
      'Organization Unit name = ${_value(branch.organizationUnitName)}',
      'Organization Name = ${_value(branch.organizationName)}',
      'Organization Unit (TIN 10 Digit) = ${_value(branch.taxNumber)}',
      'Common Name = ${_value(branch.commonName).isEmpty ? 'Auto' : _value(branch.commonName)}',
      'Registered Address = ${_value(branch.registeredAddress)}',
      'Business Category = ${_value(branch.businessCategory)}',
      'VAT No: ${_value(branch.taxNumber)}',
      'Email: ${_value(branch.email)}',
      'TelePhone: ${branch.phone}',
      'Alternative Phone: ${_value(branch.phone2)}',
      'Zatca credentials username: ${_value(branch.zatcaUsername)}',
      'Password: ${_value(branch.zatcaPassword)}',
      'Building no: ${_value(branch.buildingNo)}',
      'Street name: ${_value(branch.streetName)}',
      'District Name: ${_value(branch.districtName)}',
      'City Name: ${_value(branch.cityName)}',
      'zip code: ${_value(branch.zipCode)}',
      'Addit No: ${_value(branch.additionalNo)}',
      'Unit no: ${_value(branch.unitNo)}',
      'Cr: ${_value(branch.crNumber)}',
      'Branch Address: ${branch.address}',
      'Period Section: ${_value(branch.periodSectionName)}',
      'Financial Period Start: ${_dateValue(branch.financialPeriodStartDate)}',
      'Financial Period End: ${_dateValue(branch.financialPeriodEndDate)}',
    ];

    for (final staff in branch.staff) {
      lines.add('Staff: ${staff.name} | ${staff.phone}');
    }

    for (final activation in branch.softwareActivations) {
      final software = (activation['softwareName'] ?? activation['name'] ?? '')
          .toString()
          .trim();
      final device =
          (activation['deviceLabel'] ?? activation['deviceType'] ?? '')
              .toString()
              .trim();
      final userId = (activation['activationUserId'] ?? '').toString().trim();
      final key =
          (activation['activationKey'] ??
                  activation['key'] ??
                  activation['licenseKey'] ??
                  '')
              .toString()
              .trim();
      final activationDate = _dateValue(
        activation['activationDate'] ?? activation['startDate'],
      );
      final expiryDate = _dateValue(
        activation['expiryDate'] ?? activation['endDate'],
      );
      lines.add('Software: ${software.isEmpty ? 'Unknown' : software}');
      if (device.isNotEmpty) lines.add('Device: $device');
      if (userId.isNotEmpty) lines.add('User ID: $userId');
      if (activationDate.isNotEmpty) {
        lines.add('Activation Date: $activationDate');
      }
      if (expiryDate.isNotEmpty) lines.add('Expiry Date: $expiryDate');
      lines.add('Activation Key: $key');
    }

    final activatedNames = branch.softwareActivations
        .map(
          (activation) =>
              (activation['softwareName'] ?? activation['name'] ?? '')
                  .toString()
                  .trim(),
        )
        .toSet();
    for (final software in branch.usedSoftwares) {
      if (software.trim().isNotEmpty &&
          !activatedNames.contains(software.trim())) {
        lines.add('Software: ${software.trim()}');
        lines.add('Activation Key: ');
      }
    }

    return lines.join('\n');
  }

  void _copyDetails() {
    Clipboard.setData(ClipboardData(text: _branchDetailsText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Branch details copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = branch.name.trim().isEmpty
        ? 'Branch ${widget.branchIndex}'
        : branch.name.trim();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
        title: Text(title),
        actions: [
          IconButton(
            onPressed: _copyDetails,
            icon: const Icon(LucideIcons.copy),
            tooltip: 'Copy branch details',
          ),
        ],
      ),
      bottomNavigationBar: _buildActionFooter(isDark),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth > 980
              ? 980.0
              : constraints.maxWidth;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isDark, title),
                    const SizedBox(height: 14),
                    _buildSection(
                      isDark,
                      'Address and Organization',
                      LucideIcons.mapPin,
                      [
                        _Detail(label: 'Branch Address', value: branch.address),
                        _Detail(
                          label: 'Registered Address',
                          value: branch.registeredAddress,
                        ),
                        _Detail(label: 'Country', value: branch.country),
                        _Detail(
                          label: 'Organization Name',
                          value: branch.organizationName,
                        ),
                        _Detail(
                          label: 'Organization Unit Name',
                          value: branch.organizationUnitName,
                        ),
                        _Detail(
                          label: 'Common Name',
                          value: branch.commonName ?? 'Auto',
                        ),
                        _Detail(
                          label: 'Business Category',
                          value: branch.businessCategory,
                        ),
                        _Detail(
                          label: 'Building No.',
                          value: branch.buildingNo,
                        ),
                        _Detail(label: 'Street Name', value: branch.streetName),
                        _Detail(
                          label: 'District Name',
                          value: branch.districtName,
                        ),
                        _Detail(label: 'City Name', value: branch.cityName),
                        _Detail(label: 'ZIP Code', value: branch.zipCode),
                        _Detail(
                          label: 'Additional No.',
                          value: branch.additionalNo,
                        ),
                        _Detail(label: 'Unit No.', value: branch.unitNo),
                        _Detail(
                          label: 'Period Section',
                          value: branch.periodSectionName,
                        ),
                        _Detail(
                          label: 'Financial Period Start',
                          value: _dateValue(branch.financialPeriodStartDate),
                        ),
                        _Detail(
                          label: 'Financial Period End',
                          value: _dateValue(branch.financialPeriodEndDate),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildSection(
                      isDark,
                      'Contact and Registration',
                      LucideIcons.phone,
                      [
                        _Detail(label: 'Phone', value: branch.phone),
                        _Detail(
                          label: 'Alternative Phone',
                          value: branch.phone2,
                        ),
                        _Detail(label: 'Email', value: branch.email),
                        _Detail(
                          label: 'VAT / TIN Number',
                          value: branch.taxNumber,
                        ),
                        _Detail(label: 'CR Number', value: branch.crNumber),
                        _Detail(label: 'Care Of', value: branch.careOf),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildSection(
                      isDark,
                      'ZATCA Credentials',
                      LucideIcons.shieldCheck,
                      [
                        _Detail(
                          label: 'Enabled',
                          value: branch.zatcaEnabled ? 'Yes' : 'No',
                        ),
                        _Detail(label: 'Username', value: branch.zatcaUsername),
                        _Detail(label: 'Password', value: branch.zatcaPassword),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildSoftwareSection(isDark),
                    const SizedBox(height: 14),
                    _buildStaffSection(isDark),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionFooter(bool isDark) {
    final customer = widget.parentCustomer;
    if (customer == null) return const SizedBox.shrink();

    Widget button({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
      bool primary = false,
    }) {
      return primary
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? FuturisticColors.neonCyan
                    : const Color(0xFF0D9488),
                foregroundColor: isDark
                    ? const Color(0xFF070B14)
                    : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark
                    ? FuturisticColors.textPrimary
                    : const Color(0xFF1E293B),
                side: BorderSide(
                  color: isDark
                      ? FuturisticColors.borderSubtle
                      : const Color(0xFFCBD5E1),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            );
    }

    void showBranchScreen(Widget screen, {double width = 650}) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: SizedBox(width: width, height: 850, child: screen),
        ),
      );
    }

    final editButton = button(
      icon: LucideIcons.edit3,
      label: 'Edit',
      onPressed: () {
        Responsive.showAdaptiveDialog(
          context: context,
          maxWidth: 900,
          maxHeight: 850,
          child: CreateCustomerScreen(customer: customer),
        );
      },
    );
    final paymentButton = button(
      icon: LucideIcons.wallet,
      label: 'Make Payment',
      onPressed: () => showBranchScreen(
        BranchWaiseMakeAPaymentScreen(customer: customer, branch: branch),
        width: 600,
      ),
      primary: true,
    );
    final transactionsButton = button(
      icon: LucideIcons.receipt,
      label: 'Transactions',
      onPressed: () => showBranchScreen(
        BranchWaiseTransactionListScreen(customer: customer, branch: branch),
      ),
    );
    final servicesButton = button(
      icon: LucideIcons.wrench,
      label: 'Services',
      onPressed: () => showBranchScreen(
        BranchWaiseServicesListScreen(customer: customer, branch: branch),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? FuturisticColors.borderSubtle
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 650) {
              return Column(
                children: [
                  SizedBox(width: double.infinity, child: editButton),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: paymentButton),
                      const SizedBox(width: 8),
                      Expanded(child: transactionsButton),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: servicesButton),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: editButton),
                const SizedBox(width: 10),
                Expanded(child: paymentButton),
                const SizedBox(width: 10),
                Expanded(child: transactionsButton),
                const SizedBox(width: 10),
                Expanded(child: servicesButton),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? FuturisticColors.borderSubtle
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isDark
                    ? FuturisticColors.neonCyan.withValues(alpha: 0.15)
                    : const Color(0xFFE6FFFB),
                child: Icon(
                  LucideIcons.gitBranch,
                  color: isDark
                      ? FuturisticColors.neonCyan
                      : const Color(0xFF0D9488),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? FuturisticColors.textPrimary
                        : const Color(0xFF0F172A),
                  ),
                ),
              ),
              _statusChip(isDark),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _copyDetails,
              icon: const Icon(LucideIcons.copy, size: 16),
              label: const Text('Copy Complete Branch Details'),
              style: FilledButton.styleFrom(
                backgroundColor: isDark
                    ? FuturisticColors.neonCyan
                    : const Color(0xFF0D9488),
                foregroundColor: isDark
                    ? const Color(0xFF070B14)
                    : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(bool isDark) {
    final color = branch.zatcaEnabled
        ? (isDark ? FuturisticColors.neonTeal : const Color(0xFF059669))
        : (isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        branch.zatcaEnabled ? 'ZATCA ON' : 'ZATCA OFF',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSection(
    bool isDark,
    String title,
    IconData icon,
    List<_Detail> details,
  ) {
    final visibleDetails = details
        .where((detail) => detail.value.trim().isNotEmpty)
        .toList();
    return _sectionShell(
      isDark,
      title,
      icon,
      visibleDetails.isEmpty
          ? const Text('No details available')
          : Column(
              children: visibleDetails
                  .map((detail) => _buildDetailRow(detail, isDark))
                  .toList(),
            ),
    );
  }

  Widget _buildSoftwareSection(bool isDark) {
    final cards = <Widget>[];
    for (final activation in branch.softwareActivations) {
      final software =
          (activation['softwareName'] ?? activation['name'] ?? 'Unknown')
              .toString();
      final device =
          (activation['deviceLabel'] ?? activation['deviceType'] ?? '')
              .toString();
      final userId = (activation['activationUserId'] ?? '').toString();
      final key =
          (activation['activationKey'] ??
                  activation['key'] ??
                  activation['licenseKey'] ??
                  '')
              .toString();
      final activationDate = _dateValue(
        activation['activationDate'] ?? activation['startDate'],
      );
      final expiryDate = _dateValue(
        activation['expiryDate'] ?? activation['endDate'],
      );
      cards.add(
        _buildActivationCard(
          isDark,
          software,
          device,
          userId,
          key,
          activationDate,
          expiryDate,
        ),
      );
    }

    final activationNames = branch.softwareActivations
        .map(
          (activation) =>
              (activation['softwareName'] ?? activation['name'] ?? '')
                  .toString()
                  .trim(),
        )
        .toSet();
    for (final software in branch.usedSoftwares) {
      if (software.trim().isNotEmpty &&
          !activationNames.contains(software.trim())) {
        cards.add(_buildActivationCard(isDark, software, '', '', '', '', ''));
      }
    }

    return _sectionShell(
      isDark,
      'Software Activations',
      LucideIcons.cpu,
      cards.isEmpty
          ? const Text('No software activations available')
          : Column(children: cards),
    );
  }

  Widget _buildActivationCard(
    bool isDark,
    String software,
    String device,
    String userId,
    String key,
    String activationDate,
    String expiryDate,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(software, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (device.trim().isNotEmpty) Text('Device: ${device.trim()}'),
          if (userId.trim().isNotEmpty) Text('User ID: ${userId.trim()}'),
          if (activationDate.isNotEmpty) Text('Activated: $activationDate'),
          if (expiryDate.isNotEmpty) Text('Expires: $expiryDate'),
          Text('Activation Key: ${key.trim()}'),
        ],
      ),
    );
  }

  Widget _buildStaffSection(bool isDark) {
    return _sectionShell(
      isDark,
      'Branch Staff',
      LucideIcons.users,
      branch.staff.isEmpty
          ? const Text('No branch staff available')
          : Column(
              children: branch.staff
                  .map(
                    (staff) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(LucideIcons.user, size: 18),
                      title: Text(staff.name),
                      subtitle: Text(staff.phone),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _sectionShell(bool isDark, String title, IconData icon, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? FuturisticColors.borderSubtle
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? FuturisticColors.bgSurface
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isDark
                      ? FuturisticColors.neonCyan
                      : const Color(0xFF0D9488),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? FuturisticColors.textPrimary
                        : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(_Detail detail, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? FuturisticColors.borderSubtle
                : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 165,
              child: Text(
                detail.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? FuturisticColors.textSecondary
                      : const Color(0xFF64748B),
                ),
              ),
            ),
            Expanded(
              child: SelectableText(
                detail.value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? FuturisticColors.textPrimary
                      : const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail {
  final String label;
  final String value;

  const _Detail({required this.label, String? value}) : value = value ?? '';
}
