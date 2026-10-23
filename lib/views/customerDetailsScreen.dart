import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer_model.dart';
import '../providers/customer_provider.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';
import 'branchDetailsScreen.dart';
import 'createCustomerScreen.dart';
import 'customerBasedServicesListScreen.dart';
import 'customerTransactionsListScreen.dart';
import 'customerwiseMakeTransactionScreen.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailsScreen({super.key, required this.customer});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  bool _obscureZatcaPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index != _selectedTabIndex) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Resolve current customer from CustomerProvider to reflect real-time updates after edit
  Customer _resolveCurrentCustomer(BuildContext context) {
    try {
      final provider = context.watch<CustomerProvider>();
      final found = provider.customers.cast<Customer?>().firstWhere(
        (c) => c != null && c.id == widget.customer.id,
        orElse: () => null,
      );
      return found ?? widget.customer;
    } catch (_) {
      return widget.customer;
    }
  }

  // ── Helper Utilities ────────────────────────────────────────────────────────

  String _normalizePhoneForWhatsApp(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    } else if (cleaned.startsWith('00')) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith('0') && cleaned.length == 10) {
      cleaned = '966${cleaned.substring(1)}';
    }
    return cleaned;
  }

  Future<void> _launchWhatsApp(String phone, {String? customMessage}) async {
    final cleanedPhone = _normalizePhoneForWhatsApp(phone);
    if (cleanedPhone.isEmpty) {
      _showToast('No phone number available for WhatsApp', isError: true);
      return;
    }

    final query = customMessage != null && customMessage.isNotEmpty
        ? '?text=${Uri.encodeComponent(customMessage)}'
        : '';
    final uri = Uri.parse('https://wa.me/$cleanedPhone$query');

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (e) {
      _showToast('Could not open WhatsApp: $e', isError: true);
    }
  }

  Future<void> _launchPhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) {
      _showToast('No phone number available to call', isError: true);
      return;
    }
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _showToast('Could not initiate phone call: $e', isError: true);
    }
  }

  Future<void> _launchEmail(String email) async {
    final clean = email.trim();
    if (clean.isEmpty) {
      _showToast('No email address available', isError: true);
      return;
    }
    final uri = Uri.parse('mailto:$clean');
    try {
      await launchUrl(uri);
    } catch (e) {
      _showToast('Could not open email client: $e', isError: true);
    }
  }

  void _copyToClipboard(String text, String label) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text.trim()));
    _showToast('$label copied to clipboard');
  }

  String _customerAddressDetails(Customer customer) {
    String value(String? field) => field?.trim() ?? '';
    final softwareDetails = <String>[];
    final activatedSoftwareNames = <String>{};

    for (final activation in customer.softwareActivations) {
      final softwareName =
          (activation['softwareName'] ?? activation['name'] ?? '')
              .toString()
              .trim();
      if (softwareName.isEmpty) continue;

      activatedSoftwareNames.add(softwareName);
      final activationKey =
          (activation['activationKey'] ??
                  activation['key'] ??
                  activation['licenseKey'] ??
                  '')
              .toString()
              .trim();
      final deviceLabel =
          (activation['deviceLabel'] ?? activation['deviceType'] ?? '')
              .toString()
              .trim();
      final activationUserId = (activation['activationUserId'] ?? '')
          .toString()
          .trim();

      softwareDetails.add(
        [
          'Software: $softwareName',
          if (deviceLabel.isNotEmpty) 'Device: $deviceLabel',
          if (activationUserId.isNotEmpty) 'User ID: $activationUserId',
          'Activation Key: $activationKey',
        ].join('\n'),
      );
    }

    for (final software in customer.usedSoftwares) {
      final softwareName = software.trim();
      if (softwareName.isEmpty ||
          activatedSoftwareNames.contains(softwareName)) {
        continue;
      }
      softwareDetails.add('Software: $softwareName\nActivation Key: ');
    }

    return [
      'Country = ${value(customer.country).isEmpty ? 'SAUDI ARABIA' : value(customer.country)}',
      'Organization Unit name = ${value(customer.organizationUnitName)}',
      'Organization Name = ${value(customer.organizationName)}',
      'Organization Unit (TIN 10 Digit) = ${value(customer.taxNumber)}',
      'Common Name = ${value(customer.commonName).isEmpty ? 'Auto' : value(customer.commonName)}',
      'Registered Address = ${value(customer.registeredAddress)}',
      'Business Category = ${value(customer.businessCategory)}',
      'VAT No: ${value(customer.taxNumber)}',
      'Email : ${value(customer.email)}',
      'TelePhone : ${customer.phone}',
      'Zatca credentials username : ${value(customer.zatcaUsername)}',
      'Password : ${value(customer.zatcaPassword)}',
      'Building no : ${value(customer.buildingNo)}',
      'Street name : ${value(customer.streetName)}',
      'District Name : ${value(customer.districtName)}',
      'City Name : ${value(customer.cityName)}',
      'zip code : ${value(customer.zipCode)}',
      'Addit No : ${value(customer.additionalNo)}',
      'Unit no : ${value(customer.unitNo)}',
      'Cr: ${value(customer.crNumber)}',
      ...softwareDetails,
    ].join('\n');
  }

  String _branchAddressDetails(Branch branch, int index) {
    final softwareDetails = <String>[];
    String value(String? field) => field?.trim() ?? '';

    for (final activation in branch.softwareActivations) {
      final softwareName =
          (activation['softwareName'] ?? activation['name'] ?? '')
              .toString()
              .trim();
      final activationKey =
          (activation['activationKey'] ??
                  activation['key'] ??
                  activation['licenseKey'] ??
                  '')
              .toString()
              .trim();
      final deviceLabel =
          (activation['deviceLabel'] ?? activation['deviceType'] ?? '')
              .toString()
              .trim();

      softwareDetails.add(
        [
          'Software: ${softwareName.isEmpty ? 'Unknown' : softwareName}',
          if (deviceLabel.isNotEmpty) 'Device: $deviceLabel',
          'Activation Key: $activationKey',
        ].join('\n'),
      );
    }

    final activatedSoftwareNames = branch.softwareActivations
        .map(
          (activation) =>
              (activation['softwareName'] ?? activation['name'] ?? '')
                  .toString()
                  .trim(),
        )
        .toSet();
    for (final software in branch.usedSoftwares) {
      final softwareName = software.trim();
      if (softwareName.isNotEmpty &&
          !activatedSoftwareNames.contains(softwareName)) {
        softwareDetails.add('Software: $softwareName\nActivation Key: ');
      }
    }

    return [
      'Branch $index: ${branch.name}',
      'Branch Address: ${branch.address}',
      'Care Of: ${value(branch.careOf)}',
      'Alternative Phone: ${value(branch.phone2)}',
      'TelePhone: ${branch.phone}',
      'Email: ${value(branch.email)}',
      'Organization Unit name: ${value(branch.organizationUnitName)}',
      'Organization Name: ${value(branch.organizationName)}',
      'Organization Unit (TIN 10 Digit): ${value(branch.taxNumber)}',
      'Common Name: ${value(branch.commonName).isEmpty ? 'Auto' : value(branch.commonName)}',
      'Registered Address: ${value(branch.registeredAddress)}',
      'Business Category: ${value(branch.businessCategory)}',
      'VAT No: ${value(branch.taxNumber)}',
      'Zatca credentials username: ${branch.zatcaUsername ?? ''}',
      'Password: ${branch.zatcaPassword ?? ''}',
      'Building no: ${value(branch.buildingNo)}',
      'Street name: ${value(branch.streetName)}',
      'District Name: ${value(branch.districtName)}',
      'City Name: ${value(branch.cityName)}',
      'zip code: ${value(branch.zipCode)}',
      'Addit No: ${value(branch.additionalNo)}',
      'Unit no: ${value(branch.unitNo)}',
      'Country: ${value(branch.country)}',
      'Cr: ${value(branch.crNumber)}',
      ...softwareDetails,
    ].join('\n');
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? LucideIcons.alertCircle : LucideIcons.checkCircle2,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  String _formatDate(dynamic val, {String placeholder = 'Not specified'}) {
    final dt = _parseDate(val);
    if (dt == null) return placeholder;
    return DateFormat('dd MMM yyyy').format(dt);
  }

  void _sendExpiryAlert(Customer customer, CustomerProvider provider) {
    final buffer = StringBuffer();
    buffer.writeln('Dear ${customer.name},');
    buffer.writeln('');
    buffer.writeln('⚠️ Subscription / Activation Notice');

    if (customer.financialPeriodEndDate != null &&
        customer.financialPeriodEndDate!.trim().isNotEmpty) {
      buffer.writeln(
        '• ZATCA Financial Period End: ${customer.financialPeriodEndDate}',
      );
    }

    for (final sa in customer.softwareActivations) {
      final name = sa['softwareName'] ?? sa['name'] ?? 'Software';
      final exp = sa['expiryDate'];
      if (exp != null && exp.toString().trim().isNotEmpty) {
        buffer.writeln('• $name Expiry: $exp');
      }
    }
    buffer.writeln('');
    buffer.writeln(
      'Please renew your subscription to continue using the service without disruption.',
    );
    buffer.writeln('Thank you,');
    buffer.writeln('ZPro Technology Solutions');

    _launchWhatsApp(customer.phone, customMessage: buffer.toString());
  }

  void _openEditCustomerDialog(Customer customer) {
    Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 900,
      maxHeight: 850,
      child: CreateCustomerScreen(customer: customer),
    ).then((_) {
      if (mounted) {
        context.read<CustomerProvider>().fetchCustomers();
      }
    });
  }

  // ── Build Method ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final customer = _resolveCurrentCustomer(context);
    final customerProvider = context.watch<CustomerProvider>();
    final alertState = customerProvider.getActivationAlertState(customer);
    final isExpired = customerProvider.isActivationExpired(customer);
    final isWarning = alertState == ActivationAlertState.warning;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: _buildAppBar(context, customer, isDark),
      body: Column(
        children: [
          // Hero Profile Card
          _buildHeroHeader(
            customer,
            isDark,
            alertState,
            isExpired,
            isWarning,
            customerProvider,
          ),

          // Tab Navigation Bar
          _buildTabBar(customer, isDark),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(
                  customer,
                  isDark,
                  alertState,
                  isExpired,
                  isWarning,
                ),
                _buildSoftwareTab(customer, isDark, customerProvider),
                _buildBranchesTab(customer, isDark),
                _buildStaffTab(customer, isDark),
                _buildZatcaSecurityTab(customer, isDark),
              ],
            ),
          ),

          // Persistent Action Footer
          _buildActionFooter(customer, isDark),
        ],
      ),
    );
  }

  // ── Header & App Bar ────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Customer customer,
    bool isDark,
  ) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: AppTheme.surfaceBg(context),
      centerTitle: false,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: isDark
              ? FuturisticColors.textPrimary
              : const Color(0xFF334155),
          size: 20,
        ),
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: isDark
                  ? FuturisticColors.textPrimary
                  : const Color(0xFF0F172A),
            ),
          ),
          Text(
            customer.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: isDark
                  ? FuturisticColors.textSecondary
                  : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        // Direct Edit Button
        IconButton(
          icon: Icon(
            LucideIcons.edit3,
            size: 18,
            color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
          ),
          tooltip: 'Edit Customer',
          onPressed: () => _openEditCustomerDialog(customer),
        ),
        // Close Dialog / Screen Button
        IconButton(
          icon: Icon(
            LucideIcons.x,
            size: 19,
            color: isDark
                ? FuturisticColors.textMuted
                : const Color(0xFF64748B),
          ),
          tooltip: 'Close',
          onPressed: () => Navigator.maybePop(context),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: isDark
              ? FuturisticColors.borderSubtle
              : const Color(0xFFE2E8F0),
          height: 1,
        ),
      ),
    );
  }

  // ── Hero Profile Header ─────────────────────────────────────────────────────

  Widget _buildHeroHeader(
    Customer customer,
    bool isDark,
    ActivationAlertState alertState,
    bool isExpired,
    bool isWarning,
    CustomerProvider customerProvider,
  ) {
    final primaryColor = isDark
        ? FuturisticColors.neonCyan
        : const Color(0xFF0D9488);
    final initials = customer.name.trim().isNotEmpty
        ? customer.name
              .trim()
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : 'CU';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? FuturisticColors.borderSubtle
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            FuturisticColors.bgCardHover,
                            const Color(0xFF1E293B),
                          ]
                        : [const Color(0xFFE0F2FE), const Color(0xFFCCFBF1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? FuturisticColors.cyberBorder
                        : primaryColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? FuturisticColors.neonCyan
                        : const Color(0xFF0F766E),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title & Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? FuturisticColors.textPrimary
                                  : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (customer.id.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? FuturisticColors.bgInput
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark
                                    ? FuturisticColors.borderSubtle
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Text(
                              '#${customer.id.length > 8 ? customer.id.substring(customer.id.length - 8) : customer.id}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                color: isDark
                                    ? FuturisticColors.textMuted
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Subtitle (Care Of or Category)
                    if ((customer.careOf ?? '').isNotEmpty ||
                        (customer.businessCategory ?? '').isNotEmpty) ...[
                      Text(
                        [
                          if ((customer.careOf ?? '').isNotEmpty)
                            'C/O: ${customer.careOf}',
                          if ((customer.businessCategory ?? '').isNotEmpty)
                            customer.businessCategory,
                        ].join(' • '),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? FuturisticColors.textSecondary
                              : const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Badges row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // ZATCA Badge
                        _buildStatusBadge(
                          label: customer.zatcaEnabled == true
                              ? 'ZATCA Active'
                              : 'ZATCA Disabled',
                          icon: LucideIcons.shieldCheck,
                          color: customer.zatcaEnabled == true
                              ? (isDark
                                    ? FuturisticColors.neonTeal
                                    : const Color(0xFF10B981))
                              : (isDark
                                    ? FuturisticColors.textMuted
                                    : Colors.grey.shade500),
                          isDark: isDark,
                        ),

                        // Cloud Storage Badge
                        if (customer.cloudStorageEnabled)
                          _buildStatusBadge(
                            label: 'Cloud Active',
                            icon: LucideIcons.cloud,
                            color: isDark
                                ? FuturisticColors.neonCyan
                                : const Color(0xFF0284C7),
                            isDark: isDark,
                          ),

                        // Expiry Status Badge
                        if (isExpired)
                          _buildStatusBadge(
                            label: 'Subscription Expired',
                            icon: LucideIcons.alertTriangle,
                            color: isDark
                                ? FuturisticColors.neonCrimson
                                : const Color(0xFFDC2626),
                            isDark: isDark,
                            isOutlined: false,
                          )
                        else if (isWarning)
                          _buildStatusBadge(
                            label: 'Expiring Soon',
                            icon: LucideIcons.clock,
                            color: isDark
                                ? FuturisticColors.neonAmber
                                : const Color(0xFFD97706),
                            isDark: isDark,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Quick Action Pill Bar
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // WhatsApp
              _buildHeaderActionButton(
                label: 'WhatsApp',
                icon: const FaIcon(
                  FontAwesomeIcons.whatsapp,
                  size: 13,
                  color: Color(0xFF25D366),
                ),
                color: const Color(0xFF25D366),
                isDark: isDark,
                onPressed: () => _launchWhatsApp(customer.phone),
              ),
              // Call
              _buildHeaderActionButton(
                label: customer.phone.isNotEmpty ? customer.phone : 'Call',
                icon: Icon(
                  LucideIcons.phoneCall,
                  size: 13,
                  color: isDark
                      ? FuturisticColors.neonCyan
                      : const Color(0xFF0284C7),
                ),
                color: isDark
                    ? FuturisticColors.neonCyan
                    : const Color(0xFF0284C7),
                isDark: isDark,
                onPressed: () => _launchPhoneCall(customer.phone),
              ),
              // Email
              if ((customer.email ?? '').isNotEmpty)
                _buildHeaderActionButton(
                  label: 'Email',
                  icon: Icon(
                    LucideIcons.mail,
                    size: 13,
                    color: isDark
                        ? FuturisticColors.neonViolet
                        : const Color(0xFF7C3AED),
                  ),
                  color: isDark
                      ? FuturisticColors.neonViolet
                      : const Color(0xFF7C3AED),
                  isDark: isDark,
                  onPressed: () => _launchEmail(customer.email!),
                ),
              // Expiry Alert WhatsApp Quick Action
              if (isExpired || isWarning)
                _buildHeaderActionButton(
                  label: 'Send Expiry Notice',
                  icon: Icon(
                    LucideIcons.send,
                    size: 13,
                    color: isDark
                        ? FuturisticColors.neonCrimson
                        : const Color(0xFFDC2626),
                  ),
                  color: isDark
                      ? FuturisticColors.neonCrimson
                      : const Color(0xFFDC2626),
                  isDark: isDark,
                  onPressed: () => _sendExpiryAlert(customer, customerProvider),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    bool isOutlined = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required String label,
    required Widget icon,
    required Color color,
    required bool isDark,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? color.withValues(alpha: 0.1)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.3 : 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab Bar Navigation ──────────────────────────────────────────────────────

  Widget _buildTabBar(Customer customer, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? FuturisticColors.borderSubtle
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: isDark
            ? FuturisticColors.neonCyan
            : const Color(0xFF0D9488),
        indicatorWeight: 2.5,
        labelColor: isDark
            ? FuturisticColors.neonCyan
            : const Color(0xFF0D9488),
        unselectedLabelColor: isDark
            ? FuturisticColors.textMuted
            : const Color(0xFF64748B),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tabs: [
          const Tab(
            icon: Icon(LucideIcons.layoutGrid, size: 16),
            text: 'Overview',
          ),
          Tab(
            icon: Icon(LucideIcons.box, size: 16),
            text: 'Software (${customer.softwareActivations.length})',
          ),
          Tab(
            icon: Icon(LucideIcons.building2, size: 16),
            text: 'Branches (${customer.branches.length})',
          ),
          Tab(
            icon: Icon(LucideIcons.users, size: 16),
            text: 'Staff (${customer.staff.length})',
          ),
          const Tab(
            icon: Icon(LucideIcons.shieldCheck, size: 16),
            text: 'ZATCA & Security',
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Overview ─────────────────────────────────────────────────────────

  Widget _buildOverviewTab(
    Customer customer,
    bool isDark,
    ActivationAlertState alertState,
    bool isExpired,
    bool isWarning,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat KPI Grid
          _buildMetricsRow(customer, isDark),
          const SizedBox(height: 14),

          // Primary Contact Details Card
          _buildCard(
            context: context,
            title: 'Contact Information',
            icon: LucideIcons.contact2,
            isDark: isDark,
            child: Column(
              children: [
                _buildDetailRow(
                  label: 'Primary Phone',
                  value: customer.phone.isNotEmpty
                      ? customer.phone
                      : 'Not provided',
                  icon: LucideIcons.phone,
                  isDark: isDark,
                  onCopy: customer.phone.isNotEmpty
                      ? () => _copyToClipboard(customer.phone, 'Phone')
                      : null,
                  extraActions: [
                    if (customer.phone.isNotEmpty) ...[
                      IconButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.whatsapp,
                          size: 15,
                          color: Color(0xFF25D366),
                        ),
                        tooltip: 'Message on WhatsApp',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: () => _launchWhatsApp(customer.phone),
                      ),
                      IconButton(
                        icon: Icon(
                          LucideIcons.phoneCall,
                          size: 15,
                          color: isDark
                              ? FuturisticColors.neonCyan
                              : const Color(0xFF0284C7),
                        ),
                        tooltip: 'Call Phone',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: () => _launchPhoneCall(customer.phone),
                      ),
                    ],
                  ],
                ),
                if ((customer.phone2 ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Secondary Phone',
                    value: customer.phone2!,
                    icon: LucideIcons.phone,
                    isDark: isDark,
                    onCopy: () =>
                        _copyToClipboard(customer.phone2!, 'Secondary Phone'),
                    extraActions: [
                      IconButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.whatsapp,
                          size: 15,
                          color: Color(0xFF25D366),
                        ),
                        tooltip: 'Message on WhatsApp',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: () => _launchWhatsApp(customer.phone2!),
                      ),
                      IconButton(
                        icon: Icon(
                          LucideIcons.phoneCall,
                          size: 15,
                          color: isDark
                              ? FuturisticColors.neonCyan
                              : const Color(0xFF0284C7),
                        ),
                        tooltip: 'Call Phone',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: () => _launchPhoneCall(customer.phone2!),
                      ),
                    ],
                  ),
                if ((customer.email ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Email Address',
                    value: customer.email!,
                    icon: LucideIcons.mail,
                    isDark: isDark,
                    onCopy: () => _copyToClipboard(customer.email!, 'Email'),
                    extraActions: [
                      IconButton(
                        icon: Icon(
                          LucideIcons.mail,
                          size: 15,
                          color: isDark
                              ? FuturisticColors.neonViolet
                              : const Color(0xFF7C3AED),
                        ),
                        tooltip: 'Send Email',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: () => _launchEmail(customer.email!),
                      ),
                    ],
                  ),
                if ((customer.address).isNotEmpty)
                  _buildDetailRow(
                    label: 'Main Address',
                    value: customer.address,
                    icon: LucideIcons.mapPin,
                    isDark: isDark,
                    onCopy: () => _copyToClipboard(customer.address, 'Address'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Organization & Tax Registration Card
          _buildCard(
            context: context,
            title: 'Tax & Commercial Details',
            icon: LucideIcons.fileSpreadsheet,
            isDark: isDark,
            child: Column(
              children: [
                _buildDetailRow(
                  label: 'Tax / VAT Number',
                  value: customer.taxNumber.isNotEmpty
                      ? customer.taxNumber
                      : 'Not registered',
                  icon: LucideIcons.hash,
                  isDark: isDark,
                  isHighlighted: customer.taxNumber.isNotEmpty,
                  onCopy: customer.taxNumber.isNotEmpty
                      ? () => _copyToClipboard(customer.taxNumber, 'Tax Number')
                      : null,
                ),
                if ((customer.crNumber ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'CR Number',
                    value: customer.crNumber!,
                    icon: LucideIcons.briefcase,
                    isDark: isDark,
                    onCopy: () =>
                        _copyToClipboard(customer.crNumber!, 'CR Number'),
                  ),
                if ((customer.organizationName ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Organization',
                    value: customer.organizationName!,
                    icon: LucideIcons.building,
                    isDark: isDark,
                  ),
                if ((customer.organizationUnitName ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Org Unit',
                    value: customer.organizationUnitName!,
                    icon: LucideIcons.layers,
                    isDark: isDark,
                  ),
                if ((customer.commonName ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Common Name',
                    value: customer.commonName!,
                    icon: LucideIcons.tag,
                    isDark: isDark,
                  ),
                if ((customer.businessCategory ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Business Category',
                    value: customer.businessCategory!,
                    icon: LucideIcons.bookmark,
                    isDark: isDark,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Financial Periods Card
          _buildCard(
            context: context,
            title: 'Financial & Subscription Periods',
            icon: LucideIcons.calendar,
            isDark: isDark,
            child: Column(
              children: [
                _buildDetailRow(
                  label: 'Financial Period Start',
                  value: _formatDate(customer.financialPeriodStartDate),
                  icon: LucideIcons.calendarCheck2,
                  isDark: isDark,
                ),
                _buildDetailRow(
                  label: 'Financial Period End',
                  value: _formatDate(customer.financialPeriodEndDate),
                  icon: LucideIcons.calendarX2,
                  isDark: isDark,
                  isHighlighted: isExpired,
                  statusNote: isExpired
                      ? 'EXPIRED'
                      : (isWarning ? 'EXPIRING' : null),
                ),
                if ((customer.periodSectionName ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Period Section',
                    value: customer.periodSectionName!,
                    icon: LucideIcons.split,
                    isDark: isDark,
                  ),
                if (customer.cloudStorageEnabled) ...[
                  _buildDetailRow(
                    label: 'Cloud Period Start',
                    value: _formatDate(customer.cloudFinancialPeriodStartDate),
                    icon: LucideIcons.cloud,
                    isDark: isDark,
                  ),
                  _buildDetailRow(
                    label: 'Cloud Period End',
                    value: _formatDate(customer.cloudFinancialPeriodEndDate),
                    icon: LucideIcons.cloudOff,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Audit / Metadata
          _buildCard(
            context: context,
            title: 'Audit & System Records',
            icon: LucideIcons.clock4,
            isDark: isDark,
            child: Column(
              children: [
                _buildDetailRow(
                  label: 'Created At',
                  value: _formatDate(customer.createdAt),
                  icon: LucideIcons.plusCircle,
                  isDark: isDark,
                ),
                if ((customer.createdByName ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Created By',
                    value: customer.createdByName!,
                    icon: LucideIcons.userCheck,
                    isDark: isDark,
                  ),
                if (customer.editedDate != null)
                  _buildDetailRow(
                    label: 'Last Edited',
                    value: _formatDate(customer.editedDate),
                    icon: LucideIcons.edit2,
                    isDark: isDark,
                  ),
                if ((customer.editedByName ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Edited By',
                    value: customer.editedByName!,
                    icon: LucideIcons.userCog,
                    isDark: isDark,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(Customer customer, bool isDark) {
    final activeSoftwares = customer.softwareActivations.length;
    final totalBranches = customer.branches.length;
    final totalStaff =
        customer.staff.length +
        customer.branches.fold<int>(0, (acc, b) => acc + b.staff.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        final cardWidth = isNarrow
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 30) / 4;

        final metrics = [
          _MetricItem(
            label: 'Softwares',
            value: '$activeSoftwares',
            icon: LucideIcons.box,
            color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0284C7),
          ),
          _MetricItem(
            label: 'Branches',
            value: '$totalBranches',
            icon: LucideIcons.building2,
            color: isDark ? FuturisticColors.neonTeal : const Color(0xFF0D9488),
          ),
          _MetricItem(
            label: 'Total Staff',
            value: '$totalStaff',
            icon: LucideIcons.users,
            color: isDark
                ? FuturisticColors.neonViolet
                : const Color(0xFF7C3AED),
          ),
          _MetricItem(
            label: 'ZATCA',
            value: customer.zatcaEnabled == true ? 'Active' : 'Off',
            icon: LucideIcons.shieldCheck,
            color: customer.zatcaEnabled == true
                ? (isDark ? FuturisticColors.neonTeal : const Color(0xFF10B981))
                : (isDark ? FuturisticColors.textMuted : Colors.grey.shade500),
          ),
        ];

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics.map((m) {
            return SizedBox(
              width: cardWidth,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? FuturisticColors.bgCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? FuturisticColors.borderSubtle
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: m.color.withValues(alpha: isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(m.icon, size: 18, color: m.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.value,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? FuturisticColors.textPrimary
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            m.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? FuturisticColors.textSecondary
                                  : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ── Tab 2: Software & Activations ───────────────────────────────────────────

  Widget _buildSoftwareTab(
    Customer customer,
    bool isDark,
    CustomerProvider customerProvider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Used Softwares Chips Card
          if (customer.usedSoftwares.isNotEmpty) ...[
            _buildCard(
              context: context,
              title: 'Registered Software Platforms',
              icon: LucideIcons.layers,
              isDark: isDark,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: customer.usedSoftwares.map((software) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? FuturisticColors.neonCyan.withValues(alpha: 0.12)
                          : const Color(0xFF0D9488).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? FuturisticColors.cyberBorder
                            : const Color(0xFF0D9488).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.checkSquare,
                          size: 13,
                          color: isDark
                              ? FuturisticColors.neonCyan
                              : const Color(0xFF0D9488),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          software,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? FuturisticColors.neonCyan
                                : const Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Software Activations List Header
          Row(
            children: [
              Text(
                'Software Activations & Licenses',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? FuturisticColors.textPrimary
                      : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? FuturisticColors.bgCard
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${customer.softwareActivations.length} Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? FuturisticColors.textSecondary
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Activations Cards
          if (customer.softwareActivations.isEmpty)
            _buildEmptyState(
              icon: LucideIcons.box,
              title: 'No Software Activations Configured',
              subtitle:
                  'Software licenses and keys assigned to this customer will appear here.',
              isDark: isDark,
            )
          else
            ...customer.softwareActivations.map((activation) {
              return _buildSoftwareActivationCard(
                activation,
                customer,
                isDark,
                customerProvider,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSoftwareActivationCard(
    Map<String, dynamic> activation,
    Customer customer,
    bool isDark,
    CustomerProvider customerProvider,
  ) {
    final name =
        activation['softwareName'] ?? activation['name'] ?? 'Software Platform';
    final key =
        activation['activationKey'] ??
        activation['key'] ??
        activation['licenseKey'] ??
        '';
    final actDate = activation['activationDate'] ?? activation['startDate'];
    final expDate = activation['expiryDate'] ?? activation['endDate'];
    final parsedExpDate = _parseDate(expDate);

    final now = DateTime.now();
    final isExpired = parsedExpDate != null && !parsedExpDate.isAfter(now);
    final isExpiringSoon =
        parsedExpDate != null &&
        !isExpired &&
        parsedExpDate.difference(now).inDays <= 30;

    final daysLeft = parsedExpDate?.difference(now).inDays;

    final statusColor = isExpired
        ? (isDark ? FuturisticColors.neonCrimson : const Color(0xFFDC2626))
        : (isExpiringSoon
              ? (isDark ? FuturisticColors.neonAmber : const Color(0xFFD97706))
              : (isDark ? FuturisticColors.neonTeal : const Color(0xFF10B981)));

    final statusText = isExpired
        ? 'EXPIRED'
        : (isExpiringSoon
              ? 'EXPIRING SOON (${daysLeft ?? 0}d left)'
              : (daysLeft != null ? 'ACTIVE (${daysLeft}d left)' : 'ACTIVE'));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired
              ? statusColor.withValues(alpha: 0.4)
              : (isDark
                    ? FuturisticColors.borderSubtle
                    : const Color(0xFFE2E8F0)),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? FuturisticColors.bgSurface
                  : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? FuturisticColors.borderSubtle
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.cpu,
                  size: 16,
                  color: isDark
                      ? FuturisticColors.neonCyan
                      : const Color(0xFF0D9488),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? FuturisticColors.textPrimary
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Card Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (key.toString().isNotEmpty)
                  _buildDetailRow(
                    label: 'Activation Key',
                    value: key.toString(),
                    icon: LucideIcons.keyRound,
                    isDark: isDark,
                    isMonospace: true,
                    onCopy: () =>
                        _copyToClipboard(key.toString(), 'Activation Key'),
                  ),
                _buildDetailRow(
                  label: 'Activated On',
                  value: _formatDate(actDate),
                  icon: LucideIcons.calendarCheck2,
                  isDark: isDark,
                ),
                _buildDetailRow(
                  label: 'Expires On',
                  value: _formatDate(expDate),
                  icon: LucideIcons.calendarX2,
                  isDark: isDark,
                  isHighlighted: isExpired || isExpiringSoon,
                ),

                // Additional details
                if (activation['devicesCount'] != null ||
                    activation['machineId'] != null)
                  _buildDetailRow(
                    label: 'Machine / Devices',
                    value: [
                      if (activation['devicesCount'] != null)
                        '${activation['devicesCount']} devices',
                      if (activation['machineId'] != null)
                        'ID: ${activation['machineId']}',
                    ].join(' • '),
                    icon: LucideIcons.monitor,
                    isDark: isDark,
                  ),

                if ((activation['notes'] ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Notes',
                    value: activation['notes'].toString(),
                    icon: LucideIcons.fileText,
                    isDark: isDark,
                  ),

                // Send Expiry Notice button if expired or warning
                if (isExpired || isExpiringSoon) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final msg =
                            'Dear ${customer.name},\n\n'
                            'Your subscription for "$name" expired/expires on ${_formatDate(expDate)}.\n'
                            'Please contact us to renew your activation key.\n\n'
                            'ZPro Technology Solutions';
                        _launchWhatsApp(customer.phone, customMessage: msg);
                      },
                      icon: const FaIcon(
                        FontAwesomeIcons.whatsapp,
                        size: 14,
                        color: Color(0xFF25D366),
                      ),
                      label: const Text(
                        'Send Renewal Alert',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? FuturisticColors.neonCyan
                            : const Color(0xFF0D9488),
                        side: BorderSide(
                          color: isDark
                              ? FuturisticColors.borderSubtle
                              : const Color(0xFFCBD5E1),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Branches & Locations ─────────────────────────────────────────────

  Widget _buildBranchesTab(Customer customer, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Head Office Primary Address Breakdown Card
          _buildCard(
            context: context,
            title: 'Head Office Address Details',
            icon: LucideIcons.mapPin,
            isDark: isDark,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(
                      _customerAddressDetails(customer),
                      'Customer address details',
                    ),
                    icon: const Icon(LucideIcons.copy, size: 15),
                    label: const Text('Copy Address Details'),
                  ),
                ),
                const SizedBox(height: 6),
                if (customer.address.isNotEmpty)
                  _buildDetailRow(
                    label: 'Address Line',
                    value: customer.address,
                    icon: LucideIcons.home,
                    isDark: isDark,
                    onCopy: () => _copyToClipboard(customer.address, 'Address'),
                  ),
                if ((customer.registeredAddress ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Registered Address',
                    value: customer.registeredAddress!,
                    icon: LucideIcons.building,
                    isDark: isDark,
                    onCopy: () => _copyToClipboard(
                      customer.registeredAddress!,
                      'Registered Address',
                    ),
                  ),
                if ((customer.buildingNo ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Building No.',
                    value: customer.buildingNo!,
                    icon: LucideIcons.hash,
                    isDark: isDark,
                  ),
                if ((customer.streetName ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Street Name',
                    value: customer.streetName!,
                    icon: LucideIcons.compass,
                    isDark: isDark,
                  ),
                if ((customer.districtName ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'District',
                    value: customer.districtName!,
                    icon: LucideIcons.map,
                    isDark: isDark,
                  ),
                if ((customer.cityName ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'City',
                    value: customer.cityName!,
                    icon: LucideIcons.navigation,
                    isDark: isDark,
                  ),
                if ((customer.zipCode ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'ZIP / Postal Code',
                    value: customer.zipCode!,
                    icon: LucideIcons.mailCheck,
                    isDark: isDark,
                  ),
                if ((customer.additionalNo ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Additional No.',
                    value: customer.additionalNo!,
                    icon: LucideIcons.plus,
                    isDark: isDark,
                  ),
                if ((customer.unitNo ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Unit No.',
                    value: customer.unitNo!,
                    icon: LucideIcons.doorOpen,
                    isDark: isDark,
                  ),
                if ((customer.country ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Country',
                    value: customer.country!,
                    icon: LucideIcons.globe,
                    isDark: isDark,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Branches List Section
          Row(
            children: [
              Text(
                'Customer Branches',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? FuturisticColors.textPrimary
                      : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? FuturisticColors.bgCard
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${customer.branches.length} Branches',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? FuturisticColors.textSecondary
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (customer.branches.isEmpty)
            _buildEmptyState(
              icon: LucideIcons.building2,
              title: 'No Branches Registered',
              subtitle:
                  'Additional branch locations with separate addresses or staff will appear here.',
              isDark: isDark,
            )
          else
            ...customer.branches.asMap().entries.map((entry) {
              final idx = entry.key;
              final branch = entry.value;
              return _buildBranchCard(customer, branch, idx + 1, isDark);
            }),
        ],
      ),
    );
  }

  Widget _buildBranchCard(
    Customer customer,
    Branch branch,
    int index,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? FuturisticColors.borderSubtle
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branch Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? FuturisticColors.bgSurface
                  : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? FuturisticColors.borderSubtle
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color:
                        (isDark
                                ? FuturisticColors.neonTeal
                                : const Color(0xFF0D9488))
                            .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? FuturisticColors.neonTeal
                          : const Color(0xFF0D9488),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    branch.name.isNotEmpty ? branch.name : 'Branch #$index',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? FuturisticColors.textPrimary
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BranchDetailsScreen(
                          branch: branch,
                          branchIndex: index,
                          parentCustomer: _resolveCurrentCustomer(context),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.externalLink, size: 17),
                  tooltip: 'View branch details',
                  visualDensity: VisualDensity.compact,
                ),
                if (branch.zatcaEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isDark
                                  ? FuturisticColors.neonTeal
                                  : const Color(0xFF10B981))
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ZATCA ON',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? FuturisticColors.neonTeal
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Branch Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(
                      _branchAddressDetails(branch, index),
                      'Branch address details',
                    ),
                    icon: const Icon(LucideIcons.copy, size: 15),
                    label: const Text('Copy Address Details'),
                  ),
                ),
                const SizedBox(height: 6),
                if (branch.phone.isNotEmpty)
                  _buildDetailRow(
                    label: 'Branch Phone',
                    value: branch.phone,
                    icon: LucideIcons.phone,
                    isDark: isDark,
                    onCopy: () =>
                        _copyToClipboard(branch.phone, 'Branch Phone'),
                    extraActions: [
                      IconButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.whatsapp,
                          size: 14,
                          color: Color(0xFF25D366),
                        ),
                        tooltip: 'WhatsApp',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                        onPressed: () => _launchWhatsApp(branch.phone),
                      ),
                      IconButton(
                        icon: Icon(
                          LucideIcons.phoneCall,
                          size: 14,
                          color: isDark
                              ? FuturisticColors.neonCyan
                              : const Color(0xFF0284C7),
                        ),
                        tooltip: 'Call',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                        onPressed: () => _launchPhoneCall(branch.phone),
                      ),
                    ],
                  ),
                if (branch.address.isNotEmpty)
                  _buildDetailRow(
                    label: 'Branch Address',
                    value: branch.address,
                    icon: LucideIcons.mapPin,
                    isDark: isDark,
                    onCopy: () =>
                        _copyToClipboard(branch.address, 'Branch Address'),
                  ),

                // Branch Staff summary
                if (branch.staff.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? FuturisticColors.bgInput
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Branch Personnel (${branch.staff.length})',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? FuturisticColors.textSecondary
                                : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...branch.staff.map((s) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.user,
                                  size: 13,
                                  color: isDark
                                      ? FuturisticColors.neonCyan
                                      : const Color(0xFF0D9488),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  s.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? FuturisticColors.textPrimary
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                                const Spacer(),
                                if (s.phone.isNotEmpty)
                                  InkWell(
                                    onTap: () => _launchWhatsApp(s.phone),
                                    child: Text(
                                      s.phone,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontFamily: 'monospace',
                                        color: isDark
                                            ? FuturisticColors.neonCyan
                                            : const Color(0xFF0284C7),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],

                // Branch Softwares
                if (branch.usedSoftwares.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: branch.usedSoftwares.map((sw) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? FuturisticColors.bgInput
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sw,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark
                                ? FuturisticColors.textSecondary
                                : const Color(0xFF475569),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Staff Directory ──────────────────────────────────────────────────

  Widget _buildStaffTab(Customer customer, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Organization Staff
          Row(
            children: [
              Text(
                'Primary Customer Personnel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? FuturisticColors.textPrimary
                      : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? FuturisticColors.bgCard
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${customer.staff.length} Staff',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? FuturisticColors.textSecondary
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (customer.staff.isEmpty)
            _buildEmptyState(
              icon: LucideIcons.users,
              title: 'No Main Staff Registered',
              subtitle:
                  'Staff members associated with the main organization will appear here.',
              isDark: isDark,
            )
          else
            ...customer.staff.map((staffMember) {
              return _buildStaffMemberCard(
                staffMember,
                isDark,
                branchName: null,
              );
            }),

          // Branch Staff Members Section
          if (customer.branches.any((b) => b.staff.isNotEmpty)) ...[
            const SizedBox(height: 16),
            Text(
              'Branch Staff Members',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? FuturisticColors.textPrimary
                    : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            ...customer.branches.where((b) => b.staff.isNotEmpty).expand((b) {
              return b.staff.map((staffMember) {
                return _buildStaffMemberCard(
                  staffMember,
                  isDark,
                  branchName: b.name,
                );
              });
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildStaffMemberCard(Staff staff, bool isDark, {String? branchName}) {
    final initials = staff.name.trim().isNotEmpty
        ? staff.name
              .trim()
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : 'S';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgCard : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? FuturisticColors.borderSubtle
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Mini avatar
          CircleAvatar(
            radius: 18,
            backgroundColor:
                (isDark ? FuturisticColors.neonViolet : const Color(0xFF7C3AED))
                    .withValues(alpha: 0.15),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? FuturisticColors.neonViolet
                    : const Color(0xFF7C3AED),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name and branch
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.name.isNotEmpty ? staff.name : 'Unnamed Staff Member',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? FuturisticColors.textPrimary
                        : const Color(0xFF0F172A),
                  ),
                ),
                if (branchName != null && branchName.isNotEmpty)
                  Text(
                    'Branch: $branchName',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? FuturisticColors.neonCyan
                          : const Color(0xFF0D9488),
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else if (staff.phone.isNotEmpty)
                  Text(
                    staff.phone,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: isDark
                          ? FuturisticColors.textSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),

          // Actions
          if (staff.phone.isNotEmpty) ...[
            IconButton(
              icon: const FaIcon(
                FontAwesomeIcons.whatsapp,
                size: 15,
                color: Color(0xFF25D366),
              ),
              tooltip: 'WhatsApp',
              onPressed: () => _launchWhatsApp(staff.phone),
            ),
            IconButton(
              icon: Icon(
                LucideIcons.phoneCall,
                size: 15,
                color: isDark
                    ? FuturisticColors.neonCyan
                    : const Color(0xFF0284C7),
              ),
              tooltip: 'Call',
              onPressed: () => _launchPhoneCall(staff.phone),
            ),
            IconButton(
              icon: Icon(
                LucideIcons.copy,
                size: 14,
                color: isDark
                    ? FuturisticColors.textMuted
                    : const Color(0xFF94A3B8),
              ),
              tooltip: 'Copy Phone',
              onPressed: () =>
                  _copyToClipboard(staff.phone, '${staff.name} Phone'),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab 5: ZATCA & Security ─────────────────────────────────────────────────

  Widget _buildZatcaSecurityTab(Customer customer, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ZATCA Integration Status Card
          _buildCard(
            context: context,
            title: 'ZATCA Phase-2 Integration',
            icon: LucideIcons.shieldCheck,
            isDark: isDark,
            child: Column(
              children: [
                _buildDetailRow(
                  label: 'Integration Status',
                  value: customer.zatcaEnabled == true
                      ? 'Phase 2 Enabled'
                      : 'Disabled / Standalone',
                  icon: LucideIcons.power,
                  isDark: isDark,
                  isHighlighted: customer.zatcaEnabled == true,
                  statusNote: customer.zatcaEnabled == true ? 'ACTIVE' : 'OFF',
                ),
                _buildDetailRow(
                  label: 'Tax / VAT Identification',
                  value: customer.taxNumber.isNotEmpty
                      ? customer.taxNumber
                      : 'Not registered',
                  icon: LucideIcons.hash,
                  isDark: isDark,
                  onCopy: customer.taxNumber.isNotEmpty
                      ? () => _copyToClipboard(customer.taxNumber, 'VAT Number')
                      : null,
                ),
                if ((customer.crNumber ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Commercial Registration (CR)',
                    value: customer.crNumber!,
                    icon: LucideIcons.fileCheck,
                    isDark: isDark,
                    onCopy: () =>
                        _copyToClipboard(customer.crNumber!, 'CR Number'),
                  ),
                if ((customer.periodSectionName ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Period Section',
                    value: customer.periodSectionName!,
                    icon: LucideIcons.folderKanban,
                    isDark: isDark,
                  ),
                if ((customer.periodSectionId ?? '').isNotEmpty)
                  _buildDetailRow(
                    label: 'Period Section ID',
                    value: customer.periodSectionId!,
                    icon: LucideIcons.fingerprint,
                    isDark: isDark,
                    isMonospace: true,
                    onCopy: () => _copyToClipboard(
                      customer.periodSectionId!,
                      'Section ID',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ZATCA Credentials Card
          _buildCard(
            context: context,
            title: 'ZATCA API Credentials',
            icon: LucideIcons.key,
            isDark: isDark,
            child: Column(
              children: [
                _buildDetailRow(
                  label: 'ZATCA Username',
                  value: (customer.zatcaUsername ?? '').isNotEmpty
                      ? customer.zatcaUsername!
                      : 'Not configured',
                  icon: LucideIcons.user,
                  isDark: isDark,
                  isMonospace: true,
                  onCopy: (customer.zatcaUsername ?? '').isNotEmpty
                      ? () => _copyToClipboard(
                          customer.zatcaUsername!,
                          'ZATCA Username',
                        )
                      : null,
                ),
                _buildDetailRow(
                  label: 'ZATCA Password / Secret',
                  value: (customer.zatcaPassword ?? '').isNotEmpty
                      ? (_obscureZatcaPassword
                            ? '••••••••••••••••'
                            : customer.zatcaPassword!)
                      : 'Not configured',
                  icon: LucideIcons.lock,
                  isDark: isDark,
                  isMonospace: true,
                  extraActions: [
                    if ((customer.zatcaPassword ?? '').isNotEmpty) ...[
                      IconButton(
                        icon: Icon(
                          _obscureZatcaPassword
                              ? LucideIcons.eye
                              : LucideIcons.eyeOff,
                          size: 15,
                          color: isDark
                              ? FuturisticColors.neonCyan
                              : const Color(0xFF0D9488),
                        ),
                        tooltip: _obscureZatcaPassword
                            ? 'Reveal Password'
                            : 'Hide Password',
                        onPressed: () {
                          setState(() {
                            _obscureZatcaPassword = !_obscureZatcaPassword;
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          LucideIcons.copy,
                          size: 14,
                          color: isDark
                              ? FuturisticColors.textMuted
                              : const Color(0xFF94A3B8),
                        ),
                        tooltip: 'Copy Password',
                        onPressed: () => _copyToClipboard(
                          customer.zatcaPassword!,
                          'ZATCA Password',
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Cloud Storage Configuration
          _buildCard(
            context: context,
            title: 'Cloud Storage & Sync',
            icon: LucideIcons.cloud,
            isDark: isDark,
            child: Column(
              children: [
                _buildDetailRow(
                  label: 'Cloud Sync',
                  value: customer.cloudStorageEnabled ? 'Active' : 'Disabled',
                  icon: LucideIcons.refreshCw,
                  isDark: isDark,
                  isHighlighted: customer.cloudStorageEnabled,
                ),
                if (customer.cloudStorageEnabled) ...[
                  _buildDetailRow(
                    label: 'Cloud Period Start',
                    value: _formatDate(customer.cloudFinancialPeriodStartDate),
                    icon: LucideIcons.calendar,
                    isDark: isDark,
                  ),
                  _buildDetailRow(
                    label: 'Cloud Period End',
                    value: _formatDate(customer.cloudFinancialPeriodEndDate),
                    icon: LucideIcons.calendarCheck,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Action Footer ────────────────────────────────────────────────────

  Widget _buildActionFooter(Customer customer, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? FuturisticColors.borderSubtle
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 600;

            final paymentBtn = ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    insetPadding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: 600,
                      height: 900,
                      child: CustomerwiseMakeTransactionScreen(
                        customer: customer,
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(LucideIcons.wallet, size: 16),
              label: const Text(
                'Make Payment',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? FuturisticColors.neonCyan
                    : const Color(0xFF0D9488),
                foregroundColor: isDark
                    ? const Color(0xFF070B14)
                    : Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            );

            final transactionsBtn = OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    insetPadding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: 650,
                      height: 900,
                      child: CustomerTransactionsListScreen(
                        customerName: customer.name,
                        customerId: customer.id,
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(LucideIcons.receipt, size: 16),
              label: const Text(
                'Transactions',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark
                    ? FuturisticColors.textPrimary
                    : const Color(0xFF1E293B),
                side: BorderSide(
                  color: isDark
                      ? FuturisticColors.borderSubtle
                      : const Color(0xFFCBD5E1),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );

            final servicesBtn = OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    insetPadding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: 650,
                      height: 900,
                      child: CustomerBasedServicesListScreen(
                        customer: customer,
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(LucideIcons.wrench, size: 16),
              label: const Text(
                'Services',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark
                    ? FuturisticColors.textPrimary
                    : const Color(0xFF1E293B),
                side: BorderSide(
                  color: isDark
                      ? FuturisticColors.borderSubtle
                      : const Color(0xFFCBD5E1),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );

            if (isSmall) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: double.infinity, child: paymentBtn),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: transactionsBtn),
                      const SizedBox(width: 8),
                      Expanded(child: servicesBtn),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: paymentBtn),
                const SizedBox(width: 10),
                Expanded(child: transactionsBtn),
                const SizedBox(width: 10),
                Expanded(child: servicesBtn),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Reusable Component Helpers ──────────────────────────────────────────────

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? FuturisticColors.borderSubtle
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? FuturisticColors.bgSurface
                  : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? FuturisticColors.borderSubtle
                      : const Color(0xFFE2E8F0),
                ),
              ),
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
          // Card Content
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    bool isHighlighted = false,
    bool isMonospace = false,
    String? statusNote,
    VoidCallback? onCopy,
    List<Widget>? extraActions,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Label with icon
          SizedBox(
            width: 140,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: isDark
                      ? FuturisticColors.textMuted
                      : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? FuturisticColors.textSecondary
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Value
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontFamily: isMonospace ? 'monospace' : null,
                fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                color: isHighlighted
                    ? (isDark
                          ? FuturisticColors.neonCyan
                          : const Color(0xFF0F766E))
                    : (isDark
                          ? FuturisticColors.textPrimary
                          : const Color(0xFF1E293B)),
              ),
            ),
          ),

          // Status note pill
          if (statusNote != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusNote == 'EXPIRED'
                    ? (isDark
                              ? FuturisticColors.neonCrimson
                              : const Color(0xFFDC2626))
                          .withValues(alpha: 0.15)
                    : (isDark
                              ? FuturisticColors.neonTeal
                              : const Color(0xFF10B981))
                          .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusNote,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusNote == 'EXPIRED'
                      ? (isDark
                            ? FuturisticColors.neonCrimson
                            : const Color(0xFFDC2626))
                      : (isDark
                            ? FuturisticColors.neonTeal
                            : const Color(0xFF10B981)),
                ),
              ),
            ),
          ],

          // Copy button
          if (onCopy != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                LucideIcons.copy,
                size: 13.5,
                color: isDark
                    ? FuturisticColors.textMuted
                    : const Color(0xFF94A3B8),
              ),
              tooltip: 'Copy',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: onCopy,
            ),
          ],

          // Extra action buttons
          if (extraActions != null) ...extraActions,
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? FuturisticColors.borderSubtle
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:
                  (isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488))
                      .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 22,
              color: isDark
                  ? FuturisticColors.neonCyan
                  : const Color(0xFF0D9488),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? FuturisticColors.textPrimary
                  : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? FuturisticColors.textSecondary
                  : const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MetricItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
