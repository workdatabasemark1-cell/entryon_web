import 'package:entryon/models/customer_model.dart';
import 'package:entryon/models/supplier_model.dart';
import 'package:entryon/providers/customer_provider.dart';
import 'package:entryon/providers/supplier_provider.dart';
import 'package:entryon/views/createCustomerScreen.dart';
import 'package:entryon/views/createSupplierScreen.dart';
import 'package:entryon/views/branchDetailsScreen.dart';
import 'package:entryon/views/customerDetailsScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:entryon/utils/app_theme.dart';
import 'package:entryon/utils/responsive.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'editSupplierScreen.dart';

// ── Constants ────────────────────────────────────────────────────────────────

abstract class _K {
  static const customerColor = Colors.blue;
  static const supplierColor = Colors.green;
  static const cardRadius = 10.0;
}

enum ViewMode { grid, table }

// ─────────────────────────────────────────────────────────────────────────────

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  final _customerSearch = TextEditingController();
  final _supplierSearch = TextEditingController();

  ViewMode _viewMode = ViewMode.grid;

  String _zatcaExpiryFilter = 'All';
  String _softwareExpiryFilter = 'All';
  String _softwareFilter = 'All';
  DateTime? _zatcaExpiryFromDate;
  DateTime? _zatcaExpiryToDate;
  DateTime? _softwareExpiryFromDate;
  DateTime? _softwareExpiryToDate;

  // Cached supplier filtering state
  List<Supplier>? _filteredSuppliers;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().fetchCustomers();
      context.read<SupplierProvider>().fetchSuppliers();
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _customerSearch.dispose();
    _supplierSearch.dispose();
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  void _filterCustomers(String q) {
    setState(() {});
  }

  List<Customer> _filteredCustomerList(List<Customer> customers) {
    final query = _customerSearch.text.trim().toLowerCase();
    return customers.where((customer) {
      final matchesSearch =
          query.isEmpty ||
          customer.name.toLowerCase().contains(query) ||
          customer.phone.contains(query) ||
          customer.taxNumber.toLowerCase().contains(query) ||
          (customer.cityName?.toLowerCase().contains(query) ?? false) ||
          (customer.organizationName?.toLowerCase().contains(query) ?? false);
      return matchesSearch &&
          _matchesCustomerExpiry(customer, _zatcaExpiryFilter, zatca: true) &&
          _matchesCustomerExpiry(
            customer,
            _softwareExpiryFilter,
            zatca: false,
          ) &&
          _matchesExpiryDateRange(
            customer,
            _zatcaExpiryFromDate,
            _zatcaExpiryToDate,
            zatca: true,
          ) &&
          _matchesExpiryDateRange(
            customer,
            _softwareExpiryFromDate,
            _softwareExpiryToDate,
            zatca: false,
          ) &&
          (_softwareFilter == 'All' ||
              customer.usedSoftwares.contains(_softwareFilter));
    }).toList();
  }

  bool _matchesExpiryDateRange(
    Customer customer,
    DateTime? fromDate,
    DateTime? toDate, {
    required bool zatca,
  }) {
    if (fromDate == null || toDate == null) return true;

    final provider = context.read<CustomerProvider>();
    final expiryDates = zatca
        ? [provider.parseActivationDate(customer.financialPeriodEndDate)]
        : customer.softwareActivations
              .map(
                (activation) =>
                    provider.parseActivationDate(activation['expiryDate']),
              )
              .toList();
    return expiryDates.whereType<DateTime>().any(
      (date) => !date.isBefore(fromDate) && !date.isAfter(toDate),
    );
  }

  Future<void> _pickExpiryDateRange({required bool zatca}) async {
    final currentFrom = zatca ? _zatcaExpiryFromDate : _softwareExpiryFromDate;
    final currentTo = zatca ? _zatcaExpiryToDate : _softwareExpiryToDate;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: currentFrom != null && currentTo != null
          ? DateTimeRange(start: currentFrom, end: currentTo)
          : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF0D9488),
            onPrimary: Colors.white,
            onSurface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;

    final startTime = await showTimePicker(
      context: context,
      initialTime: currentFrom != null
          ? TimeOfDay.fromDateTime(currentFrom)
          : const TimeOfDay(hour: 0, minute: 0),
    );
    if (startTime == null || !mounted) return;

    final endTime = await showTimePicker(
      context: context,
      initialTime: currentTo != null
          ? TimeOfDay.fromDateTime(currentTo)
          : const TimeOfDay(hour: 23, minute: 59),
    );
    if (endTime == null || !mounted) return;

    final startDateTime = DateTime(
      picked.start.year,
      picked.start.month,
      picked.start.day,
      startTime.hour,
      startTime.minute,
    );
    final endDateTime = DateTime(
      picked.end.year,
      picked.end.month,
      picked.end.day,
      endTime.hour,
      endTime.minute,
    );

    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'End date and time must be after the start date and time.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      if (zatca) {
        _zatcaExpiryFromDate = startDateTime;
        _zatcaExpiryToDate = endDateTime;
      } else {
        _softwareExpiryFromDate = startDateTime;
        _softwareExpiryToDate = endDateTime;
      }
    });
  }

  bool _matchesCustomerExpiry(
    Customer customer,
    String filter, {
    required bool zatca,
  }) {
    if (filter == 'All') return true;
    final provider = context.read<CustomerProvider>();
    final now = DateTime.now();
    final warningEnd = now.add(const Duration(days: 2));
    final dates = zatca
        ? [provider.parseActivationDate(customer.financialPeriodEndDate)]
        : customer.softwareActivations
              .map(
                (activation) =>
                    provider.parseActivationDate(activation['expiryDate']),
              )
              .toList();
    final validDates = dates.whereType<DateTime>();

    if (filter == 'Expired') {
      return validDates.any((date) => !date.isAfter(now));
    }
    if (filter == 'Expiring soon') {
      return validDates.any(
        (date) => date.isAfter(now) && !date.isAfter(warningEnd),
      );
    }
    return validDates.isNotEmpty &&
        validDates.every((date) => date.isAfter(warningEnd));
  }

  Widget _buildCustomerFilterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.inputBg(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(value) ? value : 'All',
          icon: Icon(
            LucideIcons.chevronDown,
            size: 14,
            color: AppTheme.textSecondary(context),
          ),
          style: TextStyle(fontSize: 12, color: AppTheme.textPrimary(context)),
          onChanged: (selected) {
            if (selected != null) onChanged(selected);
          },
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option == 'All' ? label : option),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildExpiryDateRangeButton({required bool zatca}) {
    final fromDate = zatca ? _zatcaExpiryFromDate : _softwareExpiryFromDate;
    final toDate = zatca ? _zatcaExpiryToDate : _softwareExpiryToDate;
    final hasRange = fromDate != null && toDate != null;
    final label = hasRange
        ? '${DateFormat('dd MMM yy, hh:mm a').format(fromDate)} - '
              '${DateFormat('dd MMM yy, hh:mm a').format(toDate)}'
        : zatca
        ? 'ZATCA date & time'
        : 'Software date & time';

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: hasRange
            ? AppTheme.accent(context).withValues(alpha: 0.10)
            : AppTheme.inputBg(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasRange
              ? AppTheme.accent(context).withValues(alpha: 0.35)
              : AppTheme.cardBorderColor(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _pickExpiryDateRange(zatca: zatca),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.calendarRange,
                    size: 14,
                    color: hasRange
                        ? AppTheme.accent(context)
                        : AppTheme.textSecondary(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: hasRange ? FontWeight.w700 : FontWeight.w500,
                      color: hasRange
                          ? AppTheme.accent(context)
                          : AppTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasRange)
            IconButton(
              onPressed: () => setState(() {
                if (zatca) {
                  _zatcaExpiryFromDate = null;
                  _zatcaExpiryToDate = null;
                } else {
                  _softwareExpiryFromDate = null;
                  _softwareExpiryToDate = null;
                }
              }),
              icon: const Icon(LucideIcons.x, size: 13),
              color: AppTheme.textSecondary(context),
              tooltip: 'Clear expiry date range',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerFilterBar(
    List<Customer> customers, {
    required int filteredCustomerCount,
  }) {
    return Container(
      width: double.infinity,
      color: AppTheme.surfaceBg(context),
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.accent(context).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.accent(context).withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                '$filteredCustomerCount ${filteredCustomerCount == 1 ? 'customer' : 'customers'}'
                ' • ${_filteredCustomerList(customers).fold<int>(0, (count, customer) => count + customer.branches.length)} '
                '${_filteredCustomerList(customers).fold<int>(0, (count, customer) => count + customer.branches.length) == 1 ? 'branch' : 'branches'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent(context),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _buildCustomerFilterDropdown(
              label: 'ZATCA expiry',
              value: _zatcaExpiryFilter,
              options: const ['All', 'Expired', 'Expiring soon', 'Active'],
              onChanged: (value) => setState(() => _zatcaExpiryFilter = value),
            ),
            const SizedBox(width: 6),
            _buildCustomerFilterDropdown(
              label: 'Software expiry',
              value: _softwareExpiryFilter,
              options: const ['All', 'Expired', 'Expiring soon', 'Active'],
              onChanged: (value) =>
                  setState(() => _softwareExpiryFilter = value),
            ),
            const SizedBox(width: 6),
            _buildExpiryDateRangeButton(zatca: true),
            const SizedBox(width: 6),
            _buildExpiryDateRangeButton(zatca: false),
            const SizedBox(width: 6),
            _buildCustomerFilterDropdown(
              label: 'Software',
              value: _softwareFilter,
              options: _softwareFilterOptions(customers),
              onChanged: (value) => setState(() => _softwareFilter = value),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _softwareFilterOptions(List<Customer> customers) {
    final software =
        customers
            .expand((customer) => customer.usedSoftwares)
            .where((name) => name.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...software];
  }

  void _filterSuppliers(String q) {
    final all = context.read<SupplierProvider>().suppliers;
    setState(() {
      _filteredSuppliers = q.isEmpty
          ? null
          : all
                .where(
                  (s) =>
                      s.name.toLowerCase().contains(q.toLowerCase()) ||
                      s.phone.contains(q) ||
                      s.vatNumber.toLowerCase().contains(q.toLowerCase()) ||
                      (s.address?.toLowerCase().contains(q.toLowerCase()) ??
                          false),
                )
                .toList();
    });
  }

  // ── Deletion ──────────────────────────────────────────────────────────────

  Future<void> _confirmDelete({
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
    required String successMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await onConfirm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF0D9488),
          ),
        );
      }
    }
  }

  void _deleteCustomer(String id) => _confirmDelete(
    title: 'Delete Customer',
    message: 'Are you sure you want to delete this customer record?',
    onConfirm: () => context.read<CustomerProvider>().deleteCustomer(id),
    successMessage: 'Customer deleted successfully',
  );

  void _deleteSupplier(String id) => _confirmDelete(
    title: 'Delete Supplier',
    message: 'Are you sure you want to delete this supplier record?',
    onConfirm: () => context.read<SupplierProvider>().deleteSupplier(id),
    successMessage: 'Supplier deleted successfully',
  );

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _openCreateCustomerDialog() {
    Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 900,
      maxHeight: 850,
      child: const CreateCustomerScreen(),
    ).then((_) {
      if (mounted) {
        context.read<CustomerProvider>().fetchCustomers();
      }
    });
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

  void _openCustomerDetailsDialog(Customer customer) {
    Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 850,
      maxHeight: 850,
      child: CustomerDetailsScreen(customer: customer),
    );
  }

  void _openBranchDetails(
    Branch branch,
    int branchIndex,
    Customer parentCustomer,
  ) {
    Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 850,
      maxHeight: 850,
      child: BranchDetailsScreen(
        branch: branch,
        branchIndex: branchIndex,
        parentCustomer: parentCustomer,
      ),
    );
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (_) => BranchDetailsScreen(
    //       branch: branch,
    //       branchIndex: branchIndex,
    //     ),
    //   ),
    // );
  }

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

  Future<void> _sendExpiredAlertWhatsApp(
    Customer customer,
    ActivationAlertState alertState,
  ) async {
    final rawPhone = customer.phone.trim();
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer does not have a phone number.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final phone = _normalizePhoneForWhatsApp(rawPhone);
    final alertReason = _alertMessage(alertState);

    final buffer = StringBuffer();
    buffer.writeln('Dear ${customer.name},');
    buffer.writeln('');
    buffer.writeln('⚠️ Alert: $alertReason');
    if (customer.financialPeriodEndDate != null &&
        customer.financialPeriodEndDate!.trim().isNotEmpty) {
      buffer.writeln('• ZATCA Expiry: ${customer.financialPeriodEndDate}');
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
      'Please renew your activation/subscription to continue using the service without disruption.',
    );
    buffer.writeln('Thank you,');
    buffer.writeln('ZPro Technology Solutions');

    final urlString =
        'https://wa.me/$phone?text=${Uri.encodeComponent(buffer.toString())}';
    final uri = Uri.parse(urlString);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch WhatsApp: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _sendExpiredBranchAlertWhatsApp(
    Branch branch,
    String customerName,
    Customer? parent,
    ActivationAlertState alertState,
  ) async {
    final rawPhone = branch.phone.trim().isNotEmpty
        ? branch.phone.trim()
        : (parent?.phone.trim() ?? '');
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Branch does not have a phone number.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final phone = _normalizePhoneForWhatsApp(rawPhone);
    final alertReason = _alertMessage(alertState);

    final buffer = StringBuffer();
    buffer.writeln(
      'Dear $customerName (${branch.name.isNotEmpty ? branch.name : "Branch"}),',
    );
    buffer.writeln('');
    buffer.writeln('⚠️ Alert: $alertReason');
    if (branch.financialPeriodEndDate != null &&
        branch.financialPeriodEndDate!.trim().isNotEmpty) {
      buffer.writeln('• ZATCA Expiry: ${branch.financialPeriodEndDate}');
    }
    for (final sa in branch.softwareActivations) {
      final name = sa['softwareName'] ?? sa['name'] ?? 'Software';
      final exp = sa['expiryDate'];
      if (exp != null && exp.toString().trim().isNotEmpty) {
        buffer.writeln('• $name Expiry: $exp');
      }
    }
    buffer.writeln('');
    buffer.writeln(
      'Please renew your activation/subscription to continue using the service without disruption.',
    );
    buffer.writeln('Thank you,');
    buffer.writeln('ZPro Technology Solutions');

    final urlString =
        'https://wa.me/$phone?text=${Uri.encodeComponent(buffer.toString())}';
    final uri = Uri.parse(urlString);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch WhatsApp: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openCreateSupplierDialog() {
    Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 550,
      maxHeight: 700,
      child: const CreateSupplierScreen(),
    ).then((_) {
      if (mounted) {
        context.read<SupplierProvider>().fetchSuppliers();
      }
    });
  }

  void _openEditSupplierDialog(Supplier supplier) {
    Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 550,
      maxHeight: 700,
      child: EditSupplierScreen(supplier: supplier),
    ).then((_) {
      if (mounted) {
        context.read<SupplierProvider>().fetchSuppliers();
      }
    });
  }

  void _openSupplierDetailsDialog(Supplier supplier) {
    Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 650,
      maxHeight: 850,
      child: CustomerDetailsScreen(
        customer: Customer(
          id: supplier.id ?? '',
          name: supplier.name,
          phone: supplier.phone,
          address: supplier.address ?? '',
          taxNumber: supplier.vatNumber,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isCustomersTab = _tabController.index == 0;
    final isWide = MediaQuery.of(context).size.width >= 900;
    final isMobile = context.isMobile;

    final searchBarWidget = _SearchBar(
      controller: isCustomersTab ? _customerSearch : _supplierSearch,
      hint: isCustomersTab ? 'Search customers...' : 'Search suppliers...',
      onChanged: isCustomersTab ? _filterCustomers : _filterSuppliers,
    );

    final viewModeToggleWidget = _ViewModeToggle(
      viewMode: _viewMode,
      onChanged: (mode) => setState(() => _viewMode = mode),
    );

    final addButtonWidget = _AddButton(
      label: isCustomersTab ? 'Create Customer' : 'Create Supplier',
      onTap: isCustomersTab
          ? _openCreateCustomerDialog
          : _openCreateSupplierDialog,
    );

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
        centerTitle: !isWide,
        title: isWide
            ? Row(
                children: [
                  _PillTabBar(controller: _tabController),
                  const Spacer(),
                  Text(
                    'Customers & Suppliers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const Spacer(),
                  viewModeToggleWidget,
                  const SizedBox(width: 10),
                  SizedBox(width: 250, child: searchBarWidget),
                  const SizedBox(width: 10),
                  addButtonWidget,
                ],
              )
            : _PillTabBar(controller: _tabController),
      ),
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: isCustomersTab
                  ? _openCreateCustomerDialog
                  : _openCreateSupplierDialog,
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: Text(
                isCustomersTab ? 'Customer' : 'Supplier',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          if (!isWide)
            Container(
              color: AppTheme.surfaceBg(context),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(child: searchBarWidget),
                  const SizedBox(width: 8),
                  viewModeToggleWidget,
                  if (!isMobile) ...[const SizedBox(width: 8), addButtonWidget],
                ],
              ),
            ),
          if (isCustomersTab)
            _buildCustomerFilterBar(
              context.watch<CustomerProvider>().customers,
              filteredCustomerCount: _filteredCustomerList(
                context.watch<CustomerProvider>().customers,
              ).length,
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_customersTab(), _suppliersTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bodies ────────────────────────────────────────────────────────────

  Widget _customersTab() {
    return RefreshIndicator(
      onRefresh: () => context.read<CustomerProvider>().fetchCustomers(),
      child: Selector<CustomerProvider, List<Customer>>(
        selector: (_, p) => p.customers,
        builder: (context, customers, _) {
          final list = _filteredCustomerList(customers);

          if (list.isEmpty) {
            return _EmptyState(
              icon: LucideIcons.users,
              text: _customerSearch.text.isNotEmpty
                  ? 'No matching customers found'
                  : 'No customers found',
            );
          }

          if (_viewMode == ViewMode.table) {
            return _CustomerTableView(
              customers: list,
              onEdit: _openEditCustomerDialog,
              onViewDetails: _openCustomerDetailsDialog,
              onDelete: (customer) => _deleteCustomer(customer.id),
              onWhatsAppAlert: _sendExpiredAlertWhatsApp,
            );
          }

          // Grid View
          final gridItems = <_CustomerGridItem>[];
          for (final customer in list) {
            gridItems.add(_CustomerGridItem.customer(customer));
            for (final branch in customer.branches) {
              gridItems.add(_CustomerGridItem.branch(branch, customer));
            }
          }

          return _MasonryGrid(
            itemCount: gridItems.length,
            itemBuilder: (i) {
              final item = gridItems[i];
              if (item.branch != null) {
                final branchAlertState = context
                    .read<CustomerProvider>()
                    .getBranchActivationAlertState(item.branch!);
                final isBranchExpired = _isExpiredAlert(branchAlertState);

                return _BranchContactCard(
                  branch: item.branch!,
                  customerName: item.customerName!,
                  onEdit: () => _openEditCustomerDialog(item.parentCustomer!),
                  onViewDetails: () => _openBranchDetails(
                    item.branch!,
                    item.parentCustomer!.branches.indexOf(item.branch!) + 1,
                    item.parentCustomer!,
                  ),
                  onDelete: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Edit the customer to manage this branch.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  ),
                  onWhatsAppAlert: isBranchExpired
                      ? () => _sendExpiredBranchAlertWhatsApp(
                          item.branch!,
                          item.customerName!,
                          item.parentCustomer,
                          branchAlertState,
                        )
                      : null,
                );
              }

              final customer = item.customer!;
              final alertState = context
                  .read<CustomerProvider>()
                  .getActivationAlertState(customer);
              final isExpired = _isExpiredAlert(alertState);
              final customerProvider = context.read<CustomerProvider>();
              final expiryDate =
                  customerProvider.parseActivationDate(
                    customer.financialPeriodEndDate,
                  ) ??
                  (customer.softwareActivations.isNotEmpty
                      ? customerProvider.parseActivationDate(
                          customer.softwareActivations.first['expiryDate'],
                        )
                      : null);

              return _ContactCard(
                avatarLetter: customer.name.isNotEmpty
                    ? customer.name[0].toUpperCase()
                    : '?',
                avatarColor: isExpired
                    ? Colors.red.shade700
                    : alertState == ActivationAlertState.warning
                    ? Colors.orange.shade700
                    : _K.customerColor.shade700,
                title: customer.name,
                subtitle: customer.phone,
                expiryDate: expiryDate,
                infoRows: _customerInfoRows(customer),
                editColor: _K.customerColor.shade700,
                isExpired: isExpired,
                alertState: alertState,
                branches: customer.branches,
                onEdit: () => _openEditCustomerDialog(customer),
                onViewDetails: () => _openCustomerDetailsDialog(customer),
                onDelete: () => _deleteCustomer(customer.id),
                onWhatsAppAlert: isExpired
                    ? () => _sendExpiredAlertWhatsApp(customer, alertState)
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  Widget _suppliersTab() {
    return RefreshIndicator(
      onRefresh: () => context.read<SupplierProvider>().fetchSuppliers(),
      child: Selector<SupplierProvider, List<Supplier>>(
        selector: (_, p) => p.suppliers,
        builder: (context, suppliers, _) {
          final list = _filteredSuppliers ?? suppliers;

          if (list.isEmpty) {
            return _EmptyState(
              icon: LucideIcons.truck,
              text: _supplierSearch.text.isNotEmpty
                  ? 'No matching suppliers found'
                  : 'No suppliers found',
            );
          }

          if (_viewMode == ViewMode.table) {
            return _SupplierTableView(
              suppliers: list,
              onEdit: _openEditSupplierDialog,
              onViewDetails: _openSupplierDetailsDialog,
              onDelete: (supplier) => _deleteSupplier(supplier.id ?? ''),
            );
          }

          // Grid View
          return _MasonryGrid(
            itemCount: list.length,
            itemBuilder: (i) => _ContactCard(
              isExpired: false,
              onViewDetails: () => _openSupplierDetailsDialog(list[i]),
              alertState: ActivationAlertState.none,
              avatarLetter: list[i].name.isNotEmpty
                  ? list[i].name[0].toUpperCase()
                  : '?',
              avatarColor: _K.supplierColor.shade700,
              title: list[i].name,
              subtitle: list[i].phone,
              infoRows: _supplierInfoRows(list[i]),
              editColor: _K.supplierColor.shade700,
              onEdit: () => _openEditSupplierDialog(list[i]),
              onDelete: () => _deleteSupplier(list[i].id ?? ''),
            ),
          );
        },
      ),
    );
  }

  // ── Info row builders ─────────────────────────────────────────────────────

  static List<CardInfoRow> _customerInfoRows(Customer c) => [
    CardInfoRow(LucideIcons.phone, 'Phone 1', c.phone),
    if (c.phone2?.isNotEmpty ?? false)
      CardInfoRow(LucideIcons.phoneCall, 'Phone 2', c.phone2!),
    if (c.email?.isNotEmpty ?? false)
      CardInfoRow(LucideIcons.mail, 'Email', c.email!),
    CardInfoRow(LucideIcons.mapPin, 'Address', c.address),
    if (c.cityName?.isNotEmpty ?? false)
      CardInfoRow(LucideIcons.building2, 'City', c.cityName!),
    if (c.organizationName?.isNotEmpty ?? false)
      CardInfoRow(LucideIcons.building, 'Organization', c.organizationName!),
    if (c.periodSectionName?.isNotEmpty ?? false)
      CardInfoRow(LucideIcons.calendarRange, 'Period', c.periodSectionName!),
    CardInfoRow(LucideIcons.receipt, 'VAT Number', c.taxNumber),
    if (c.crNumber?.isNotEmpty ?? false)
      CardInfoRow(LucideIcons.briefcase, 'CR Number', c.crNumber!),
  ];

  static List<CardInfoRow> _supplierInfoRows(Supplier s) => [
    CardInfoRow(LucideIcons.phone, 'Phone 1', s.phone),
    CardInfoRow(LucideIcons.mapPin, 'Address', s.address ?? 'Not specified'),
    CardInfoRow(LucideIcons.receipt, 'VAT Number', s.vatNumber),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// View Mode Toggle Segmented Control
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
        color: AppTheme.inputBg(context),
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
                ? AppTheme.surfaceBg(context)
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
            color: isSelected
                ? AppTheme.accent(context)
                : AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modern Customer Table View
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerTableView extends StatelessWidget {
  final List<Customer> customers;
  final Function(Customer) onEdit;
  final Function(Customer) onViewDetails;
  final Function(Customer) onDelete;
  final Function(Customer, ActivationAlertState)? onWhatsAppAlert;

  const _CustomerTableView({
    required this.customers,
    required this.onEdit,
    required this.onViewDetails,
    required this.onDelete,
    this.onWhatsAppAlert,
  });

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.read<CustomerProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.cardBorderColor(context),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _HorizontalTableScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppTheme.surfaceBg(context),
              ),
              headingRowHeight: 40,
              dataRowMinHeight: 35,
              dataRowMaxHeight: 40,
              horizontalMargin: 18,
              columnSpacing: 10,
              dividerThickness: 1,
              columns: const [
                DataColumn(
                  label: Text(
                    'CUSTOMER NAME',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'PHONE / CONTACT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'ADDRESS & CITY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'TAX / VAT NUMBER',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'PERIOD SECTION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'SOFTWARE & STATUS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'CREATED BY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'EDITED BY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'BRANCHES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'ACTIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
              rows: customers.map((c) {
                final isDark = AppTheme.isDark(context);

                final alertState = customerProvider.getActivationAlertState(c);
                final isExpired = _isExpiredAlert(alertState);
                final isWarning = alertState == ActivationAlertState.warning;

                return DataRow(
                  color: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return isDark
                          ? FuturisticColors.bgCardHover
                          : const Color(0xFFF8FAFC);
                    }
                    return AppTheme.cardBg(context);
                  }),
                  cells: [
                    // Name & Avatar
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: isExpired
                                ? Colors.red.shade100
                                : isWarning
                                ? Colors.orange.shade100
                                : const Color(
                                    0xFF0D9488,
                                  ).withValues(alpha: 0.12),
                            child: Text(
                              c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isExpired
                                    ? Colors.red.shade700
                                    : isWarning
                                    ? Colors.orange.shade700
                                    : const Color(0xFF0D9488),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                c.name,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark == true
                                      ? Colors.white
                                      : Color(0xFF0F172A),
                                ),
                              ),
                              if ((c.organizationName ?? '').isNotEmpty)
                                Text(
                                  c.organizationName!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Phone / Contact
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                c.phone.isEmpty ? '—' : c.phone,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark == true
                                      ? Colors.grey.shade400
                                      : Color(0xFF334155),
                                ),
                              ),
                              if (c.phone.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _copyToClipboard(
                                    context,
                                    c.phone,
                                    'Phone number',
                                  ),
                                  child: Icon(
                                    LucideIcons.copy,
                                    size: 13,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if ((c.email ?? '').isNotEmpty)
                            Text(
                              c.email!,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark == true
                                    ? Colors.grey.shade400
                                    : Color(0xFF334155),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Address & City
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            c.address.isEmpty ? '—' : c.address,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: isDark == true
                                  ? Colors.grey.shade400
                                  : Color(0xFF334155),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((c.cityName ?? '').isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                c.cityName!,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // VAT Number
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            c.taxNumber.isEmpty ? '—' : c.taxNumber,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: isDark == true
                                  ? Colors.grey.shade400
                                  : Color(0xFF334155),
                            ),
                          ),
                          if (c.taxNumber.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _copyToClipboard(
                                context,
                                c.taxNumber,
                                'Tax number',
                              ),
                              child: Icon(
                                LucideIcons.copy,
                                size: 13,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Period Section
                    DataCell(
                      c.periodSectionName != null &&
                              c.periodSectionName!.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF6366F1,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                c.periodSectionName!,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            )
                          : const Text(
                              '—',
                              style: TextStyle(color: Colors.grey),
                            ),
                    ),

                    // Software & Status
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.usedSoftwares.isNotEmpty)
                            ...c.usedSoftwares
                                .take(2)
                                .map(
                                  (sw) => Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF0D9488,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      sw,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D9488),
                                      ),
                                    ),
                                  ),
                                ),
                          if (isExpired) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _alertMessage(alertState),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade800,
                                ),
                              ),
                            ),
                            if (onWhatsAppAlert != null) ...[
                              const SizedBox(width: 5),
                              Tooltip(
                                message: 'Send Expired Alert via WhatsApp',
                                child: InkWell(
                                  onTap: () => onWhatsAppAlert!(c, alertState),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FaIcon(
                                          FontAwesomeIcons.whatsapp,
                                          size: 11,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'Alert',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ] else if (isWarning)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'EXPIRING',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            )
                          else if (c.zatcaEnabled == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ZATCA',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            c.createdByName ?? '—',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: isDark == true
                                  ? Colors.grey.shade400
                                  : Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            c.editedByName ?? '—',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: isDark == true
                                  ? Colors.grey.shade400
                                  : Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Branches
                    DataCell(
                      c.branches.isEmpty
                          ? const Text(
                              '—',
                              style: TextStyle(color: Colors.grey),
                            )
                          : Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: c.branches.map((b) {
                                return Tooltip(
                                  message: b.phone.isNotEmpty
                                      ? '${b.name}  •  ${b.phone}'
                                      : b.name,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF0D9488,
                                      ).withValues(alpha: 0.09),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF0D9488,
                                        ).withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          LucideIcons.building2,
                                          size: 11,
                                          color: Color(0xFF0D9488),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          b.name.isEmpty ? 'Branch' : b.name,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0D9488),
                                          ),
                                        ),
                                        if (b.zatcaEnabled) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF10B981,
                                              ).withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                            child: const Text(
                                              'Z',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF10B981),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),

                    // Action buttons
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isExpired && onWhatsAppAlert != null) ...[
                            IconButton(
                              icon: const FaIcon(
                                FontAwesomeIcons.whatsapp,
                                size: 16,
                              ),
                              color: const Color(0xFF25D366),
                              tooltip: 'Send Expired Alert via WhatsApp',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () => onWhatsAppAlert!(c, alertState),
                            ),
                            const SizedBox(width: 6),
                          ],
                          IconButton(
                            icon: const Icon(LucideIcons.eye, size: 16),
                            color: const Color(0xFF0D9488),
                            tooltip: 'View Details',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: () => onViewDetails(c),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(LucideIcons.edit, size: 16),
                            color: Colors.blue.shade600,
                            tooltip: 'Edit Customer',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: () => onEdit(c),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2, size: 16),
                            color: Colors.red.shade500,
                            tooltip: 'Delete Customer',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: () => onDelete(c),
                          ),
                        ],
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
// Modern Supplier Table View
// ─────────────────────────────────────────────────────────────────────────────

class _SupplierTableView extends StatelessWidget {
  final List<Supplier> suppliers;
  final Function(Supplier) onEdit;
  final Function(Supplier) onViewDetails;
  final Function(Supplier) onDelete;

  const _SupplierTableView({
    required this.suppliers,
    required this.onEdit,
    required this.onViewDetails,
    required this.onDelete,
  });

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _HorizontalTableScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingRowHeight: 40,
              dataRowMinHeight: 35,
              dataRowMaxHeight: 40,
              horizontalMargin: 18,
              columnSpacing: 15,
              dividerThickness: 1,
              columns: const [
                DataColumn(
                  label: Text(
                    'SUPPLIER NAME',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'PHONE NUMBER',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'ADDRESS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'VAT NUMBER',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'ACTIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
              rows: suppliers.map((s) {
                return DataRow(
                  color: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return const Color(0xFFF8FAFC);
                    }
                    return Colors.white;
                  }),
                  cells: [
                    // Name & Avatar
                    DataCell(
                      Row(
                        children: [
                          Container(
                            width: 32, // radius * 2
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.12),
                              // shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            s.name,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Phone
                    DataCell(
                      Row(
                        children: [
                          Text(
                            s.phone.isEmpty ? '—' : s.phone,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                          if (s.phone.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _copyToClipboard(
                                context,
                                s.phone,
                                'Phone number',
                              ),
                              child: Icon(
                                LucideIcons.copy,
                                size: 13,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Address
                    DataCell(
                      Text(
                        (s.address ?? '').isEmpty ? '—' : s.address!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // VAT Number
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s.vatNumber.isEmpty ? '—' : s.vatNumber,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (s.vatNumber.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _copyToClipboard(
                                context,
                                s.vatNumber,
                                'VAT number',
                              ),
                              child: Icon(
                                LucideIcons.copy,
                                size: 13,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(LucideIcons.eye, size: 16),
                            color: const Color(0xFF0D9488),
                            tooltip: 'View Details',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: () => onViewDetails(s),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(LucideIcons.edit, size: 16),
                            color: Colors.green.shade700,
                            tooltip: 'Edit Supplier',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: () => onEdit(s),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2, size: 16),
                            color: Colors.red.shade500,
                            tooltip: 'Delete Supplier',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: () => onDelete(s),
                          ),
                        ],
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
// Small extracted widgets
// ─────────────────────────────────────────────────────────────────────────────

class _HorizontalTableScrollView extends StatefulWidget {
  const _HorizontalTableScrollView({required this.child});

  final Widget child;

  @override
  State<_HorizontalTableScrollView> createState() =>
      _HorizontalTableScrollViewState();
}

class _HorizontalTableScrollViewState
    extends State<_HorizontalTableScrollView> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      thickness: 10,
      radius: const Radius.circular(5),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          child: widget.child,
        ),
      ),
    );
  }
}

class _PillTabBar extends StatelessWidget {
  const _PillTabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final isSmall = context.isSmallMobile;
    return Container(
      height: 38,
      constraints: const BoxConstraints(maxWidth: 280),
      width: isSmall ? 220 : 270,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.inputBg(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: AppTheme.surfaceBg(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppTheme.textPrimary(context),
        unselectedLabelColor: AppTheme.textSecondary(context),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
        ),
        tabs: const [
          Tab(text: 'Customers'),
          Tab(text: 'Suppliers'),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 37,
      decoration: BoxDecoration(
        color: const Color(0xFF0D9488),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.plus, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 37,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          filled: true,
          // fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 0,
          ),
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
          isDense: true,
          prefixIcon: const Icon(
            LucideIcons.search,
            size: 15,
            color: Color(0xFF64748B),
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, size: 14),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _MasonryGrid extends StatelessWidget {
  const _MasonryGrid({required this.itemCount, required this.itemBuilder});
  final int itemCount;
  final Widget Function(int) itemBuilder;

  int _getColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 650) return 1;
    if (width < 1050) return 2;
    if (width < 1550) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      crossAxisCount: _getColumns(context),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: itemCount,
      itemBuilder: (_, i) => itemBuilder(i),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isExpiredAlert(ActivationAlertState state) {
  return state == ActivationAlertState.zatcaExpired ||
      state == ActivationAlertState.softwareExpired ||
      state == ActivationAlertState.bothExpired;
}

String _alertMessage(ActivationAlertState state) {
  switch (state) {
    case ActivationAlertState.zatcaExpired:
      return 'ZATCA activation expired';
    case ActivationAlertState.softwareExpired:
      return 'Software activation expired';
    case ActivationAlertState.bothExpired:
      return 'ZATCA and software activations expired';
    case ActivationAlertState.warning:
      return 'Activation expires soon';
    case ActivationAlertState.none:
      return '';
  }
}

class _CustomerGridItem {
  final Customer? customer;
  final Branch? branch;
  final String? customerName;
  final Customer? parentCustomer;

  const _CustomerGridItem.customer(Customer value)
    : customer = value,
      branch = null,
      customerName = null,
      parentCustomer = null;

  _CustomerGridItem.branch(Branch value, Customer parent)
    : customer = null,
      branch = value,
      customerName = parent.name,
      parentCustomer = parent;
}

class _BranchContactCard extends StatelessWidget {
  final Branch branch;
  final String customerName;
  final VoidCallback onEdit;
  final VoidCallback onViewDetails;
  final VoidCallback onDelete;
  final VoidCallback? onWhatsAppAlert;

  const _BranchContactCard({
    required this.branch,
    required this.customerName,
    required this.onEdit,
    required this.onViewDetails,
    required this.onDelete,
    this.onWhatsAppAlert,
  });

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.read<CustomerProvider>();
    final alertState = customerProvider.getBranchActivationAlertState(branch);
    final isExpired = _isExpiredAlert(alertState);
    final expiryDate =
        customerProvider.parseActivationDate(branch.financialPeriodEndDate) ??
        (branch.softwareActivations.isNotEmpty
            ? customerProvider.parseActivationDate(
                branch.softwareActivations.first['expiryDate'],
              )
            : null);

    return _ContactCard(
      avatarLetter: branch.name.isNotEmpty ? branch.name[0].toUpperCase() : '?',
      avatarColor: isExpired ? Colors.red.shade700 : const Color(0xFF0D9488),
      title: branch.name.isEmpty ? '(No name)' : branch.name,
      subtitle: 'Branch of $customerName',
      expiryDate: expiryDate,
      infoRows: [
        CardInfoRow(LucideIcons.phone, 'Phone', branch.phone),
        CardInfoRow(LucideIcons.mapPin, 'Address', branch.address),
        if (branch.periodSectionName?.isNotEmpty ?? false)
          CardInfoRow(
            LucideIcons.calendarRange,
            'Period',
            branch.periodSectionName!,
          ),
        CardInfoRow(
          LucideIcons.shieldCheck,
          'ZATCA',
          branch.zatcaEnabled ? 'Enabled' : 'Disabled',
        ),
        if (branch.softwareActivations.isNotEmpty)
          CardInfoRow(
            LucideIcons.laptop,
            'Software Activations',
            '${branch.softwareActivations.length}',
          ),
      ],
      editColor: const Color(0xFF0D9488),
      isExpired: isExpired,
      alertState: alertState,
      showActions: true,
      onEdit: onEdit,
      onViewDetails: onViewDetails,
      onDelete: onDelete,
      onWhatsAppAlert: isExpired ? onWhatsAppAlert : null,
    );
  }
}

class _BranchListCard extends StatelessWidget {
  final Branch branch;
  final String customerName;

  const _BranchListCard({required this.branch, required this.customerName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final softwareCount = branch.softwareActivations.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.teal.shade900.withValues(alpha: 0.14)
            : const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(_K.cardRadius),
        border: Border.all(
          color: isDark
              ? Colors.teal.shade700.withValues(alpha: 0.35)
              : const Color(0xFF0D9488).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  LucideIcons.building2,
                  size: 19,
                  color: Color(0xFF0D9488),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            branch.name.isEmpty ? '(No name)' : branch.name,
                            style: TextStyle(
                              overflow: TextOverflow.ellipsis,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            overflow: TextOverflow.ellipsis,
                            'Branch of $customerName',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (branch.zatcaEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'ZATCA',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _branchListDetail(
            context,
            LucideIcons.phone,
            branch.phone.isEmpty ? 'No phone number' : branch.phone,
          ),
          _branchListDetail(
            context,
            LucideIcons.mapPin,
            branch.address.isEmpty ? 'No address' : branch.address,
          ),
          if (branch.periodSectionName?.isNotEmpty ?? false)
            _branchListDetail(
              context,
              LucideIcons.calendarRange,
              branch.periodSectionName!,
            ),
          if (softwareCount > 0)
            _branchListDetail(
              context,
              LucideIcons.laptop,
              '$softwareCount software activation${softwareCount == 1 ? '' : 's'}',
            ),
        ],
      ),
    );
  }

  Widget _branchListDetail(BuildContext context, IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0D9488)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unified Contact Card (Grid View)
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class CardInfoRow {
  final IconData icon;
  final String label;
  final String value;
  const CardInfoRow(this.icon, this.label, this.value);
}

class _ContactCard extends StatefulWidget {
  const _ContactCard({
    required this.avatarLetter,
    required this.avatarColor,
    required this.title,
    required this.subtitle,
    this.expiryDate,
    required this.infoRows,
    required this.editColor,
    required this.isExpired,
    required this.alertState,
    required this.onEdit,
    required this.onViewDetails,
    required this.onDelete,
    this.onWhatsAppAlert,
    this.branches = const [],
    this.showActions = true,
  });

  final String avatarLetter;
  final Color avatarColor;
  final String title;
  final String subtitle;
  final DateTime? expiryDate;
  final List<CardInfoRow> infoRows;
  final Color editColor;
  final bool isExpired;
  final ActivationAlertState alertState;
  final VoidCallback onEdit;
  final VoidCallback onViewDetails;
  final VoidCallback onDelete;
  final VoidCallback? onWhatsAppAlert;
  final List<Branch> branches;
  final bool showActions;

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  late final Animation<double> _expandAnim = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeInOut,
  );

  late final Animation<double> _rotateAnim = Tween<double>(
    begin: 0,
    end: 0.5,
  ).animate(_expandAnim);

  bool _expanded = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpired = _isExpiredAlert(widget.alertState);
    final isWarning = widget.alertState == ActivationAlertState.warning;

    final borderColor = isExpired
        ? (isDark ? FuturisticColors.neonCrimson : Colors.red.shade400)
        : isWarning
        ? (isDark ? FuturisticColors.neonAmber : Colors.orange.shade400)
        : AppTheme.cardBorderColor(context);
    final surfaceColor = isExpired
        ? (isDark
              ? Colors.red.shade900.withValues(alpha: 0.25)
              : Colors.red.shade50.withValues(alpha: 0.4))
        : isWarning
        ? (isDark
              ? Colors.orange.shade900.withValues(alpha: 0.25)
              : Colors.orange.shade50.withValues(alpha: 0.4))
        : AppTheme.cardBg(context);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(_K.cardRadius),
        border: Border.all(
          color: borderColor,
          width: (isExpired || isWarning) ? 1.4 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_K.cardRadius),
        child: Column(
          children: [
            if (isExpired || isWarning)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                color: isExpired
                    ? (isDark
                          ? Colors.red.shade900.withValues(alpha: 0.4)
                          : Colors.red.shade100)
                    : (isDark
                          ? Colors.orange.shade900.withValues(alpha: 0.4)
                          : Colors.orange.shade100),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.alertTriangle,
                      size: 15,
                      color: isExpired
                          ? (isDark
                                ? FuturisticColors.neonCrimson
                                : Colors.red.shade700)
                          : (isDark
                                ? FuturisticColors.neonAmber
                                : Colors.orange.shade700),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _alertMessage(widget.alertState),
                        style: TextStyle(
                          color: isExpired
                              ? (isDark
                                    ? FuturisticColors.neonCrimson
                                    : Colors.red.shade800)
                              : (isDark
                                    ? FuturisticColors.neonAmber
                                    : Colors.orange.shade800),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isExpired && widget.onWhatsAppAlert != null) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Send Expired Alert via WhatsApp',
                        child: Material(
                          color: const Color(0xFF25D366),
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            onTap: widget.onWhatsAppAlert,
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FaIcon(
                                    FontAwesomeIcons.whatsapp,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Send Alert',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            // Header
            InkWell(
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _Avatar(
                      letter: widget.avatarLetter,
                      color: widget.avatarColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.subtitle,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.textSecondary(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.expiryDate != null)
                                Text(
                                  'Exp: ${widget.expiryDate!.toLocal().toString().split(' ')[0]}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    RotationTransition(
                      turns: _rotateAnim,
                      child: Icon(
                        LucideIcons.chevronDown,
                        color: Colors.grey.shade400,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Expandable body
            SizeTransition(
              sizeFactor: _expandAnim,
              axisAlignment: -1,
              child: Column(
                children: [
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...widget.infoRows.map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  row.icon,
                                  size: 14,
                                  color: const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${row.label}: ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    row.value.isEmpty ? '—' : row.value,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark == true
                                          ? Colors.grey.shade500
                                          : Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // ── Branches section ───────────────────────────────
                        if (widget.branches.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.gitBranch,
                                size: 13,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Branches (${widget.branches.length})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...widget.branches.map(
                            (b) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      LucideIcons.building2,
                                      size: 13,
                                      color: isDark
                                          ? FuturisticColors.neonCyan
                                          : const Color(0xFF0D9488),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            b.name.isEmpty
                                                ? '(No name)'
                                                : b.name,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textPrimary(
                                                context,
                                              ),
                                            ),
                                          ),
                                          if (b.phone.isNotEmpty)
                                            Text(
                                              b.phone,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: AppTheme.textSecondary(
                                                  context,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (b.zatcaEnabled)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF10B981,
                                          ).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'ZATCA',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (widget.showActions) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (isExpired &&
                                  widget.onWhatsAppAlert != null) ...[
                                Expanded(
                                  child: _ActionButton(
                                    iconWidget: const FaIcon(
                                      FontAwesomeIcons.whatsapp,
                                      size: 14,
                                      color: Color(0xFF25D366),
                                    ),
                                    label: 'Alert',
                                    color: const Color(0xFF25D366),
                                    onTap: widget.onWhatsAppAlert!,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: _ActionButton(
                                  icon: LucideIcons.eye,
                                  label: 'Details',
                                  color: const Color(0xFF0D9488),
                                  onTap: widget.onViewDetails,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ActionButton(
                                  icon: LucideIcons.edit3,
                                  label: 'Edit',
                                  color: widget.editColor,
                                  onTap: widget.onEdit,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ActionButton(
                                  icon: LucideIcons.trash2,
                                  label: 'Delete',
                                  color: Colors.red.shade600,
                                  onTap: widget.onDelete,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.letter, required this.color});
  final String letter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget ?? Icon(icon!, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
