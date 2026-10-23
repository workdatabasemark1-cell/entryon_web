import 'package:entryon/models/service_model.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/service_entry_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/user_provider.dart';
import '../models/user_model.dart';
import '../models/customer_model.dart';
import '../utils/date_utils.dart';
import '../utils/responsive.dart';
import 'createServiceEntryScreen.dart';
import 'editServiceEntryScreen.dart';
import 'serviceEntryDetailsScreen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/pdf_theme_helper.dart';
import '../utils/pdf_actions.dart';
import '../utils/app_theme.dart';

enum ViewMode { grid, table }

Color _balanceColor(double balance) {
  if (balance > 0.005) return Colors.red.shade700;
  if (balance < -0.005) return Colors.blue.shade700;
  return const Color(0xFF10B981);
}

String _balanceLabel(double balance) {
  if (balance > 0.005) return 'Due';
  if (balance < -0.005) return 'Overpaid';
  return 'Settled';
}

class ServicesListScreen extends StatefulWidget {
  const ServicesListScreen({super.key});

  @override
  State<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends State<ServicesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  ViewMode _viewMode = ViewMode.grid;
  String _paymentStatusFilter = 'All';
  String _serviceStatusFilter = 'All';
  String _softwareFilter = 'All';
  String _addedByFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceEntryProvider>().fetchServices();
      context.read<CustomerProvider>().fetchCustomers();
      context.read<UserProvider>().fetchUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialStart = _fromDate ?? now.subtract(const Duration(days: 30));
    final initialEnd = _toDate ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D9488),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  List<ServiceEntry> _filteredServices(List<ServiceEntry> services) {
    final query = _searchController.text.trim().toLowerCase();
    final start = _fromDate;
    final end = _toDate;

    return services.where((service) {
      final matchesName = query.isEmpty ||
          service.customerName.toLowerCase().contains(query) ||
          service.title.toLowerCase().contains(query);
      final matchesDate = isDateWithinRange(service.serviceDate, start, end);
      return matchesName &&
          matchesDate &&
          (_paymentStatusFilter == 'All' ||
              service.paymentStatus == _paymentStatusFilter) &&
          (_serviceStatusFilter == 'All' ||
              service.serviceStatus == _serviceStatusFilter) &&
          (_softwareFilter == 'All' ||
              (_softwareFilter == 'No software'
                  ? service.softwareName == null || service.softwareName!.isEmpty
                  : service.softwareName == _softwareFilter)) &&
          (_addedByFilter == 'All' ||
              service.addedByName == _addedByFilter ||
              service.addedById == _userIdForName(_addedByFilter));
    }).toList();
  }

  String? _userIdForName(String name) {
    for (final user in context.read<UserProvider>().users) {
      if (user.name == name) return user.id;
    }
    return null;
  }

  List<String> _filterOptions(List<ServiceEntry> services, String Function(ServiceEntry) valueOf) {
    final values = services
        .map(valueOf)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...values];
  }

  Widget _buildFilterDropdown({
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
          hint: Text(label),
          icon: Icon(LucideIcons.chevronDown,
              size: 14, color: AppTheme.textSecondary(context)),
          style: TextStyle(
              fontSize: 12, color: AppTheme.textPrimary(context)),
          onChanged: (selected) {
            if (selected != null) onChanged(selected);
          },
          items: options
              .map((option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option == 'All' ? label : option),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildFilterBar(
      List<ServiceEntry> services, List<AppUser> users, int filteredCount) {
    return Container(
      width: double.infinity,
      color: AppTheme.surfaceBg(context),
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Container(
            //   height: 38,
            //   padding: const EdgeInsets.symmetric(horizontal: 10),
            //   alignment: Alignment.center,
            //   decoration: BoxDecoration(
            //     color: AppTheme.accent(context).withValues(alpha: 0.10),
            //     borderRadius: BorderRadius.circular(8),
            //     border: Border.all(
            //       color: AppTheme.accent(context).withValues(alpha: 0.25),
            //     ),
            //   ),
            //   child: Text(
            //     '$filteredCount ${filteredCount == 1 ? 'service' : 'services'}',
            //     style: TextStyle(
            //       fontSize: 12,
            //       fontWeight: FontWeight.w700,
            //       color: AppTheme.accent(context),
            //     ),
            //   ),
            // ),
            // const SizedBox(width: 6),
            _buildFilterDropdown(
              label: 'Payment status',
              value: _paymentStatusFilter,
              options: _filterOptions(services, (service) => service.paymentStatus),
              onChanged: (value) =>
                  setState(() => _paymentStatusFilter = value),
            ),
            const SizedBox(width: 6),
            _buildFilterDropdown(
              label: 'Service status',
              value: _serviceStatusFilter,
              options: _filterOptions(services, (service) => service.serviceStatus),
              onChanged: (value) =>
                  setState(() => _serviceStatusFilter = value),
            ),
            const SizedBox(width: 6),
            _buildFilterDropdown(
              label: 'Software',
              value: _softwareFilter,
              options: [
                'All',
                'No software',
                ..._filterOptions(services, (service) => service.softwareName ?? '')
                    .where((option) => option != 'All'),
              ],
              onChanged: (value) => setState(() => _softwareFilter = value),
            ),
            const SizedBox(width: 6),
            _buildFilterDropdown(
              label: 'Added by',
              value: _addedByFilter,
              options: _addedByOptions(users),
              onChanged: (value) => setState(() => _addedByFilter = value),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _addedByOptions(List<AppUser> users) {
    final names = users
        .map((user) => user.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...names];
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed':
        return const Color(0xFF10B981);
      case 'free':
        return const Color(0xFF0EA5E9);
      case 'partial':
      case 'in progress':
      case 'work in progress':
        return Colors.orange.shade700;
      case 'pending':
        return const Color(0xFF6366F1);
      default:
        return Colors.redAccent;
    }
  }

  Color _balanceColor(double balance) {
    if (balance > 0.005) return Colors.red.shade700;
    if (balance < -0.005) return Colors.blue.shade700;
    return const Color(0xFF10B981);
  }

  String _balanceLabel(double balance) {
    if (balance > 0.005) return 'Due';
    if (balance < -0.005) return 'Overpaid';
    return 'Settled';
  }

  String? customerPhone(ServiceEntry service, List<Customer> customers) {
    if (service.customerId != null) {
      for (final customer in customers) {
        if (customer.id == service.customerId) return service.staffPhone?? customer.phone;
      }
    }
    return service.staffPhone;
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri.parse('tel:${phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    
    }
  }

  Future<void> _whatsappCustomer(String phone) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    // final uri = Uri.parse(
    //   'https://wa.me/${normalizedPhone.replaceFirst('+', '')}',
    // );
    // if (await canLaunchUrl(uri)) {
    //   await launchUrl(uri, mode: LaunchMode.externalApplication);
    // }
    launchUrl(
                                    Uri.parse('https://wa.me/${normalizedPhone}'),
                                  );
  }

  Widget _customerContactActions(
    BuildContext context,
    ServiceEntry service,
    List<Customer> customers,
  ) {
    final phone = customerPhone(service, customers);
    if (phone == null || phone.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            phone,
            style: TextStyle(
              fontSize: 11.5,
              color: AppTheme.textSecondary(context),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 2),
        IconButton(
          icon: const Icon(LucideIcons.phone, size: 15),
          color: const Color(0xFF0D9488),
          tooltip: 'Call customer',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: () => _callCustomer(phone),
        ),
        IconButton(
          icon: const Icon(LucideIcons.messageCircle, size: 15),
          color: const Color(0xFF25D366),
          tooltip: 'WhatsApp customer',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: () => _whatsappCustomer(phone),
        ),
      ],
    );
  }

  int _getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 650) return 1;
    if (width < 1100) return 2;
    if (width < 1870) return 2;
    return 3;
  }

  void _openCreateServiceDialog() {
    Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 850,
      maxHeight: 850,
      child: const CreateServiceEntryScreen(),
    ).then((_) {
      if (mounted) {
        context.read<ServiceEntryProvider>().fetchServices();
      }
    });
  }

  void _openServiceDetailsDialog(ServiceEntry service) {
    Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 800,
      maxHeight: 850,
      child: ServiceEntryDetailsScreen(service: service),
    ).then((_) {
      if (mounted) {
        context.read<ServiceEntryProvider>().fetchServices();
      }
    });
  }

  void _openEditServiceDialog(ServiceEntry service) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 800,
          height: 900,
          child: EditServiceEntryScreen(serviceId: service.id),
        ),
      ),
    ).then((_) {
      if (mounted) {
        context.read<ServiceEntryProvider>().fetchServices();
      }
    });
  }

  Future<void> _deleteService(ServiceEntry service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceBg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppTheme.cardBorderColor(context)),
        ),
        title: Text('Delete Service',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
        content: Text(
            'Are you sure you want to delete "${service.title}" for ${service.customerName}?',
            style: TextStyle(color: AppTheme.textSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<ServiceEntryProvider>().deleteService(service.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Service deleted successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.accent(context),
          ),
        );
      }
    }
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
      decoration: InputDecoration(
        hintText: 'Search service or customer...',
        hintStyle: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary(context)),
        prefixIcon: Icon(LucideIcons.search, size: 15, color: AppTheme.textSecondary(context)),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(LucideIcons.x, size: 14, color: AppTheme.textSecondary(context)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() => _searchController.clear());
                },
              )
            : null,
        filled: true,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        fillColor: AppTheme.inputBg(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.cardBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.cardBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.accent(context), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDatePickerButton() {
    final hasDate = _fromDate != null || _toDate != null;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: hasDate ? AppTheme.accent(context).withValues(alpha: 0.12) : AppTheme.cardBg(context),
        border: Border.all(
          color: hasDate ? AppTheme.accent(context) : AppTheme.cardBorderColor(context),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: _pickDateRange,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.calendar,
              size: 15,
              color: hasDate ? AppTheme.accent(context) : AppTheme.textSecondary(context),
            ),
            const SizedBox(width: 6),
            Text(
              !hasDate
                  ? 'Date Range'
                  : '${_fromDate != null ? DateFormat('dd MMM').format(_fromDate!) : ""}'
                    '${_fromDate != null && _toDate != null ? ' - ' : ''}'
                    '${_toDate != null ? DateFormat('dd MMM').format(_toDate!) : ""}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: hasDate ? FontWeight.w700 : FontWeight.w500,
                color: hasDate ? AppTheme.accent(context) : AppTheme.textPrimary(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return InkWell(
      onTap: () => setState(() {
        _searchController.clear();
        _fromDate = null;
        _toDate = null;
        _paymentStatusFilter = 'All';
        _serviceStatusFilter = 'All';
        _softwareFilter = 'All';
        _addedByFilter = 'All';
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surfaceBg(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.cardBorderColor(context)),
        ),
        child: Text(
          'Reset',
          style: TextStyle(
            color: AppTheme.textSecondary(context),
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton(List<ServiceEntry> filteredServices) {
    return OutlinedButton.icon(
      onPressed: filteredServices.isEmpty ? null : () => _exportToPdf(context, filteredServices),
      icon: const Icon(LucideIcons.fileDown, size: 15),
      label: const Text('Export PDF',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.accent(context),
        side: BorderSide(color: AppTheme.accent(context)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
Widget _buildAddServiceButton() {final isDark = AppTheme.isDark(context);
  return InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: _openCreateServiceDialog,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.accent(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:  [
          Icon(LucideIcons.plus, size: 16, color: isDark==true?Colors.black: Colors.white,),
          SizedBox(width: 8),
          Text(
            'Add Service',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              color:isDark==true?Colors.black: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServiceEntryProvider>();
    final customers = context.watch<CustomerProvider>().customers;
    final users = context.watch<UserProvider>().users;
    final filteredServices = _filteredServices(provider.services);
    final isWide = MediaQuery.of(context).size.width >= 1100;
    final isMobile = context.isMobile;
    final hasActiveFilter = _searchController.text.trim().isNotEmpty ||
        _fromDate != null ||
      _toDate != null ||
      _paymentStatusFilter != 'All' ||
      _serviceStatusFilter != 'All' ||
      _softwareFilter != 'All' ||
      _addedByFilter != 'All';

    final viewModeToggleWidget = _ViewModeToggle(
      viewMode: _viewMode,
      onChanged: (mode) => setState(() => _viewMode = mode),
    );

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          'Services',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.textPrimary(context),
          ),
        ),
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: Icon(LucideIcons.refreshCw, color: AppTheme.accent(context), size: 17),
            tooltip: 'Refresh',
            onPressed: () async {
              await context.read<ServiceEntryProvider>().fetchServices();
            },
          ),
          if (isWide) ...[
            viewModeToggleWidget,
            const SizedBox(width: 8),
            SizedBox(
              width: 220,
              height: 38,
              child: _buildSearchField(),
            ),
            const SizedBox(width: 8),
            _buildDatePickerButton(),
            if (hasActiveFilter) ...[
              const SizedBox(width: 8),
              _buildResetButton(),
            ],
            const SizedBox(width: 8),
            _buildExportButton(filteredServices),
            const SizedBox(width: 8),
            _buildAddServiceButton(),
            const SizedBox(width: 14),
          ] else ...[
            viewModeToggleWidget,
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Export PDF',
              icon: Icon(LucideIcons.fileDown, size: 18, color: AppTheme.accent(context)),
              onPressed: filteredServices.isEmpty ? null : () => _exportToPdf(context, filteredServices),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 6),
              _buildAddServiceButton(),
              const SizedBox(width: 8),
            ],
          ],
        ],
      ),
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: _openCreateServiceDialog,
              backgroundColor: AppTheme.accent(context),
              foregroundColor: Colors.white,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text(
                'Add Service',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                  Expanded(child: _buildSearchField()),
                  const SizedBox(width: 6),
                  _buildDatePickerButton(),
                  if (hasActiveFilter) ...[
                    const SizedBox(width: 6),
                    _buildResetButton(),
                  ],
                ],
              ),
            ),
          Row(
            children: [
              Expanded(child: _buildFilterBar(provider.services, users, filteredServices.length)),
              Container(
                width: 453,
                child: _buildSummaryBar(context, filteredServices),
              ),
            ],
          ),
          Expanded(
            child: Consumer<ServiceEntryProvider>(
              builder: (context, prov, _) {
                if (prov.isLoading && prov.services.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0D9488)),
                  );
                }

                if (prov.errorMessage != null && prov.services.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.alertCircle,
                              size: 48, color: Colors.red.shade300),
                          const SizedBox(height: 12),
                          Text(
                            prov.errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: prov.isLoading ? null : prov.fetchServices,
                            icon: const Icon(LucideIcons.refreshCw, size: 15),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (filteredServices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceBg(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.wrench,
                              size: 38, color: AppTheme.textSecondary(context)),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          hasActiveFilter
                              ? 'No matching services found'
                              : 'No services found',
                          style: TextStyle(
                            color: AppTheme.textSecondary(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: _viewMode == ViewMode.table
                          ? _ServicesTableView(
                              services: filteredServices,
                              customers: customers,
                              onTap: _openServiceDetailsDialog,
                              onEdit: _openEditServiceDialog,
                              onDelete: _deleteService,
                              statusColor: _statusColor,
                                contactActions: (service) => PopupMenuButton<String>(
  color: AppTheme.surfaceBg(context),
  elevation: 6,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(color: AppTheme.textSecondary(context), width: 0.6),
  ),
  padding: EdgeInsets.zero,
  offset: const Offset(0, 8),
  onSelected: (value) async {
    final phone = customerPhone(service, customers);
    if (phone == null || phone.trim().isEmpty) return;
    if (value == 'Call') {
      _callCustomer(phone);
    } else if (value == 'Whatsapp') {
      _whatsappCustomer(phone);
    }
  },
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
    decoration: BoxDecoration(
      color: AppTheme.accent(context).withOpacity(0.08),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(
        color: AppTheme.accent(context).withOpacity(0.25),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.phone, size: 13, color: AppTheme.accent(context)),
        const SizedBox(width: 6),
        Text(
          customerPhone(service, customers).toString(),
          style: TextStyle(
            color: AppTheme.textSecondary(context),
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
       
        
      ],
    ),
  ),
  itemBuilder: (_) => [
    PopupMenuItem(
      value: 'Call',
      height: 42,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.accent(context).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.phone, size: 14, color: AppTheme.accent(context)),
          ),
          const SizedBox(width: 10),
          Text(
            'Call',
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
    const PopupMenuDivider(height: 4),
    PopupMenuItem(
      value: 'Whatsapp',
      height: 42,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.messageSquare, size: 14, color: Colors.green),
          ),
          const SizedBox(width: 10),
          Text(
            'Whatsapp',
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  ],
)
                                
                                 ,
                            )
                          : _buildGridView(filteredServices, customers),
                    ),
                    
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Grid View ─────────────────────────────────────────────────────────────
  Widget _buildGridView(
      List<ServiceEntry> filteredServices, List<Customer> customers) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: filteredServices.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getGridColumns(context),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 103,
      ),
      itemBuilder: (context, index) {
        final service = filteredServices[index];
        final balance = service.balanceAmount;

        return GestureDetector(
          onTap: () => _openServiceDetailsDialog(service),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cardBorderColor(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      service.title,
                                      style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                                                DateFormat('dd MMM yyyy').format(service.serviceDate),
                                                                style: TextStyle(
                                                                  fontSize: 11.5,
                                                                  color: AppTheme.textSecondary(context),
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),Text(
                                                                service.addedByName != null ? ' • ${service.addedByName}' : '',
                                                                style: TextStyle(
                                                                  fontSize: 11.5,
                                                                  color: AppTheme.textSecondary(context),
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                              SizedBox(width: 6),
                                                              PopupMenuButton<String>(
                                                                color: AppTheme.surfaceBg(context),  padding: EdgeInsets.zero,child: Icon(LucideIcons.moreVertical,
                                                                    size: 16, color: AppTheme.textSecondary(context)),
                                                                onSelected: (value) async {
                                                                  if (value == 'view') {
                                                                    _openServiceDetailsDialog(service);
                                                                  } else if (value == 'edit') {
                                                                    _openEditServiceDialog(service);
                                                                  } else if (value == 'delete') {
                                                                    _deleteService(service);
                                                                  }
                                                                },
                                                               
                                                                itemBuilder: (_) => [
                                                                  PopupMenuItem(
                                                                    value: 'view',
                                                                    child: Row(
                                                                      children: [
                                      Icon(LucideIcons.eye,
                                          size: 15, color: AppTheme.accent(context)),
                                      const SizedBox(width: 8),
                                      Text('View Details', style: TextStyle(color: AppTheme.textPrimary(context))),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  PopupMenuItem(
                                                                    value: 'edit',
                                                                    child: Row(
                                                                      children: [
                                      const Icon(LucideIcons.edit,
                                          size: 15, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Text('Edit Service', style: TextStyle(color: AppTheme.textPrimary(context))),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  const PopupMenuItem(
                                                                    value: 'delete',
                                                                    child: Row(
                                                                      children: [
                                      Icon(LucideIcons.trash2,
                                          size: 15, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete',
                                          style: TextStyle(color: Colors.red)),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            service.customerName,
                                            style: TextStyle(
                                              color: AppTheme.textSecondary(context),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                       
                                        if (service.softwareName != null && service.softwareName!.isNotEmpty) ...[
                                          Text(
                                            ' • ${service.softwareName!}',
                                            style: TextStyle(
                                              color: AppTheme.accent(context),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                    ],
                                    ),
                                  ),
                                
                                 PopupMenuButton<String>(
  color: AppTheme.surfaceBg(context),
  elevation: 6,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(color: AppTheme.textSecondary(context), width: 0.6),
  ),
  padding: EdgeInsets.zero,
  offset: const Offset(0, 8),
  onSelected: (value) async {
    final phone = customerPhone(service, customers);
    if (phone == null || phone.trim().isEmpty) return;
    if (value == 'Call') {
      _callCustomer(phone);
    } else if (value == 'Whatsapp') {
      _whatsappCustomer(phone);
    }
  },
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
    decoration: BoxDecoration(
      color: AppTheme.accent(context).withOpacity(0.08),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(
        color: AppTheme.accent(context).withOpacity(0.25),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.phone, size: 13, color: AppTheme.accent(context)),
        const SizedBox(width: 6),
        Text(
          customerPhone(service, customers).toString(),
          style: TextStyle(
            color: AppTheme.textSecondary(context),
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
       
        
      ],
    ),
  ),
  itemBuilder: (_) => [
    PopupMenuItem(
      value: 'Call',
      height: 42,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.accent(context).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.phone, size: 14, color: AppTheme.accent(context)),
          ),
          const SizedBox(width: 10),
          Text(
            'Call',
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
    const PopupMenuDivider(height: 4),
    PopupMenuItem(
      value: 'Whatsapp',
      height: 42,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.messageSquare, size: 14, color: Colors.green),
          ),
          const SizedBox(width: 10),
          Text(
            'Whatsapp',
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  ],
)
                                
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                      ],
                    ),
                    
                    
                    
                    // const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                       
                        Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: _AmountBox(
                                label: 'Total',
                                value: service.amount,
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 70,
                              child: _AmountBox(
                                label: 'Paid',
                                value: service.customerPaidAmount,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 70,
                              child: _AmountBox(
                                label: _balanceLabel(balance),
                                value: balance,
                                color: _balanceColor(balance),
                              ),
                            ),
                          ],
                        ),
                   
                   
                    Row(
                          children: [
                            _MiniChip(
                              header: 'Payment',
                              label: service.paymentStatus,
                              color: _statusColor(service.paymentStatus),
                            ),
                            const SizedBox(width: 4),
                            _MiniChip(
                              header: 'Status',
                              label: service.serviceStatus,
                              color: _statusColor(service.serviceStatus),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View Mode Toggle Control
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
        color: AppTheme.surfaceBg(context),
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
                ? (AppTheme.isDark(context) ? FuturisticColors.bgCardHover : Colors.white)
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
            color: isSelected ? AppTheme.accent(context) : AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modern Services Table View
// ─────────────────────────────────────────────────────────────────────────────

class _ServicesTableView extends StatelessWidget {
  final List<ServiceEntry> services;
  final List<Customer> customers;
  final Function(ServiceEntry) onTap;
  final Function(ServiceEntry) onEdit;
  final Function(ServiceEntry) onDelete;
  final Color Function(String) statusColor;
  final Widget Function(ServiceEntry) contactActions;

  const _ServicesTableView({
    required this.services,
    required this.customers,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.statusColor,
    required this.contactActions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorderColor(context), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.surfaceBg(context)),
              headingRowHeight: 35,
              dataRowMinHeight: 35,
              dataRowMaxHeight: 40,
              horizontalMargin: 15,
              columnSpacing: 15,
              dividerThickness: 1,
              columns: [
                DataColumn(
                  label: Text(
                    'SERVICE & CUSTOMER',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'PHONE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'DATE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'PAYMENT STATUS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'SERVICE STATUS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'TOTAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'PAID',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'BALANCE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary(context),
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
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
              rows: services.map((service) {
                final balance = service.balanceAmount;
                final payColor = statusColor(service.paymentStatus);
                final srvColor = statusColor(service.serviceStatus);

                return DataRow(
                  color: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return isDark ? FuturisticColors.bgCardHover : const Color(0xFFF8FAFC);
                    }
                    return AppTheme.cardBg(context);
                  }),
                  cells: [
                    // Title & Customer Name
                    DataCell(
                      InkWell(
                        onTap: () => onTap(service),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppTheme.accent(context).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                LucideIcons.wrench,
                                size: 16,
                                color: AppTheme.accent(context),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  service.title,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      service.customerName,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppTheme.textSecondary(context),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    // contactActions(service),
                                    if (service.softwareName != null && service.softwareName!.isNotEmpty) ...[
                                      Text(
                                        ' • ${service.softwareName!}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.accent(context),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
DataCell(
                      contactActions(service),
                    ),
                    // Date
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.calendar,
                              size: 13, color: AppTheme.textSecondary(context)),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd MMM yyyy').format(service.serviceDate),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            service.addedByName != null ? ' • ${service.addedByName}' : '',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Payment Status
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: payColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          service.paymentStatus,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: payColor,
                          ),
                        ),
                      ),
                    ),

                    // Service Status
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: srvColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          service.serviceStatus,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: srvColor,
                          ),
                        ),
                      ),
                    ),

                    // Total
                    DataCell(
                      Text(
                        service.amount.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                    ),

                    // Paid
                    DataCell(
                      Text(
                        service.customerPaidAmount.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),

                    // Balance
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _balanceColor(balance).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _balanceColor(balance).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${balance.toStringAsFixed(2)}  ${_balanceLabel(balance).toUpperCase()}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _balanceColor(balance),
                          ),
                        ),
                      ),
                    ),

                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(LucideIcons.eye, size: 16),
                            color: AppTheme.accent(context),
                            tooltip: 'View Details',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: () => onTap(service),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(LucideIcons.edit, size: 16),
                            color: Colors.blue.shade600,
                            tooltip: 'Edit Service',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: () => onEdit(service),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2, size: 16),
                            color: Colors.red.shade500,
                            tooltip: 'Delete Service',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: () => onDelete(service),
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
// Summary Footer Bar & Helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _buildSummaryBar(BuildContext context, List<ServiceEntry> services) {
  final totalServices = services.length;
  final totalAmount = services.fold<double>(0, (sum, s) => sum + s.amount);
  final totalPaid = services.fold<double>(0, (sum, s) => sum + s.customerPaidAmount);
  final totalBalance = services.fold<double>(0, (sum, s) => sum + s.balanceAmount);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10.0),
    child: Row(
      children: [
        const Spacer(),
        SizedBox(
          width: 70,
          child: _AmountBox(
            label: 'Services',
            value: totalServices.toDouble(),
            color: AppTheme.accent(context),
          ),
        ),
        _divider(context),
        SizedBox(
          width: 100,
          child: _AmountBox(
            label: 'Total Amount',
            value: totalAmount,
            color: AppTheme.textPrimary(context),
          ),
        ),
        _divider(context),
        SizedBox(
          width: 100,
          child: _AmountBox(
            label: 'Total Paid',
            value: totalPaid,
            color: const Color(0xFF10B981),
          ),
        ),
        _divider(context),
        SizedBox(
          width: 100,
          child: _AmountBox(
            label: 'Total Balance',
            value: totalBalance,
            color: totalBalance > 0 ? Colors.red.shade700 : const Color(0xFF10B981),
          ),
        ),
      ],
    ),
  );
}

Widget _divider(BuildContext context) {
  return Container(
    height: 32,
    width: 1,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: AppTheme.cardBorderColor(context),
  );
}

Future<void> _exportToPdf(BuildContext context, List<ServiceEntry> services) async {
  final totalAmount = services.fold<double>(0, (s, e) => s + e.amount);
  final totalPaid = services.fold<double>(0, (s, e) => s + e.customerPaidAmount);
  final totalBalance = services.fold<double>(0, (s, e) => s + e.balanceAmount);

  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(22),
      footer: (context) => PdfThemeHelper.buildPageFooter(
        context: context,
        documentName: 'Services Report | Total: SAR ${totalAmount.toStringAsFixed(2)}',
      ),
      build: (context) => [
        // Header
        PdfThemeHelper.buildDocumentHeader(
          title: 'SERVICES & WORK ORDERS REPORT',
          subtitle: 'Comprehensive overview of service engagements, billing, and progress status',
          badgeText: '${services.length} Services',
        ),

        // KPI Metric Cards
        PdfThemeHelper.buildKpiCardsRow([
          PdfKpiItem(
            label: 'Total Invoiced',
            value: 'SAR ${totalAmount.toStringAsFixed(2)}',
            color: PdfThemeHelper.darkSlate,
          ),
          PdfKpiItem(
            label: 'Total Collected',
            value: 'SAR ${totalPaid.toStringAsFixed(2)}',
            color: PdfThemeHelper.emeraldGreen,
          ),
          PdfKpiItem(
            label: 'Balance Outstanding',
            value: 'SAR ${totalBalance.toStringAsFixed(2)}',
            color: totalBalance > 0 ? PdfThemeHelper.roseRed : PdfThemeHelper.emeraldGreen,
          ),
          PdfKpiItem(
            label: 'Total Services',
            value: '${services.length}',
            color: PdfThemeHelper.primaryTealDark,
          ),
        ]),

        PdfThemeHelper.buildSectionHeader(
          'SERVICE RECORDS',
          countText: '${services.length} records',
        ),

        // Table
        pw.Container(
          decoration: pw.BoxDecoration(
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: PdfThemeHelper.borderColor, width: 0.8),
          ),
          child: pw.ClipRRect(
            horizontalRadius: 6,
            verticalRadius: 6,
            child: pw.Table(
              columnWidths: {
                0: const pw.FixedColumnWidth(26), // #
                1: const pw.FlexColumnWidth(2.6), // Title
                2: const pw.FlexColumnWidth(2.4), // Customer
                3: const pw.FlexColumnWidth(2.0), // Software
                4: const pw.FlexColumnWidth(1.6), // Date
                5: const pw.FlexColumnWidth(1.4), // Total
                6: const pw.FlexColumnWidth(1.4), // Paid
                7: const pw.FlexColumnWidth(1.4), // Balance
                8: const pw.FlexColumnWidth(1.4), // Payment Status
                9: const pw.FlexColumnWidth(1.6), // Service Status
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfThemeHelper.darkSlate,
                  ),
                  children: [
                    _pdfServiceCell('#', isHeader: true, alignCenter: true),
                    _pdfServiceCell('Service Title', isHeader: true),
                    _pdfServiceCell('Customer', isHeader: true),
                    _pdfServiceCell('Software', isHeader: true),
                    _pdfServiceCell('Date', isHeader: true),
                    _pdfServiceCell('Total (SAR)', isHeader: true, alignRight: true),
                    _pdfServiceCell('Paid (SAR)', isHeader: true, alignRight: true),
                    _pdfServiceCell('Balance (SAR)', isHeader: true, alignRight: true),
                    _pdfServiceCell('Payment', isHeader: true),
                    _pdfServiceCell('Status', isHeader: true),
                  ],
                ),

                // Data Rows
                ...services.asMap().entries.map((entry) {
                  final index = entry.key;
                  final s = entry.value;
                  final isEven = index % 2 == 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.white : PdfThemeHelper.surfaceBg,
                    ),
                    children: [
                      _pdfServiceCell('${index + 1}', alignCenter: true, fontSize: 8),
                      _pdfServiceCell(s.title, isBold: true, fontSize: 8),
                      _pdfServiceCell(s.customerName, fontSize: 8),
                        _pdfServiceCell(
                        s.softwareName?.trim().isNotEmpty == true
                          ? s.softwareName!.trim()
                          : 'No software',
                        fontSize: 8,
                        color: s.softwareName?.trim().isNotEmpty == true
                          ? PdfThemeHelper.darkSlate
                          : PdfThemeHelper.textMuted,
                        ),
                      _pdfServiceCell(
                        DateFormat('dd/MM/yyyy').format(s.serviceDate),
                        fontSize: 7.5,
                        color: PdfThemeHelper.textMuted,
                      ),
                      _pdfServiceCell(
                        s.amount.toStringAsFixed(2),
                        alignRight: true,
                        isBold: true,
                        fontSize: 8,
                      ),
                      _pdfServiceCell(
                        s.customerPaidAmount.toStringAsFixed(2),
                        alignRight: true,
                        fontSize: 8,
                        color: PdfThemeHelper.emeraldGreen,
                      ),
                      _pdfServiceCell(
                        s.balanceAmount.toStringAsFixed(2),
                        alignRight: true,
                        fontSize: 8,
                        color: s.balanceAmount > 0
                            ? PdfThemeHelper.roseRed
                            : PdfThemeHelper.emeraldGreen,
                        isBold: s.balanceAmount > 0,
                      ),
                      _pdfServiceBadgeCell(s.paymentStatus),
                      _pdfServiceBadgeCell(s.serviceStatus),
                    ],
                  );
                }),

                // Summary Total Footer
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfThemeHelper.zebraBg,
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfThemeHelper.borderColor, width: 1),
                    ),
                  ),
                  children: [
                    _pdfServiceCell(''),
                    _pdfServiceCell('Grand Total', isBold: true),
                    _pdfServiceCell(''),
                    _pdfServiceCell(''),
                    _pdfServiceCell(''),
                    _pdfServiceCell(
                      totalAmount.toStringAsFixed(2),
                      alignRight: true,
                      isBold: true,
                      fontSize: 8.5,
                    ),
                    _pdfServiceCell(
                      totalPaid.toStringAsFixed(2),
                      alignRight: true,
                      isBold: true,
                      fontSize: 8.5,
                      color: PdfThemeHelper.emeraldGreen,
                    ),
                    _pdfServiceCell(
                      totalBalance.toStringAsFixed(2),
                      alignRight: true,
                      isBold: true,
                      fontSize: 8.5,
                      color: totalBalance > 0 ? PdfThemeHelper.roseRed : PdfThemeHelper.emeraldGreen,
                    ),
                    _pdfServiceCell(''),
                    _pdfServiceCell(''),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  final bytes = await pdf.save();
  final filename =
      'services_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
  await showPdfActionsSheet(context: context, bytes: bytes, filename: filename);
}

pw.Widget _pdfServiceCell(
  String text, {
  bool isHeader = false,
  bool isBold = false,
  bool alignRight = false,
  bool alignCenter = false,
  double fontSize = 8.5,
  PdfColor? color,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    child: pw.Text(
      text,
      textAlign: alignRight
          ? pw.TextAlign.right
          : (alignCenter ? pw.TextAlign.center : pw.TextAlign.left),
      style: pw.TextStyle(
        fontSize: isHeader ? 8 : fontSize,
        fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: isHeader ? PdfColors.white : (color ?? PdfThemeHelper.darkSlate),
      ),
    ),
  );
}

pw.Widget _pdfServiceBadgeCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
    child: PdfThemeHelper.buildStatusBadge(text),
  );
}

class _MiniChip extends StatelessWidget {
  final String label;
  final String header;
  final Color color;
  const _MiniChip(
      {required this.label, required this.header, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header,
            style: TextStyle(
              color: AppTheme.textSecondary(context),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.08) ?? AppTheme.surfaceBg(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color?.withValues(alpha: 0.25) ?? AppTheme.cardBorderColor(context),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary(context)),
          ),
          Text(
            value.toStringAsFixed(0),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color ?? AppTheme.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}