import 'package:dropdown_search/dropdown_search.dart';
import 'package:entryon/models/customer_model.dart';
import 'package:entryon/providers/auth_Provider.dart';
import 'package:entryon/providers/customer_provider.dart';
import 'package:entryon/providers/edit_service_provider.dart';
import 'package:entryon/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/service_model.dart';
import '../providers/service_entry_provider.dart';
import '../utils/app_theme.dart';
import './createCustomerScreen.dart';

class EditServiceEntryScreen extends StatefulWidget {
  final String serviceId;
  const EditServiceEntryScreen({super.key, required this.serviceId});

  @override
  State<EditServiceEntryScreen> createState() => _EditServiceEntryScreenState();
}

class _EditServiceEntryScreenState extends State<EditServiceEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _serviceFeeController = TextEditingController(text: '0');
  final _purchaseNameController = TextEditingController();
  final _purchaseCostController = TextEditingController();

  DateTime _serviceDate = DateTime.now();
  DateTime? _paymentExpiryDate;
  String _paymentStatus = 'Pending';
  String _serviceStatus = 'Pending';
  String? _paymentType = 'Cash';
  Customer? _selectedCustomer;
  _CustomerSoftwareDevice? _selectedSoftwareDevice;
  _CustomerStaff? _selectedStaff;
  _ServiceSuggestion? _selectedServiceSuggestion;
  List<ServicePurchaseLine> _purchaseLines = [];
  List<_ServiceSuggestion> _serviceSuggestions = [];
  bool _isSaving = false;
  bool _isLoading = true;
  String _addedById = '';
  String _addedByName = '';

  // ── Dropdown Option Definitions ──────────────────────────────────────────

  static const List<_DropdownOption> _paymentMethods = [
    _DropdownOption(
      value: 'Cash',
      label: 'Cash',
      description: 'Instant cash payment',
      icon: LucideIcons.banknote,
      color: Color(0xFF059669),
    ),
    _DropdownOption(
      value: 'Card',
      label: 'Card',
      description: 'POS / Credit / Debit card swipe',
      icon: LucideIcons.creditCard,
      color: Color(0xFF2563EB),
    ),
    _DropdownOption(
      value: 'Acasiya',
      label: 'Acasiya',
      description: 'Acasiya corporate transfer',
      icon: LucideIcons.building,
      color: Color(0xFF7C3AED),
    ),
    _DropdownOption(
      value: 'Darwish Alrajhi',
      label: 'Darwish Alrajhi',
      description: 'Darwish Al Rajhi bank transfer',
      icon: LucideIcons.landmark,
      color: Color(0xFF0D9488),
    ),
    _DropdownOption(
      value: 'Jeel Hasinath',
      label: 'Jeel Hasinath',
      description: 'Jeel Hasinath account transfer',
      icon: LucideIcons.wallet2,
      color: Color(0xFF4F46E5),
    ),
    _DropdownOption(
      value: 'Shafeeq Alinma',
      label: 'Shafeeq Alinma',
      description: 'Shafeeq Alinma bank transfer',
      icon: LucideIcons.coins,
      color: Color(0xFFD97706),
    ),
  ];

  static const List<_DropdownOption> _paymentStatusOptions = [
    _DropdownOption(
      value: 'Pending',
      label: 'Pending',
      description: 'Payment awaiting collection',
      icon: LucideIcons.clock,
      color: Color(0xFF6366F1),
    ),
    _DropdownOption(
      value: 'Partial',
      label: 'Partial',
      description: 'Partial advance collected',
      icon: LucideIcons.alertCircle,
      color: Color(0xFFF59E0B),
    ),
    _DropdownOption(
      value: 'Paid',
      label: 'Paid',
      description: 'Amount fully settled',
      icon: LucideIcons.checkCircle2,
      color: Color(0xFF10B981),
    ),
    _DropdownOption(
      value: 'Free',
      label: 'Free',
      description: 'Complimentary / free service',
      icon: LucideIcons.gift,
      color: Color(0xFF0EA5E9),
    ),
  ];

  static const List<_DropdownOption> _serviceStatusOptions = [
    _DropdownOption(
      value: 'Pending',
      label: 'Pending',
      description: 'Service queued & scheduled',
      icon: LucideIcons.clock,
      color: Color(0xFF6366F1),
    ),
    _DropdownOption(
      value: 'Work In Progress',
      label: 'Work In Progress',
      description: 'Actively in maintenance',
      icon: LucideIcons.wrench,
      color: Color(0xFFF59E0B),
    ),
    _DropdownOption(
      value: 'Completed',
      label: 'Completed',
      description: 'Service fulfilled & closed',
      icon: LucideIcons.checkCircle2,
      color: Color(0xFF10B981),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final customerProvider = context.read<CustomerProvider>();
      final editServiceProvider = context.read<EditServiceProvider>();

      await customerProvider.fetchCustomers();
      if (!mounted) return;
      _loadServiceSuggestions();

      final success = await editServiceProvider.fetchServiceById(widget.serviceId);
      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service record not found')));
        Navigator.pop(context);
        return;
      }

      final service = editServiceProvider.service!;
      _titleController.text = service.title;
      _descriptionController.text = service.description ?? '';
      _purchaseLines = List.from(service.purchaseLines);
      _serviceFeeController.text = service.serviceFee.toStringAsFixed(2);
      _amountController.text = service.amount.toStringAsFixed(2);
      _serviceDate = service.serviceDate;
      _paymentExpiryDate = service.paymentExpiryDate;
      _paymentStatus = _normalizePaymentStatus(service.paymentStatus);
      _serviceStatus = _normalizeServiceStatus(service.serviceStatus);
      _paymentType = _normalizePaymentType(service.paymentType);
      _paidAmountController.text = service.customerPaidAmount.toStringAsFixed(2);
      _addedById = service.addedById ?? '';
      _addedByName = service.addedByName ?? '';

      // Match customer from ID or Name
      final allCustomers = customerProvider.customers;
      if (service.customerId != null && service.customerId!.isNotEmpty) {
        _selectedCustomer = allCustomers.cast<Customer?>().firstWhere(
              (c) => c?.id == service.customerId,
              orElse: () => null,
            );
      }
      if (_selectedCustomer == null && service.customerName.isNotEmpty) {
        _selectedCustomer = allCustomers.cast<Customer?>().firstWhere(
              (c) => c?.name.toLowerCase().trim() == service.customerName.toLowerCase().trim(),
              orElse: () => null,
            );
      }

      // Match software device
      if (_selectedCustomer != null) {
        final swOptions = _getSoftwareDeviceOptions(_selectedCustomer);
        if (service.softwareName != null && service.softwareName!.isNotEmpty) {
          _selectedSoftwareDevice = swOptions.cast<_CustomerSoftwareDevice?>().firstWhere(
                (opt) => opt?.displayName == service.softwareName || opt?.softwareName == service.softwareName,
                orElse: () => _CustomerSoftwareDevice(
                  softwareName: service.softwareName!,
                  branchName: service.branchName,
                ),
              );
        }

        // Match staff member
        final staffOptions = _getStaffOptions(_selectedCustomer);
        if (service.staffName != null && service.staffName!.isNotEmpty) {
          _selectedStaff = staffOptions.cast<_CustomerStaff?>().firstWhere(
                (opt) => opt?.name == service.staffName,
                orElse: () => _CustomerStaff(
                  name: service.staffName!,
                  phone: service.staffPhone ?? '',
                  branchName: service.branchName,
                ),
              );
        }
      }

      setState(() => _isLoading = false);
    });
  }

  Future<void> _loadServiceSuggestions() async {
    try {
      final serviceProvider = context.read<ServiceEntryProvider>();
      if (serviceProvider.services.isEmpty) {
        await serviceProvider.fetchServices();
      }

      final grouped = <String, List<ServiceEntry>>{};
      for (final service in serviceProvider.services) {
        final title = service.title.trim();
        if (title.isEmpty) continue;
        grouped.putIfAbsent(title, () => <ServiceEntry>[]).add(service);
      }

      final suggestions = grouped.entries.map((entry) {
        final services = [...entry.value]..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
        final latestService = services.first;
        final averageAmount = services.fold<double>(0, (sum, s) => sum + s.amount) / services.length;

        return _ServiceSuggestion(
          title: entry.key,
          amount: latestService.amount,
          averageAmount: averageAmount,
          count: services.length,
        );
      }).toList();

      suggestions.sort((a, b) => b.count.compareTo(a.count));

      if (mounted) {
        setState(() => _serviceSuggestions = suggestions);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _serviceSuggestions = const []);
      }
    }
  }

  Future<void> _pickDate({required bool payment}) async {
    final isDark = AppTheme.isDark(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: payment ? (_paymentExpiryDate ?? DateTime.now()) : _serviceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: FuturisticColors.neonCyan,
                    onPrimary: FuturisticColors.bgVoid,
                    surface: FuturisticColors.bgCard,
                    onSurface: FuturisticColors.textPrimary,
                  )
                : const ColorScheme.light(
                    primary: Colors.teal,
                    onPrimary: Colors.white,
                    onSurface: Color(0xFF0F172A),
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => payment ? _paymentExpiryDate = picked : _serviceDate = picked);
    }
  }

  void _addPurchaseLine() {
    final name = _purchaseNameController.text.trim();
    final cost = double.tryParse(_purchaseCostController.text.trim()) ?? 0;
    if (name.isEmpty) return;

    setState(() {
      _purchaseLines.add(ServicePurchaseLine(
        id: DateTime.now().toIso8601String(),
        purchaseName: name,
        cost: cost,
      ));
      _purchaseNameController.clear();
      _purchaseCostController.clear();
      _amountController.text = ServiceEntry.calculateTotalAmount(
        purchaseLines: _purchaseLines,
        serviceCost: double.tryParse(_serviceFeeController.text.trim()) ?? 0,
      ).toStringAsFixed(2);
    });
  }

  void _removePurchaseLine(int index) {
    setState(() {
      _purchaseLines.removeAt(index);
      _amountController.text = ServiceEntry.calculateTotalAmount(
        purchaseLines: _purchaseLines,
        serviceCost: double.tryParse(_serviceFeeController.text.trim()) ?? 0,
      ).toStringAsFixed(2);
    });
  }

  double get _totalPurchasesCost => _purchaseLines.fold<double>(0.0, (sum, line) => sum + line.cost);

  double get _totalServiceCost => ServiceEntry.calculateTotalAmount(
        purchaseLines: _purchaseLines,
        serviceCost: double.tryParse(_serviceFeeController.text.trim()) ?? 0,
      );

  double get _balanceAmount =>
      _totalServiceCost - (double.tryParse(_paidAmountController.text.trim()) ?? 0);

  String _normalizePaymentStatus(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized == 'partial' || normalized == 'partially' || normalized == 'partially paid') {
      return 'Partial';
    }
    if (normalized == 'paid' || normalized == 'complete' || normalized == 'completed') {
      return 'Paid';
    }
    if (normalized == 'free') {
      return 'Free';
    }
    return 'Pending';
  }

  String _normalizeServiceStatus(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized == 'in progress' ||
        normalized == 'inprogress' ||
        normalized == 'work in progress' ||
        normalized == 'workinprogress' ||
        normalized == 'ongoing' ||
        normalized == 'progress') {
      return 'Work In Progress';
    }
    if (normalized == 'completed' || normalized == 'complete' || normalized == 'done') {
      return 'Completed';
    }
    return 'Pending';
  }

  String _normalizePaymentType(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized == 'card' || normalized == 'credit card' || normalized == 'credit') {
      return 'Card';
    }
    if (normalized == 'acasiya') {
      return 'Acasiya';
    }
    if (normalized == 'darwish alrajhi' || normalized == 'darwish') {
      return 'Darwish Alrajhi';
    }
    if (normalized == 'jeel hasinath' || normalized == 'jeel') {
      return 'Jeel Hasinath';
    }
    if (normalized == 'shafeeq alinma' || normalized == 'shafeeq') {
      return 'Shafeeq Alinma';
    }
    return 'Cash';
  }

  List<_CustomerSoftwareDevice> _getSoftwareDeviceOptions(Customer? customer) {
    if (customer == null) return [];
    final list = <_CustomerSoftwareDevice>[];
    final seen = <String>{};

    void addOption(_CustomerSoftwareDevice opt) {
      final key = '${opt.softwareName}|${opt.deviceLabel ?? ''}|${opt.branchName ?? ''}|${opt.activationKey ?? ''}';
      if (!seen.contains(key)) {
        seen.add(key);
        list.add(opt);
      }
    }

    // 1. Customer level activations
    for (final act in customer.softwareActivations) {
      final sName = (act['name'] ?? act['softwareName'] ?? '').toString().trim();
      if (sName.isNotEmpty) {
        final dLabel = (act['deviceLabel'] ?? act['deviceType'] ?? '').toString().trim();
        addOption(_CustomerSoftwareDevice(
          softwareName: sName,
          deviceLabel: dLabel.isNotEmpty ? dLabel : null,
          activationKey: act['activationKey']?.toString(),
          userId: act['activationUserId']?.toString(),
        ));
      }
    }

    // 2. Customer level used softwares
    for (final sw in customer.usedSoftwares) {
      final sName = sw.trim();
      if (sName.isNotEmpty) {
        addOption(_CustomerSoftwareDevice(softwareName: sName));
      }
    }

    // 3. Branch level activations & used softwares
    for (final branch in customer.branches) {
      final bName = branch.name.trim().isNotEmpty ? branch.name.trim() : null;
      for (final act in branch.softwareActivations) {
        final sName = (act['name'] ?? act['softwareName'] ?? '').toString().trim();
        if (sName.isNotEmpty) {
          final dLabel = (act['deviceLabel'] ?? act['deviceType'] ?? '').toString().trim();
          addOption(_CustomerSoftwareDevice(
            softwareName: sName,
            deviceLabel: dLabel.isNotEmpty ? dLabel : null,
            branchName: bName,
            activationKey: act['activationKey']?.toString(),
            userId: act['activationUserId']?.toString(),
          ));
        }
      }
      for (final sw in branch.usedSoftwares) {
        final sName = sw.trim();
        if (sName.isNotEmpty) {
          addOption(_CustomerSoftwareDevice(
            softwareName: sName,
            branchName: bName,
          ));
        }
      }
    }

    return list;
  }

  List<_CustomerStaff> _getStaffOptions(Customer? customer) {
    if (customer == null) return [];
    final list = <_CustomerStaff>[];
    final seen = <String>{};

    void addOption(_CustomerStaff opt) {
      final key = '${opt.name}|${opt.phone}|${opt.branchName ?? ''}';
      if (!seen.contains(key)) {
        seen.add(key);
        list.add(opt);
      }
    }

    // 1. Customer level staff
    for (final s in customer.staff) {
      if (s.name.trim().isNotEmpty) {
        addOption(_CustomerStaff(
          name: s.name.trim(),
          phone: s.phone.trim(),
        ));
      }
    }

    // 2. Branch level staff
    for (final branch in customer.branches) {
      final bName = branch.name.trim().isNotEmpty ? branch.name.trim() : null;
      for (final s in branch.staff) {
        if (s.name.trim().isNotEmpty) {
          addOption(_CustomerStaff(
            name: s.name.trim(),
            phone: s.phone.trim(),
            branchName: bName,
          ));
        }
      }
    }

    return list;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final auth = context.read<AuthProvider>();

    final success = await context.read<ServiceEntryProvider>().updateService(
      id: widget.serviceId,
      title: _titleController.text.trim(),
      customerName: _selectedCustomer?.name ?? '',
      customerId: _selectedCustomer?.id,
      branchName: _selectedStaff?.branchName ?? _selectedSoftwareDevice?.branchName,
      staffName: _selectedStaff?.name,
      staffPhone: _selectedStaff?.phone,
      softwareName: _selectedSoftwareDevice?.displayName,
      description: _descriptionController.text.trim(),
      serviceDate: _serviceDate,
      amount: _totalServiceCost,
      serviceFee: double.tryParse(_serviceFeeController.text.trim()) ?? 0,
      customerPaidAmount: double.tryParse(_paidAmountController.text.trim()) ?? 0,
      paymentStatus: _paymentStatus,
      serviceStatus: _serviceStatus,
      paymentType: _paymentType ?? 'Cash',
      paymentExpiryDate: _paymentExpiryDate,
      purchaseLines: _purchaseLines,
      addedById: _addedById,
      addedByName: _addedByName,
      editedById: auth.currentUserId,
      editedByName: auth.currentUserName,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Service entry updated successfully!'),
            ],
          ),
          backgroundColor: const Color(0xFF0D9488),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(context.read<ServiceEntryProvider>().errorMessage ?? 'Failed to update service')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _paidAmountController.dispose();
    _purchaseNameController.dispose();
    _purchaseCostController.dispose();
    _serviceFeeController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, {Widget? prefixIcon, Widget? suffixIcon, String? hintText}) {
    final isDark = AppTheme.isDark(context);
    final fillColor = isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC);
    final borderColor = isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0);
    final labelColor = isDark ? FuturisticColors.textSecondary : Colors.grey.shade700;
    final hintColor = isDark ? FuturisticColors.textMuted : Colors.grey.shade400;
    final focusColor = isDark ? FuturisticColors.neonCyan : Colors.teal;
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      labelStyle: TextStyle(fontSize: 13, color: labelColor, fontWeight: FontWeight.w500),
      hintStyle: TextStyle(fontSize: 12.5, color: hintColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: focusColor, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? FuturisticColors.neonCrimson : Colors.red.shade300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? FuturisticColors.bgVoid : const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: Text('Edit Service Entry', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A), fontSize: 17)),
          backgroundColor: isDark ? FuturisticColors.bgSurface : Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF334155)),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488)),
        ),
      );
    }

    final isWideScreen = MediaQuery.of(context).size.width >= 960;

    return Scaffold(
      backgroundColor: isDark ? FuturisticColors.bgVoid : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Edit Service Entry',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
            ),
            Text(
              'Update service records, financial details & terminal assignment',
              style: TextStyle(fontSize: 11.5, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B), fontWeight: FontWeight.normal),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.save, size: 16),
              label: Text(_isSaving ? 'Updating...' : 'Update Service', style: const TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                foregroundColor: isDark ? FuturisticColors.bgVoid : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: isWideScreen ? _buildWideLayout() : _buildNarrowLayout(),
      ),
    );
  }

  /// Wide screen layout (Desktop / Large Tablet) with responsive two-column grid
  Widget _buildWideLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column (Primary Service Details & Purchase Lines)
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    _buildServiceInfoCard(),
                    const SizedBox(height: 10),
                    _buildPurchaseLinesCard(),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Right Column (Financials & Payment / Schedule)
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildFinancialCard(),
                    const SizedBox(height: 10),
                    _buildStatusAndScheduleCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Narrow screen layout (Mobile / Portrait Tablet)
  Widget _buildNarrowLayout() {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        _buildServiceInfoCard(),
        const SizedBox(height: 10),
        _buildPurchaseLinesCard(),
        const SizedBox(height: 10),
        _buildFinancialCard(),
        const SizedBox(height: 10),
        _buildStatusAndScheduleCard(),
        const SizedBox(height: 10),
        // Primary mobile update button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(LucideIcons.checkCircle, size: 18),
            label: Text(
              _isSaving ? 'Updating Service...' : 'Update Service Entry',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.isDark(context) ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
              foregroundColor: AppTheme.isDark(context) ? FuturisticColors.bgVoid : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // ── Card 1: Service Information & Customer Selection ───────────────────────

  Widget _buildServiceInfoCard() {
    final customers = context.watch<CustomerProvider>().customers;

    return _buildSectionCard(
      title: 'Service & Customer Scope',
      subtitle: 'Specify service title, customer, device node, and personnel',
      icon: LucideIcons.briefcase,
      accentColor: const Color(0xFF0D9488),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Title with Autocomplete
          Autocomplete<_ServiceSuggestion>(
            optionsBuilder: (textEditingValue) {
              final query = textEditingValue.text.trim();
              if (query.isEmpty) {
                return const Iterable<_ServiceSuggestion>.empty();
              }
              return _serviceSuggestions.where(
                (suggestion) => suggestion.title.toLowerCase().contains(query.toLowerCase()),
              );
            },
            displayStringForOption: (option) => option.title,
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              if (_titleController.text != controller.text) {
                controller.text = _titleController.text;
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length),
                );
              }

              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: _inputDecoration(
                  'Service Title *',
                  hintText: 'e.g., POS Installation, Annual Maintenance...',
                  prefixIcon: const Icon(LucideIcons.wrench, size: 18, color: Color(0xFF0D9488)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Service title is required' : null,
                onChanged: (value) {
                  _titleController.text = value;
                  _titleController.selection = TextSelection.fromPosition(
                    TextPosition(offset: value.length),
                  );

                  if (_selectedServiceSuggestion != null && value.trim() != _selectedServiceSuggestion!.title) {
                    setState(() => _selectedServiceSuggestion = null);
                  }
                },
              );
            },
            onSelected: (suggestion) {
              setState(() {
                _selectedServiceSuggestion = suggestion;
                _titleController.text = suggestion.title;
                _titleController.selection = TextSelection.fromPosition(
                  TextPosition(offset: suggestion.title.length),
                );
                _serviceFeeController.text = suggestion.amount.toStringAsFixed(2);
                _amountController.text = suggestion.amount.toStringAsFixed(2);
              });
            },
            optionsViewBuilder: (context, onSelected, options) {
              final isDark = AppTheme.isDark(context);
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  color: isDark ? FuturisticColors.bgCard : Colors.white,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280, maxWidth: 500),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? FuturisticColors.bgCard : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFF1F5F9)),
                        itemBuilder: (_, index) {
                          final option = options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(option),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isDark ? FuturisticColors.neonCyan.withValues(alpha: 0.15) : const Color(0xFFCCFBF1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(LucideIcons.history, color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488), size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      option.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? FuturisticColors.textPrimary : const Color(0xFF1E293B),
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  _suggestionBadge(
                                    label: 'Last: SAR ${option.amount.toStringAsFixed(2)}',
                                    color: Colors.teal,
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // Customer Search & Select Dropdown with Enhanced Item Builder & In-field Preview
          Builder(builder: (context) {
            final isDark = AppTheme.isDark(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          DropdownSearch<Customer>(
            items: (filter, infiniteScrollProps) => customers,
            compareFn: (item1, item2) => item1.id == item2.id,
            itemAsString: (Customer c) => c.name,
            selectedItem: _selectedCustomer,
            onChanged: (v) {
              setState(() {
                _selectedCustomer = v;
                _selectedSoftwareDevice = null;
                _selectedStaff = null;
              });
            },
            validator: (v) => v == null ? 'Please select a customer' : null,
            filterFn: (customer, filter) {
              final q = filter.toLowerCase();
              return customer.name.toLowerCase().contains(q) ||
                  customer.phone.toLowerCase().contains(q) ||
                  customer.taxNumber.toLowerCase().contains(q) ||
                  (customer.organizationName?.toLowerCase().contains(q) ?? false);
            },
            dropdownBuilder: (context, selectedItem) {
              if (selectedItem == null) {
                return Text(
                  'Search customer name, phone, or VAT...',
                  style: TextStyle(fontSize: 13, color: isDark ? FuturisticColors.textMuted : Colors.grey.shade400),
                );
              }
              return Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D9488),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      selectedItem.name.isNotEmpty ? selectedItem.name[0].toUpperCase() : 'C',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedItem.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selectedItem.phone.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? FuturisticColors.bgElevated : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        selectedItem.phone,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? FuturisticColors.textSecondary : const Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              );
            },
            decoratorProps: DropDownDecoratorProps(
              decoration: _inputDecoration(
                'Select Customer *',
                hintText: 'Search customer name, phone, or VAT...',
                prefixIcon: const Icon(LucideIcons.userCheck, size: 18, color: Color(0xFF0D9488)),
              ),
            ),
            popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: 'Search customer by name, phone, or VAT...',
                  hintStyle: TextStyle(fontSize: 12.5, color: isDark ? FuturisticColors.textMuted : Colors.grey.shade400),
                  prefixIcon: Icon(LucideIcons.search, size: 18, color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488)),
                  filled: true,
                  fillColor: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488), width: 1.5),
                  ),
                ),
              ),
              itemBuilder: (context, item, isDisabled, isSelected) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? FuturisticColors.neonCyan.withValues(alpha: 0.1) : const Color(0xFFF0FDFA))
                        : Colors.transparent,
                    border: Border(bottom: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFF1F5F9))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0D9488)
                              : (isDark ? FuturisticColors.bgElevated : const Color(0xFFE2E8F0)),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? FuturisticColors.textSecondary : const Color(0xFF475569)),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected
                                    ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488))
                                    : (isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
                                fontSize: 13.5,
                              ),
                            ),
                            if (item.phone.isNotEmpty || item.taxNumber.isNotEmpty || (item.organizationName?.isNotEmpty ?? false)) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  if (item.phone.isNotEmpty) ...[
                                    Icon(LucideIcons.phone, size: 11, color: isDark ? FuturisticColors.textMuted : Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.phone,
                                      style: TextStyle(fontSize: 11.5, color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade600),
                                    ),
                                  ],
                                  if (item.phone.isNotEmpty && item.taxNumber.isNotEmpty)
                                    Text(' • ', style: TextStyle(fontSize: 11, color: isDark ? FuturisticColors.textMuted : Colors.grey.shade400)),
                                  if (item.taxNumber.isNotEmpty) ...[
                                    Icon(LucideIcons.receipt, size: 11, color: isDark ? FuturisticColors.textMuted : Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      'VAT: ${item.taxNumber}',
                                      style: TextStyle(fontSize: 11.5, color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade600),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              menuProps: MenuProps(
                backgroundColor: isDark ? FuturisticColors.bgCard : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  side: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                ),
                elevation: 6,
              ),
              emptyBuilder: (context, searchEntry) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? FuturisticColors.bgElevated : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(LucideIcons.userX, size: 24, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        searchEntry.trim().isNotEmpty
                            ? 'No customer found for "$searchEntry"'
                            : 'No customers available',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? FuturisticColors.textPrimary : const Color(0xFF334155)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create a new customer profile to proceed',
                        style: TextStyle(fontSize: 11.5, color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final customerProvider = context.read<CustomerProvider>();
                          final initialCount = customerProvider.customers.length;
                          Navigator.pop(context);
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const CreateCustomerScreen(),
                            ),
                          );
                          if (!mounted) return;
                          await customerProvider.fetchCustomers();
                          if (customerProvider.customers.length > initialCount) {
                            setState(() {
                              _selectedCustomer = customerProvider.customers.first;
                              _selectedSoftwareDevice = null;
                              _selectedStaff = null;
                            });
                          } else {
                            setState(() {});
                          }
                        },
                        icon: const Icon(LucideIcons.userPlus, size: 16),
                        label: const Text('Add New Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Selected Customer Profile Badge
          if (_selectedCustomer != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0D9488).withValues(alpha: 0.15)
                    : const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF0D9488).withValues(alpha: 0.4)
                      : const Color(0xFF99F6E4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _selectedCustomer!.name.isNotEmpty ? _selectedCustomer!.name[0].toUpperCase() : 'C',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
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
                                _selectedCustomer!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (_selectedCustomer!.phone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(LucideIcons.phone, size: 12, color: isDark ? FuturisticColors.textMuted : Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedCustomer!.phone,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_selectedCustomer!.taxNumber.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isDark ? FuturisticColors.bgElevated : Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isDark ? FuturisticColors.borderSubtle : const Color(0xFF99F6E4),
                                  ),
                                ),
                                child: Text(
                                  'VAT: ${_selectedCustomer!.taxNumber}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? FuturisticColors.neonTeal : const Color(0xFF0D9488),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final customerProvider = context.read<CustomerProvider>();
                      await Responsive.showAdaptiveDialog(
                        context: context,
                        maxWidth: 1000,
                        maxHeight: 850,
                        child: CreateCustomerScreen(
                          customer: _selectedCustomer,
                        ),
                      );
                      if (!mounted) return;
                      customerProvider.fetchCustomers();
                      setState(() {});
                    },
                    icon: const Icon(LucideIcons.edit3, size: 14),
                    label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? FuturisticColors.neonTeal : const Color(0xFF0D9488),
                      backgroundColor: isDark ? FuturisticColors.bgElevated : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isDark ? FuturisticColors.borderSubtle : const Color(0xFF99F6E4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Software device & staff dropdowns
            _buildSoftwareDeviceDropdown(_getSoftwareDeviceOptions(_selectedCustomer)),
            const SizedBox(height: 10),
            _buildStaffDropdown(_getStaffOptions(_selectedCustomer)),
          ],
              ],
            );
          }),

          const SizedBox(height: 10),

          // Description input
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: _inputDecoration(
              'Description & Remarks (Optional)',
              hintText: 'Add internal notes, customer requirements, or remarks...',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Icon(LucideIcons.alignLeft, size: 18, color: Color(0xFF64748B)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card 2: Purchase Lines ────────────────────────────────────────────────

  Widget _buildPurchaseLinesCard() {
    final isDark = AppTheme.isDark(context);
    return _buildSectionCard(
      title: 'Purchase & Replacement Lines',
      subtitle: 'Add itemized materials, license keys, or spare parts used',
      icon: LucideIcons.shoppingBag,
      accentColor: const Color(0xFF6366F1),
      headerTrailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _purchaseLines.isNotEmpty
              ? (isDark ? const Color(0xFF6366F1).withValues(alpha: 0.2) : const Color(0xFFEEF2FF))
              : (isDark ? FuturisticColors.bgElevated : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${_purchaseLines.length} Item${_purchaseLines.length == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _purchaseLines.isNotEmpty
                ? const Color(0xFF4F46E5)
                : (isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B)),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick add input row
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _purchaseNameController,
                    decoration: _inputDecoration(
                      'Purchase Item Name',
                      hintText: 'e.g., Thermal Printer, RAM...',
                      prefixIcon: const Icon(LucideIcons.package, size: 16, color: Color(0xFF6366F1)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _purchaseCostController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration(
                      'Cost (SAR)',
                      hintText: '0.00',
                      prefixIcon: const Icon(LucideIcons.coins, size: 16, color: Color(0xFF6366F1)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _addPurchaseLine,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Add Line'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          if (_purchaseLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _purchaseLines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final line = _purchaseLines[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? FuturisticColors.bgCard : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF6366F1).withValues(alpha: 0.2) : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? FuturisticColors.neonCyan : const Color(0xFF4F46E5)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          line.purchaseName,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: isDark ? FuturisticColors.textPrimary : const Color(0xFF1E293B)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? FuturisticColors.bgElevated : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'SAR ${line.cost.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _removePurchaseLine(index),
                        icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent),
                        tooltip: 'Remove Line',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            // Subtotal Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Purchase Lines Subtotal',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B)),
                  ),
                  Text(
                    'SAR ${_totalPurchasesCost.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: isDark ? FuturisticColors.neonCyan : const Color(0xFF4F46E5)),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0), style: BorderStyle.solid),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(LucideIcons.packageOpen, size: 28, color: isDark ? FuturisticColors.textMuted : Colors.grey.shade400),
                    const SizedBox(height: 6),
                    Text(
                      'No purchase line items added',
                      style: TextStyle(fontSize: 13, color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Add parts or license keys above if included with this service',
                      style: TextStyle(fontSize: 11.5, color: isDark ? FuturisticColors.textMuted : Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Card 3: Financial Details ─────────────────────────────────────────────

  Widget _buildFinancialCard() {
    final isDark = AppTheme.isDark(context);
    final isFree = _paymentStatus.toLowerCase() == 'free';
    final isFullyPaid = _balanceAmount <= 0;

    return _buildSectionCard(
      title: 'Financial Breakdown',
      subtitle: 'Service cost, labor charges, and payment balance',
      icon: LucideIcons.dollarSign,
      accentColor: const Color(0xFF059669),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero KPI Total Cost Display
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF047857), Color(0xFF0D9488)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isFree ? 'FREE' : 'SAR',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isFree ? 'Free of Charge' : 'SAR ${_totalServiceCost.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Fee: ${_serviceFeeController.text} + Parts: ${_totalPurchasesCost.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Service Fee input
          TextFormField(
            controller: _serviceFeeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration(
              'Base Service Fee (Labor / Service Charge)',
              hintText: '0.00',
              prefixIcon: const Icon(LucideIcons.banknote, size: 18, color: Color(0xFF059669)),
            ),
            onChanged: (_) => setState(() {
              _amountController.text = _totalServiceCost.toStringAsFixed(2);
            }),
          ),

          const SizedBox(height: 10),

          // Paid Amount input & presets
          TextFormField(
            controller: _paidAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration(
              'Customer Paid Amount',
              hintText: '0.00',
              prefixIcon: const Icon(LucideIcons.creditCard, size: 18, color: Color(0xFF059669)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, size: 16),
                tooltip: 'Clear paid amount',
                onPressed: () => setState(() => _paidAmountController.text = '0'),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 8),

          // Quick fill amount chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickPayChip(
                  label: 'Full (SAR ${_totalServiceCost.toStringAsFixed(2)})',
                  onTap: () {
                    setState(() {
                      _paidAmountController.text = _totalServiceCost.toStringAsFixed(2);
                      _paymentStatus = 'Paid';
                    });
                  },
                ),
                const SizedBox(width: 6),
                _quickPayChip(
                  label: 'Half (SAR ${(_totalServiceCost / 2).toStringAsFixed(2)})',
                  onTap: () {
                    setState(() {
                      _paidAmountController.text = (_totalServiceCost / 2).toStringAsFixed(2);
                      _paymentStatus = 'Partial';
                    });
                  },
                ),
                const SizedBox(width: 6),
                _quickPayChip(
                  label: 'Zero (0.00)',
                  onTap: () {
                    setState(() {
                      _paidAmountController.text = '0';
                      _paymentStatus = 'Pending';
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Balance status tile
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isFree
                  ? (isDark ? const Color(0xFF0284C7).withValues(alpha: 0.12) : const Color(0xFFF0F9FF))
                  : isFullyPaid
                      ? (isDark ? const Color(0xFF059669).withValues(alpha: 0.12) : const Color(0xFFECFDF5))
                      : (isDark ? const Color(0xFFDC2626).withValues(alpha: 0.12) : const Color(0xFFFEF2F2)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFree
                    ? (isDark ? const Color(0xFF0284C7).withValues(alpha: 0.4) : const Color(0xFFBAE6FD))
                    : isFullyPaid
                        ? (isDark ? const Color(0xFF059669).withValues(alpha: 0.4) : const Color(0xFFA7F3D0))
                        : (isDark ? const Color(0xFFDC2626).withValues(alpha: 0.4) : const Color(0xFFFECACA)),
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
                      size: 18,
                      color: isFree
                          ? const Color(0xFF0284C7)
                          : isFullyPaid
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isFree
                          ? 'Free of Charge'
                          : isFullyPaid
                              ? 'Fully Settled'
                              : 'Outstanding Balance Due',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isFree
                            ? const Color(0xFF0284C7)
                            : isFullyPaid
                                ? (isDark ? FuturisticColors.neonTeal : const Color(0xFF065F46))
                                : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                Text(
                  isFree ? 'SAR 0.00' : 'SAR ${_balanceAmount.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isFree
                        ? const Color(0xFF0284C7)
                        : isFullyPaid
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickPayChip({required String label, required VoidCallback onTap}) {
    final isDark = AppTheme.isDark(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? FuturisticColors.bgElevated : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF475569)),
        ),
      ),
    );
  }

  // ── Card 4: Status, Method & Schedule ──────────────────────────────────────

  Widget _buildStatusAndScheduleCard() {
    return _buildSectionCard(
      title: 'Status & Schedule',
      subtitle: 'Manage payment method, execution status, and deadlines',
      icon: LucideIcons.calendar,
      accentColor: const Color(0xFF3B82F6),
      child: Column(
        children: [
          // Payment Method Dropdown with Rich Item Rows & Icon Pill
          Builder(builder: (context) {
            final isDark = AppTheme.isDark(context);
            return DropdownButtonFormField<String>(
              initialValue: _paymentType,
              dropdownColor: isDark ? FuturisticColors.bgCard : Colors.white,
              borderRadius: BorderRadius.circular(10),
              elevation: 4,
              isExpanded: true,
              icon: Icon(LucideIcons.chevronDown, size: 16, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B)),
              decoration: _inputDecoration(
                'Payment Method',
                prefixIcon: const Icon(LucideIcons.wallet, size: 18, color: Color(0xFF3B82F6)),
              ),
              selectedItemBuilder: (context) {
                return _paymentMethods.map((opt) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: opt.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        opt.label,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
                      ),
                    ],
                  );
                }).toList();
              },
              items: _paymentMethods.map((opt) {
                final isSelected = opt.value == _paymentType;
                return DropdownMenuItem<String>(
                  value: opt.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: opt.color.withValues(alpha: isDark ? 0.2 : 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(opt.icon, size: 14, color: opt.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                opt.label,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 13,
                                  color: isSelected ? opt.color : (isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
                                ),
                              ),
                              Text(
                                opt.description,
                                style: TextStyle(fontSize: 11, color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _paymentType = v ?? 'Cash'),
            );
          }),

          const SizedBox(height: 10),

          // Payment Status & Service Status Row
          Builder(builder: (context) {
            final isDark = AppTheme.isDark(context);
            return Row(
            children: [
              // Payment Status Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _paymentStatus,
                  dropdownColor: isDark ? FuturisticColors.bgCard : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  elevation: 4,
                  isExpanded: true,
                  icon: Icon(LucideIcons.chevronDown, size: 16, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B)),
                  decoration: _inputDecoration('Payment Status'),
                  selectedItemBuilder: (context) {
                    return _paymentStatusOptions.map((opt) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: opt.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            opt.label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: opt.color,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                  items: _paymentStatusOptions.map((opt) {
                    final isSelected = opt.value == _paymentStatus;
                    return DropdownMenuItem<String>(
                      value: opt.value,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: opt.color.withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(opt.icon, size: 14, color: opt.color),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  opt.label,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 12.5,
                                    color: isSelected ? opt.color : (isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
                                  ),
                                ),
                                Text(
                                  opt.description,
                                  style: TextStyle(fontSize: 10.5, color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _paymentStatus = v ?? 'Pending'),
                ),
              ),
              const SizedBox(width: 10),
              // Service Status Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _serviceStatus,
                  dropdownColor: isDark ? FuturisticColors.bgCard : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  elevation: 4,
                  isExpanded: true,
                  icon: Icon(LucideIcons.chevronDown, size: 16, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B)),
                  decoration: _inputDecoration('Service Status'),
                  selectedItemBuilder: (context) {
                    return _serviceStatusOptions.map((opt) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: opt.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            opt.label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: opt.color,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                  items: _serviceStatusOptions.map((opt) {
                    final isSelected = opt.value == _serviceStatus;
                    return DropdownMenuItem<String>(
                      value: opt.value,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: opt.color.withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(opt.icon, size: 14, color: opt.color),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  opt.label,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 12.5,
                                    color: isSelected ? opt.color : (isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
                                  ),
                                ),
                                Text(
                                  opt.description,
                                  style: TextStyle(fontSize: 10.5, color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _serviceStatus = v ?? 'Pending'),
                ),
              ),
            ],
          );
          }),

          const SizedBox(height: 10),

          // Service Date and Expiry Date Row
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Service Date',
                  value: DateFormat('dd MMM yyyy').format(_serviceDate),
                  onTap: () => _pickDate(payment: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: 'Payment Expiry Date',
                  value: _paymentExpiryDate == null
                      ? 'Not Set'
                      : DateFormat('dd MMM yyyy').format(_paymentExpiryDate!),
                  onTap: () => _pickDate(payment: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Customer Software & Staff Dropdowns ────────────────────────────────────

  Widget _buildSoftwareDeviceDropdown(List<_CustomerSoftwareDevice> softwareOptions) {
    final isDark = AppTheme.isDark(context);
    if (softwareOptions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFFFFB703).withValues(alpha: 0.1) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFFFFB703).withValues(alpha: 0.3) : const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.info, size: 16, color: Colors.amber.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No software devices / terminals configured for this customer',
                style: TextStyle(fontSize: 12.5, color: isDark ? FuturisticColors.neonAmber : Colors.amber.shade900, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownSearch<_CustomerSoftwareDevice>(
      items: (filter, infiniteScrollProps) => softwareOptions,
      compareFn: (item1, item2) => item1 == item2,
      itemAsString: (item) => item.displayName,
      selectedItem: _selectedSoftwareDevice,
      onChanged: (v) => setState(() => _selectedSoftwareDevice = v),
      filterFn: (item, filter) {
        final q = filter.toLowerCase();
        return item.softwareName.toLowerCase().contains(q) ||
            (item.deviceLabel?.toLowerCase().contains(q) ?? false) ||
            (item.branchName?.toLowerCase().contains(q) ?? false);
      },
      dropdownBuilder: (context, selectedItem) {
        final isDark = AppTheme.isDark(context);
        if (selectedItem == null) {
          return Text(
            '',
            style: TextStyle(fontSize: 13, color: isDark ? FuturisticColors.textMuted : Colors.grey.shade400),
          );
        }
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? FuturisticColors.neonCyan.withValues(alpha: 0.15) : const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(LucideIcons.laptop, size: 14, color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedItem.displayName,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
      decoratorProps: DropDownDecoratorProps(
        decoration: _inputDecoration(
          'Select Software / Terminal Device',
          hintText: 'Choose terminal or activation key...',
          prefixIcon: const Icon(LucideIcons.laptop, color: Color(0xFF0D9488), size: 18),
        ),
      ),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: 'Search software or device terminal...',
            prefixIcon: Icon(LucideIcons.search, size: 16, color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488)),
            filled: true,
            fillColor: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488), width: 1.5),
            ),
          ),
        ),
        itemBuilder: (context, item, isDisabled, isSelected) {
          final isDark = AppTheme.isDark(context);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? (isDark ? FuturisticColors.neonCyan.withValues(alpha: 0.1) : const Color(0xFFF0FDFA)) : Colors.transparent,
              border: Border(bottom: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isDark ? FuturisticColors.neonCyan.withValues(alpha: 0.15) : const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.laptop, color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488), size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.softwareName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488)) : (isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
                          fontSize: 13.5,
                        ),
                      ),
                      if (item.deviceLabel != null || item.branchName != null) ...[
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (item.deviceLabel != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? FuturisticColors.bgElevated : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  item.deviceLabel!,
                                  style: TextStyle(fontSize: 11, color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade700, fontWeight: FontWeight.w500),
                                ),
                              ),
                            if (item.branchName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1D4ED8).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: isDark ? const Color(0xFF1D4ED8).withValues(alpha: 0.4) : const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  item.branchName!,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w500),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        menuProps: MenuProps(
          backgroundColor: isDark ? FuturisticColors.bgCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            side: BorderSide(
              color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0),
            ),
          ),
          elevation: 6,
        ),
      ),
    );
  }

  Widget _buildStaffDropdown(List<_CustomerStaff> staffOptions) {
    final isDark = AppTheme.isDark(context);
    if (staffOptions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF7C3AED).withValues(alpha: 0.1) : const Color(0xFFFAF5FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF7C3AED).withValues(alpha: 0.3) : const Color(0xFFE9D5FF)),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.info, size: 16, color: Colors.purple.shade400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No staff members registered for this customer',
                style: TextStyle(fontSize: 12.5, color: isDark ? FuturisticColors.neonViolet : Colors.purple.shade900, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownSearch<_CustomerStaff>(
      items: (filter, infiniteScrollProps) => staffOptions,
      compareFn: (item1, item2) => item1 == item2,
      itemAsString: (item) => item.displayName,
      selectedItem: _selectedStaff,
      onChanged: (v) => setState(() => _selectedStaff = v),
      filterFn: (item, filter) {
        final q = filter.toLowerCase();
        return item.name.toLowerCase().contains(q) ||
            item.phone.toLowerCase().contains(q) ||
            (item.branchName?.toLowerCase().contains(q) ?? false);
      },
      dropdownBuilder: (context, selectedItem) {
        final isDark = AppTheme.isDark(context);
        if (selectedItem == null) {
          return Text(
            '',
            style: TextStyle(fontSize: 13, color: isDark ? FuturisticColors.textMuted : Colors.grey.shade400),
          );
        }
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF7C3AED).withValues(alpha: 0.2) : const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(LucideIcons.user, size: 14, color: Color(0xFF7E22CE)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedItem.displayName,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
      decoratorProps: DropDownDecoratorProps(
        decoration: _inputDecoration(
          'Select Staff Member',
          hintText: 'Choose customer staff contact...',
          prefixIcon: const Icon(LucideIcons.user, color: Color(0xFF0D9488), size: 18),
        ),
      ),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: 'Search staff by name or phone...',
            prefixIcon: Icon(LucideIcons.search, size: 16, color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488)),
            filled: true,
            fillColor: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488), width: 1.5),
            ),
          ),
        ),
        itemBuilder: (context, item, isDisabled, isSelected) {
          final isDark = AppTheme.isDark(context);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? (isDark ? const Color(0xFF7C3AED).withValues(alpha: 0.15) : const Color(0xFFFAF5FF)) : Colors.transparent,
              border: Border(bottom: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF7C3AED).withValues(alpha: 0.2) : const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.user, color: Color(0xFF7E22CE), size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? const Color(0xFF7E22CE) : (isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
                          fontSize: 13.5,
                        ),
                      ),
                      if (item.phone.isNotEmpty || item.branchName != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (item.phone.isNotEmpty) ...[
                              Icon(LucideIcons.phone, size: 11, color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                item.phone,
                                style: TextStyle(fontSize: 11.5, color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade600),
                              ),
                            ],
                            if (item.phone.isNotEmpty && item.branchName != null)
                              const SizedBox(width: 8),
                            if (item.branchName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1D4ED8).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: isDark ? const Color(0xFF1D4ED8).withValues(alpha: 0.4) : const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  item.branchName!,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w500),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        menuProps: MenuProps(
          backgroundColor: isDark ? FuturisticColors.bgCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            side: BorderSide(
              color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0),
            ),
          ),
          elevation: 6,
        ),
      ),
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
    final isDark = AppTheme.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgCard : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
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
                    color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: accentColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade500,
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
          Divider(height: 1, color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(10),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Dropdown Item Models ───────────────────────────────────────────────────

class _DropdownOption {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const _DropdownOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}

// ── Customer Software & Staff Helper Models ────────────────────────────────

class _CustomerSoftwareDevice {
  final String softwareName;
  final String? deviceLabel;
  final String? branchName;
  final String? activationKey;
  final String? userId;

  const _CustomerSoftwareDevice({
    required this.softwareName,
    this.deviceLabel,
    this.branchName,
    this.activationKey,
    this.userId,
  });

  String get displayName {
    final parts = <String>[softwareName];
    if (deviceLabel != null && deviceLabel!.trim().isNotEmpty) {
      parts.add(deviceLabel!.trim());
    }
    if (branchName != null && branchName!.trim().isNotEmpty) {
      parts.add('(${branchName!.trim()})');
    }
    return parts.join(' - ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CustomerSoftwareDevice &&
          runtimeType == other.runtimeType &&
          softwareName == other.softwareName &&
          deviceLabel == other.deviceLabel &&
          branchName == other.branchName &&
          activationKey == other.activationKey;

  @override
  int get hashCode =>
      softwareName.hashCode ^
      (deviceLabel?.hashCode ?? 0) ^
      (branchName?.hashCode ?? 0) ^
      (activationKey?.hashCode ?? 0);
}

class _CustomerStaff {
  final String name;
  final String phone;
  final String? branchName;

  const _CustomerStaff({
    required this.name,
    required this.phone,
    this.branchName,
  });

  String get displayName {
    final buffer = StringBuffer(name);
    if (phone.trim().isNotEmpty) {
      buffer.write(' (${phone.trim()})');
    }
    if (branchName != null && branchName!.trim().isNotEmpty) {
      buffer.write(' • ${branchName!.trim()}');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CustomerStaff &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          phone == other.phone &&
          branchName == other.branchName;

  @override
  int get hashCode =>
      name.hashCode ^ phone.hashCode ^ (branchName?.hashCode ?? 0);
}

class _ServiceSuggestion {
  final String title;
  final double amount;
  final double averageAmount;
  final int count;

  const _ServiceSuggestion({
    required this.title,
    required this.amount,
    required this.averageAmount,
    required this.count,
  });
}

Widget _suggestionBadge({required String label, required MaterialColor color, bool isDark = false}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: isDark ? color.withValues(alpha: 0.15) : color.shade50,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: isDark ? color.withValues(alpha: 0.3) : color.shade200),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: isDark ? color.shade200 : color.shade700,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final fillColor = isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC);
    final borderColor = isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: fillColor,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: borderColor),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
            ),
            Icon(LucideIcons.calendar, size: 16, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}