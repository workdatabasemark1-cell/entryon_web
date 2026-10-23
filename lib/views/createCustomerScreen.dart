import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/customer_provider.dart';
import '../providers/auth_Provider.dart';
import '../models/customer_model.dart';
import '../utils/app_theme.dart';
import '../utils/customer_text_parser.dart';

// ── Lightweight period model ──────────────────────────────────────────────────
class _Period {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  _Period({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  String get range =>
      '${DateFormat('MMM yyyy').format(startDate)} – '
      '${DateFormat('MMM yyyy').format(endDate)}';
}

// ── Device activation for one software ────────────────────────────────────────
class _DeviceActivation {
  final TextEditingController deviceLabelController;
  final TextEditingController userController;
  final TextEditingController keyController;
  DateTime? activationDate;
  DateTime? expiryDate;

  _DeviceActivation({
    String deviceLabel = '',
    String userId = '',
    String key = '',
    this.activationDate,
    this.expiryDate,
  })  : deviceLabelController = TextEditingController(text: deviceLabel),
        userController = TextEditingController(text: userId),
        keyController = TextEditingController(text: key);

  void dispose() {
    deviceLabelController.dispose();
    userController.dispose();
    keyController.dispose();
  }
}

// ── Local branch staff member for UI state management ─────────────────────────
class _BranchStaff {
  final TextEditingController nameController;
  final TextEditingController phoneController;

  _BranchStaff({String name = '', String phone = ''})
      : nameController = TextEditingController(text: name),
        phoneController = TextEditingController(text: phone);

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
  }
}

// ── Local branch for UI state management ──────────────────────────────────────
class _BranchData {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController phone2Controller;
  final TextEditingController emailController;
  final TextEditingController careOfController;
  final TextEditingController organizationNameController;
  final TextEditingController organizationUnitNameController;
  final TextEditingController commonNameController;
  final TextEditingController businessCategoryController;
  final TextEditingController addressController;
  final TextEditingController registeredAddressController;
  final TextEditingController buildingNoController;
  final TextEditingController streetNameController;
  final TextEditingController districtNameController;
  final TextEditingController cityNameController;
  final TextEditingController zipCodeController;
  final TextEditingController additionalNoController;
  final TextEditingController unitNoController;
  final TextEditingController countryController;
  final TextEditingController taxNumberController;
  final TextEditingController crNumberController;
  final List<_BranchStaff> staffList;

  // ZATCA fields
  bool zatcaEnabled;
  final TextEditingController zatcaUsernameController;
  final TextEditingController zatcaPasswordController;
  bool obscureZatcaPassword;
  DateTime? financialPeriodStartDate;
  DateTime? financialPeriodEndDate;
  _Period? selectedPeriod;

  _BranchData({
    String name = '',
    String phone = '',
    String phone2 = '',
    String email = '',
    String careOf = '',
    String organizationName = '',
    String organizationUnitName = '',
    String commonName = '',
    String businessCategory = '',
    String address = '',
    String registeredAddress = '',
    String buildingNo = '',
    String streetName = '',
    String districtName = '',
    String cityName = '',
    String zipCode = '',
    String additionalNo = '',
    String unitNo = '',
    String country = '',
    String taxNumber = '',
    String crNumber = '',
    List<_BranchStaff>? staffList,
    this.zatcaEnabled = false,
    String zatcaUsername = '',
    String zatcaPassword = '',
    this.financialPeriodStartDate,
    this.financialPeriodEndDate,
  })  : nameController = TextEditingController(text: name),
        phoneController = TextEditingController(text: phone),
      phone2Controller = TextEditingController(text: phone2),
      emailController = TextEditingController(text: email),
      careOfController = TextEditingController(text: careOf),
      organizationNameController = TextEditingController(text: organizationName),
      organizationUnitNameController = TextEditingController(text: organizationUnitName),
      commonNameController = TextEditingController(text: commonName),
      businessCategoryController = TextEditingController(text: businessCategory),
        addressController = TextEditingController(text: address),
      registeredAddressController = TextEditingController(text: registeredAddress),
      buildingNoController = TextEditingController(text: buildingNo),
      streetNameController = TextEditingController(text: streetName),
      districtNameController = TextEditingController(text: districtName),
      cityNameController = TextEditingController(text: cityName),
      zipCodeController = TextEditingController(text: zipCode),
      additionalNoController = TextEditingController(text: additionalNo),
      unitNoController = TextEditingController(text: unitNo),
      countryController = TextEditingController(text: country),
      taxNumberController = TextEditingController(text: taxNumber),
      crNumberController = TextEditingController(text: crNumber),
        zatcaUsernameController = TextEditingController(text: zatcaUsername),
        zatcaPasswordController = TextEditingController(text: zatcaPassword),
        obscureZatcaPassword = true,
        staffList = staffList ?? [];

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    phone2Controller.dispose();
    emailController.dispose();
    careOfController.dispose();
    organizationNameController.dispose();
    organizationUnitNameController.dispose();
    commonNameController.dispose();
    businessCategoryController.dispose();
    addressController.dispose();
    registeredAddressController.dispose();
    buildingNoController.dispose();
    streetNameController.dispose();
    districtNameController.dispose();
    cityNameController.dispose();
    zipCodeController.dispose();
    additionalNoController.dispose();
    unitNoController.dispose();
    countryController.dispose();
    taxNumberController.dispose();
    crNumberController.dispose();
    zatcaUsernameController.dispose();
    zatcaPasswordController.dispose();
    for (final staff in staffList) {
      staff.dispose();
    }
  }

  Branch toModel({
    List<String> usedSoftwares = const [],
    List<Map<String, dynamic>> softwareActivations = const [],
  }) {
    return Branch(
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      phone2: phone2Controller.text.trim().isEmpty ? null : phone2Controller.text.trim(),
      email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
      careOf: careOfController.text.trim().isEmpty ? null : careOfController.text.trim(),
      organizationName: organizationNameController.text.trim().isEmpty ? null : organizationNameController.text.trim(),
      organizationUnitName: organizationUnitNameController.text.trim().isEmpty ? null : organizationUnitNameController.text.trim(),
      commonName: commonNameController.text.trim().isEmpty ? null : commonNameController.text.trim(),
      businessCategory: businessCategoryController.text.trim().isEmpty ? null : businessCategoryController.text.trim(),
      address: addressController.text.trim(),
      registeredAddress: registeredAddressController.text.trim().isEmpty ? null : registeredAddressController.text.trim(),
      buildingNo: buildingNoController.text.trim().isEmpty ? null : buildingNoController.text.trim(),
      streetName: streetNameController.text.trim().isEmpty ? null : streetNameController.text.trim(),
      districtName: districtNameController.text.trim().isEmpty ? null : districtNameController.text.trim(),
      cityName: cityNameController.text.trim().isEmpty ? null : cityNameController.text.trim(),
      zipCode: zipCodeController.text.trim().isEmpty ? null : zipCodeController.text.trim(),
      additionalNo: additionalNoController.text.trim().isEmpty ? null : additionalNoController.text.trim(),
      unitNo: unitNoController.text.trim().isEmpty ? null : unitNoController.text.trim(),
      country: countryController.text.trim().isEmpty ? null : countryController.text.trim(),
      taxNumber: taxNumberController.text.trim().isEmpty ? null : taxNumberController.text.trim(),
      crNumber: crNumberController.text.trim().isEmpty ? null : crNumberController.text.trim(),
      staff: staffList
          .map((s) => Staff(
                name: s.nameController.text.trim(),
                phone: s.phoneController.text.trim(),
              ))
          .toList(),
      usedSoftwares: usedSoftwares,
      softwareActivations: softwareActivations,
      zatcaEnabled: zatcaEnabled,
      zatcaUsername: zatcaUsernameController.text.trim().isEmpty
          ? null
          : zatcaUsernameController.text.trim(),
      zatcaPassword: zatcaPasswordController.text.trim().isEmpty
          ? null
          : zatcaPasswordController.text.trim(),
      financialPeriodStartDate: financialPeriodStartDate?.toIso8601String(),
      financialPeriodEndDate: financialPeriodEndDate?.toIso8601String(),
      periodSectionId: selectedPeriod?.id,
      periodSectionName: selectedPeriod?.name,
    );
  }
}

class CreateCustomerScreen extends StatefulWidget {
  final Customer? customer;
  final VoidCallback? onClose;
  final String? initialImportText;

  const CreateCustomerScreen({
    super.key,
    this.customer,
    this.onClose,
    this.initialImportText,
  });

  @override
  State<CreateCustomerScreen> createState() => _CreateCustomerScreenState();
}

class _CreateCustomerScreenState extends State<CreateCustomerScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Active Tab Index
  int _activeTabIndex = 0;

  // Basic Information
  late TextEditingController _nameController;
  late TextEditingController _careOfController;
  late TextEditingController _phoneController;
  late TextEditingController _phone2Controller;
  late TextEditingController _emailController;

  // Organization Details
  late TextEditingController _organizationNameController;
  late TextEditingController _organizationUnitNameController;
  late TextEditingController _commonNameController;
  late TextEditingController _businessCategoryController;

  // Address Information
  late TextEditingController _addressController;
  late TextEditingController _registeredAddressController;
  late TextEditingController _buildingNoController;
  late TextEditingController _streetNameController;
  late TextEditingController _districtNameController;
  late TextEditingController _cityNameController;
  late TextEditingController _zipCodeController;
  late TextEditingController _additionalNoController;
  late TextEditingController _unitNoController;
  late TextEditingController _countryController;

  // Tax and Registration
  late TextEditingController _taxNumberController;
  late TextEditingController _crNumberController;

  // Zatca Credentials
  late TextEditingController _zatcaUsernameController;
  late TextEditingController _zatcaPasswordController;
  bool _obscureZatcaPassword = true;

  bool _zatcaEnabled = false;
  bool _cloudStorageEnabled = false;
  DateTime? _cloudFinancialPeriodStartDate;
  DateTime? _cloudFinancialPeriodEndDate;
  DateTime? _financialPeriodStartDate;
  DateTime? _financialPeriodEndDate;

  final List<String> _availableSoftwares = [
    'Digisuite',
    'Digisuite App',
    'Saleculator Windows',
    'Saleculator Linux',
    'Saleculator Android',
    'BillBox',
    'CaproErp Windows',
    'CaproErp',
    'NextErp',
    'NextDine',
    'Unipos',
    'EonsBooks'
   

  ];

  /// Which softwares are selected
  final List<String> _selectedSoftwareNames = [];

  /// software name → list of devices
  final Map<String, List<_DeviceActivation>> _softwareDevices = {};

  List<String> _expiredSoftwares = [];
  bool _expiryAlertShown = false;

  // Main customer staff management
  final List<_BranchStaff> _mainCustomerStaff = [];

  // Branch and staff management
  final List<_BranchData> _branches = [];

  // Branch software tracking
  final Map<int, Map<String, List<_DeviceActivation>>> _branchSoftwareDevices = {};
  final Map<int, List<String>> _branchSelectedSoftwares = {};

  // Period sections from Firestore
  List<_Period> _periods = [];
  bool _periodsLoading = true;
  _Period? _selectedPeriod;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();

    // Initialize all controllers
    _nameController = TextEditingController();
    _careOfController = TextEditingController();
    _phoneController = TextEditingController();
    _phone2Controller = TextEditingController();
    _emailController = TextEditingController();
    _organizationNameController = TextEditingController();
    _organizationUnitNameController = TextEditingController();
    _commonNameController = TextEditingController();
    _businessCategoryController = TextEditingController();
    _addressController = TextEditingController();
    _registeredAddressController = TextEditingController();
    _buildingNoController = TextEditingController();
    _streetNameController = TextEditingController();
    _districtNameController = TextEditingController();
    _cityNameController = TextEditingController();
    _zipCodeController = TextEditingController();
    _additionalNoController = TextEditingController();
    _unitNoController = TextEditingController();
    _countryController = TextEditingController();
    _taxNumberController = TextEditingController();
    _crNumberController = TextEditingController();
    _zatcaUsernameController = TextEditingController();
    _zatcaPasswordController = TextEditingController();

    _fetchPeriods();

    // Pre-fill form if editing
    if (_isEditing) {
      final customer = widget.customer!;
      _nameController.text = customer.name;
      _careOfController.text = customer.careOf ?? '';
      _phoneController.text = customer.phone;
      _phone2Controller.text = customer.phone2 ?? '';
      _emailController.text = customer.email ?? '';
      _organizationNameController.text = customer.organizationName ?? '';
      _organizationUnitNameController.text = customer.organizationUnitName ?? '';
      _commonNameController.text = customer.commonName ?? '';
      _businessCategoryController.text = customer.businessCategory ?? '';
      _addressController.text = customer.address;
      _registeredAddressController.text = customer.registeredAddress ?? '';
      _buildingNoController.text = customer.buildingNo ?? '';
      _streetNameController.text = customer.streetName ?? '';
      _districtNameController.text = customer.districtName ?? '';
      _cityNameController.text = customer.cityName ?? '';
      _zipCodeController.text = customer.zipCode ?? '';
      _additionalNoController.text = customer.additionalNo ?? '';
      _unitNoController.text = customer.unitNo ?? '';
      _countryController.text = customer.country ?? '';
      _taxNumberController.text = customer.taxNumber;
      _crNumberController.text = customer.crNumber ?? '';
      _zatcaUsernameController.text = customer.zatcaUsername ?? '';
      _zatcaPasswordController.text = customer.zatcaPassword ?? '';
      _zatcaEnabled = customer.zatcaEnabled ?? false;
      _cloudStorageEnabled = customer.cloudStorageEnabled;
        _cloudFinancialPeriodStartDate = customer.cloudFinancialPeriodStartDate != null
          ? DateTime.tryParse(customer.cloudFinancialPeriodStartDate!)
          : null;
        _cloudFinancialPeriodEndDate = customer.cloudFinancialPeriodEndDate != null
          ? DateTime.tryParse(customer.cloudFinancialPeriodEndDate!)
          : null;
      _financialPeriodStartDate = customer.financialPeriodStartDate != null
          ? DateTime.tryParse(customer.financialPeriodStartDate!)
          : null;
      _financialPeriodEndDate = customer.financialPeriodEndDate != null
          ? DateTime.tryParse(customer.financialPeriodEndDate!)
          : null;

      _selectedSoftwareNames
        ..clear()
        ..addAll(_getPrefilledSoftwareNames(customer));

      // Group existing activations by software name
      for (final software in _availableSoftwares) {
        final entries = customer.softwareActivations
            .where((e) => e['name'] == software)
            .toList();

        if (entries.isEmpty) continue;

        _softwareDevices[software] = entries.map((entry) {
          return _DeviceActivation(
            deviceLabel: (entry['deviceLabel'] ?? entry['deviceType'] ?? '').toString(),
            userId: (entry['activationUserId'] ?? '').toString(),
            key: (entry['activationKey'] ?? '').toString(),
            activationDate: _parseActivationDate(entry['activationDate']),
            expiryDate: _parseActivationDate(entry['expiryDate']),
          );
        }).toList();
      }

      _checkExpiryAlerts();

      // Load existing main customer staff
      for (final s in customer.staff) {
        _mainCustomerStaff.add(_BranchStaff(name: s.name, phone: s.phone));
      }

      // Load existing branches with their software
      for (int branchIndex = 0; branchIndex < customer.branches.length; branchIndex++) {
        final branch = customer.branches[branchIndex];

        final branchData = _BranchData(
          name: branch.name,
          phone: branch.phone,
          phone2: branch.phone2 ?? '',
          email: branch.email ?? '',
          careOf: branch.careOf ?? '',
          organizationName: branch.organizationName ?? '',
          organizationUnitName: branch.organizationUnitName ?? '',
          commonName: branch.commonName ?? '',
          businessCategory: branch.businessCategory ?? '',
          address: branch.address,
          registeredAddress: branch.registeredAddress ?? '',
          buildingNo: branch.buildingNo ?? '',
          streetName: branch.streetName ?? '',
          districtName: branch.districtName ?? '',
          cityName: branch.cityName ?? '',
          zipCode: branch.zipCode ?? '',
          additionalNo: branch.additionalNo ?? '',
          unitNo: branch.unitNo ?? '',
          country: branch.country ?? '',
          taxNumber: branch.taxNumber ?? '',
          crNumber: branch.crNumber ?? '',
          zatcaEnabled: branch.zatcaEnabled,
          zatcaUsername: branch.zatcaUsername ?? '',
          zatcaPassword: branch.zatcaPassword ?? '',
          financialPeriodStartDate: branch.financialPeriodStartDate != null
              ? DateTime.tryParse(branch.financialPeriodStartDate!)
              : null,
          financialPeriodEndDate: branch.financialPeriodEndDate != null
              ? DateTime.tryParse(branch.financialPeriodEndDate!)
              : null,
          staffList: branch.staff
              .map((s) => _BranchStaff(
                    name: s.name,
                    phone: s.phone,
                  ))
              .toList(),
        );
        _branches.add(branchData);

        // Initialize branch software tracking
        _branchSelectedSoftwares[branchIndex] = [];
        _branchSoftwareDevices[branchIndex] = {};

        // Group branch software activations by software name
        for (final software in _availableSoftwares) {
          final entries = branch.softwareActivations
              .where((e) => e['name'] == software)
              .toList();

          if (entries.isEmpty) continue;

          _branchSelectedSoftwares[branchIndex]!.add(software);
          _branchSoftwareDevices[branchIndex]![software] = entries.map((entry) {
            return _DeviceActivation(
              deviceLabel:
                  (entry['deviceLabel'] ?? entry['deviceType'] ?? '').toString(),
              userId: (entry['activationUserId'] ?? '').toString(),
              key: (entry['activationKey'] ?? '').toString(),
              activationDate: _parseActivationDate(entry['activationDate']),
              expiryDate: _parseActivationDate(entry['expiryDate']),
            );
          }).toList();
        }
      }
    }

    if (widget.initialImportText != null && widget.initialImportText!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final parsed = CustomerTextParser.parse(widget.initialImportText!);
        _applyParsedCustomerData(parsed);
      });
    }
  }

  void _checkExpiryAlerts() {
    if (_expiryAlertShown) return;

    final now = DateTime.now();
    final expired = <String>[];

    for (final software in _selectedSoftwareNames) {
      final devices = _softwareDevices[software] ?? [];
      final hasExpired = devices.any((d) =>
          d.expiryDate != null && !d.expiryDate!.isAfter(now));
      if (hasExpired) expired.add(software);
    }

    _expiredSoftwares = expired;

    if (_expiredSoftwares.isNotEmpty && mounted) {
      _expiryAlertShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final message = _expiredSoftwares.length == 1
            ? '${_expiredSoftwares.first} has expired activations on one or more devices.'
            : '${_expiredSoftwares.length} software products have expired activations.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.alertTriangle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: Colors.amber.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      });
    }
  }

  DateTime? _parseActivationDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<String> _getPrefilledSoftwareNames(Customer customer) {
    if (customer.usedSoftwares.isNotEmpty) {
      return customer.usedSoftwares
          .where((s) => _availableSoftwares.contains(s))
          .toList();
    }
    return customer.softwareActivations
        .map((e) => e['name']?.toString())
        .whereType<String>()
        .where((n) => _availableSoftwares.contains(n))
        .toSet()
        .toList();
  }

  List<Map<String, dynamic>> _buildSoftwareActivations() {
    final List<Map<String, dynamic>> result = [];

    for (final software in _selectedSoftwareNames) {
      final devices = _softwareDevices[software] ?? [];
      for (final device in devices) {
        result.add({
          'name': software,
          'deviceLabel': device.deviceLabelController.text.trim(),
          'enabled': true,
          'activationUserId': device.userController.text.trim(),
          'activationKey': device.keyController.text.trim(),
          'activationDate': device.activationDate,
          'expiryDate': device.expiryDate,
        });
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _buildBranchSoftwareActivations(int branchIndex) {
    final List<Map<String, dynamic>> result = [];
    final selectedSoftwares = _branchSelectedSoftwares[branchIndex] ?? [];
    final softwareDevices = _branchSoftwareDevices[branchIndex] ?? {};

    for (final software in selectedSoftwares) {
      final devices = softwareDevices[software] ?? [];
      for (final device in devices) {
        result.add({
          'name': software,
          'deviceLabel': device.deviceLabelController.text.trim(),
          'enabled': true,
          'activationUserId': device.userController.text.trim(),
          'activationKey': device.keyController.text.trim(),
          'activationDate': device.activationDate,
          'expiryDate': device.expiryDate,
        });
      }
    }
    return result;
  }

  void _toggleSoftwareSelection(String software, bool? value) {
    setState(() {
      if (value == true) {
        if (!_selectedSoftwareNames.contains(software)) {
          _selectedSoftwareNames.add(software);
          _softwareDevices[software] = [_DeviceActivation(deviceLabel: 'Device 1')];
        }
      } else {
        _selectedSoftwareNames.remove(software);
        for (final d in _softwareDevices[software] ?? []) {
          d.dispose();
        }
        _softwareDevices.remove(software);
      }
    });
  }

  void _addDevice(String software) {
    setState(() {
      _softwareDevices.putIfAbsent(software, () => []);
      final count = (_softwareDevices[software]?.length ?? 0) + 1;
      _softwareDevices[software]!.add(
        _DeviceActivation(deviceLabel: 'Device $count'),
      );
    });
  }

  void _removeDevice(String software, int index) {
    setState(() {
      final list = _softwareDevices[software];
      if (list == null || index >= list.length) return;
      list[index].dispose();
      list.removeAt(index);
      if (list.isEmpty) {
        _selectedSoftwareNames.remove(software);
        _softwareDevices.remove(software);
      }
    });
  }

  void _toggleBranchSoftwareSelection(int branchIndex, String software, bool? value) {
    setState(() {
      _branchSelectedSoftwares.putIfAbsent(branchIndex, () => []);
      _branchSoftwareDevices.putIfAbsent(branchIndex, () => {});

      if (value == true) {
        if (!_branchSelectedSoftwares[branchIndex]!.contains(software)) {
          _branchSelectedSoftwares[branchIndex]!.add(software);
          _branchSoftwareDevices[branchIndex]![software] = [
            _DeviceActivation(deviceLabel: 'Device 1')
          ];
        }
      } else {
        _branchSelectedSoftwares[branchIndex]!.remove(software);
        for (final d in _branchSoftwareDevices[branchIndex]![software] ?? []) {
          d.dispose();
        }
        _branchSoftwareDevices[branchIndex]!.remove(software);
      }
    });
  }

  void _addBranchDevice(int branchIndex, String software) {
    setState(() {
      final devices = _branchSoftwareDevices[branchIndex]?[software];
      if (devices == null) return;
      final count = devices.length + 1;
      devices.add(_DeviceActivation(deviceLabel: 'Device $count'));
    });
  }

  void _removeBranchDevice(int branchIndex, String software, int index) {
    setState(() {
      final devices = _branchSoftwareDevices[branchIndex]?[software];
      if (devices == null || index >= devices.length) return;
      devices[index].dispose();
      devices.removeAt(index);
      if (devices.isEmpty) {
        _branchSelectedSoftwares[branchIndex]?.remove(software);
        _branchSoftwareDevices[branchIndex]?.remove(software);
      }
    });
  }

  Future<void> _pickBranchActivationDate(
      int branchIndex, String software, int deviceIndex,
      {required bool isExpiry}) async {
    final devices = _branchSoftwareDevices[branchIndex]?[software];
    if (devices == null || deviceIndex >= devices.length) return;

    final device = devices[deviceIndex];
    final initial = isExpiry ? device.expiryDate : device.activationDate;

    final picked = await _pickDateTime(initial ?? DateTime.now());
    if (picked != null) {
      setState(() {
        if (isExpiry) {
          device.expiryDate = picked;
        } else {
          device.activationDate = picked;
        }
      });
    }
  }

  Future<DateTime?> _pickDateTime(DateTime initialDateTime) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final isDark = AppTheme.isDark(context);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: FuturisticColors.neonCyan,
                    onPrimary: Colors.black,
                    surface: FuturisticColors.bgElevated,
                    onSurface: FuturisticColors.textPrimary,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF0D9488),
                    onPrimary: Colors.white,
                    onSurface: Color(0xFF1E293B),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return null;

    if (!mounted) return null;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
      builder: (context, child) {
        final isDark = AppTheme.isDark(context);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: FuturisticColors.neonCyan,
                    onPrimary: Colors.black,
                    surface: FuturisticColors.bgElevated,
                    onSurface: FuturisticColors.textPrimary,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF0D9488),
                    onPrimary: Colors.white,
                    onSurface: Color(0xFF1E293B),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _pickFinancialDate({required bool isStartDate}) async {
    final initialDate = (isStartDate
            ? _financialPeriodStartDate
            : _financialPeriodEndDate) ??
        DateTime.now();
    final pickedDateTime = await _pickDateTime(initialDate);

    if (pickedDateTime != null) {
      setState(() {
        if (isStartDate) {
          _financialPeriodStartDate = pickedDateTime;
        } else {
          _financialPeriodEndDate = pickedDateTime;
        }
      });
    }
  }

  Future<void> _pickCloudFinancialDate({required bool isStartDate}) async {
    final initialDate = (isStartDate
            ? _cloudFinancialPeriodStartDate
            : _cloudFinancialPeriodEndDate) ??
        DateTime.now();
    final pickedDateTime = await _pickDateTime(initialDate);

    if (pickedDateTime != null) {
      setState(() {
        if (isStartDate) {
          _cloudFinancialPeriodStartDate = pickedDateTime;
        } else {
          _cloudFinancialPeriodEndDate = pickedDateTime;
        }
      });
    }
  }

  Future<void> _pickBranchFinancialDate(
    int branchIndex, {
    required bool isStartDate,
  }) async {
    if (branchIndex >= _branches.length) return;
    final branch = _branches[branchIndex];
    final initialDate = (isStartDate
            ? branch.financialPeriodStartDate
            : branch.financialPeriodEndDate) ??
        DateTime.now();
    final pickedDateTime = await _pickDateTime(initialDate);

    if (pickedDateTime != null) {
      setState(() {
        if (isStartDate) {
          branch.financialPeriodStartDate = pickedDateTime;
        } else {
          branch.financialPeriodEndDate = pickedDateTime;
        }
      });
    }
  }

  Future<void> _pickActivationDate(
    String software,
    int deviceIndex, {
    required bool isExpiry,
  }) async {
    final devices = _softwareDevices[software];
    if (devices == null || deviceIndex >= devices.length) return;

    final device = devices[deviceIndex];
    final initial = isExpiry
        ? device.expiryDate ?? DateTime.now()
        : device.activationDate ?? DateTime.now();

    final picked = await _pickDateTime(initial);
    if (picked != null) {
      setState(() {
        if (isExpiry) {
          device.expiryDate = picked;
        } else {
          device.activationDate = picked;
        }
        _checkExpiryAlerts();
      });
    }
  }

  Future<void> _fetchPeriods() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('period_sections')
          .orderBy('name')
          .get();
      if (mounted) {
        _periods = snap.docs.map((doc) {
          final data = doc.data();
          return _Period(
            id: doc.id,
            name: data['name'] ?? 'Unnamed',
            startDate: (data['startDate'] as Timestamp).toDate(),
            endDate: (data['endDate'] as Timestamp).toDate(),
          );
        }).toList();

        if (_isEditing && widget.customer?.periodSectionId != null) {
          _matchPeriod(widget.customer!.periodSectionId!);
        }

        if (_isEditing && widget.customer?.branches != null) {
          for (int i = 0;
              i < widget.customer!.branches.length && i < _branches.length;
              i++) {
            final b = widget.customer!.branches[i];
            if (b.periodSectionId != null) {
              try {
                final match =
                    _periods.firstWhere((p) => p.id == b.periodSectionId);
                _branches[i].selectedPeriod = match;
              } catch (_) {}
            }
          }
        }

        setState(() => _periodsLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _periodsLoading = false);
      }
    }
  }

  void _matchPeriod(String periodId) {
    try {
      final match = _periods.firstWhere((p) => p.id == periodId);
      setState(() => _selectedPeriod = match);
    } catch (e) {
      // Period not found, leave as null
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _careOfController.dispose();
    _phoneController.dispose();
    _phone2Controller.dispose();
    _emailController.dispose();
    _organizationNameController.dispose();
    _organizationUnitNameController.dispose();
    _commonNameController.dispose();
    _businessCategoryController.dispose();
    _addressController.dispose();
    _registeredAddressController.dispose();
    _buildingNoController.dispose();
    _streetNameController.dispose();
    _districtNameController.dispose();
    _cityNameController.dispose();
    _zipCodeController.dispose();
    _additionalNoController.dispose();
    _unitNoController.dispose();
    _countryController.dispose();
    _taxNumberController.dispose();
    _crNumberController.dispose();
    _zatcaUsernameController.dispose();
    _zatcaPasswordController.dispose();

    for (final devices in _softwareDevices.values) {
      for (final d in devices) {
        d.dispose();
      }
    }

    for (final staff in _mainCustomerStaff) {
      staff.dispose();
    }

    for (final branch in _branches) {
      branch.dispose();
    }

    for (final branchDevices in _branchSoftwareDevices.values) {
      for (final devices in branchDevices.values) {
        for (final d in devices) {
          d.dispose();
        }
      }
    }

    super.dispose();
  }

  void _closeScreen() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _saveCustomer() async {
    final provider = Provider.of<CustomerProvider>(context, listen: false);
    if (provider.isLoading) return;

    // Check required fields and switch to relevant tab if invalid
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      setState(() => _activeTabIndex = 0);
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter customer name and primary phone number.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      setState(() => _activeTabIndex = 1);
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the primary customer address.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_taxNumberController.text.trim().isEmpty) {
      setState(() => _activeTabIndex = 2);
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the tax / VAT number.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    bool success;
    String successMessage;

    if (_isEditing) {
      success = await provider.updateCustomer(
        id: widget.customer!.id,
        name: _nameController.text.trim(),
        careOf: _careOfController.text.trim().isEmpty
          ? null
          : _careOfController.text.trim(),
        phone: _phoneController.text.trim(),
        phone2: _phone2Controller.text.trim().isEmpty
            ? null
            : _phone2Controller.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        organizationName: _organizationNameController.text.trim().isEmpty
            ? null
            : _organizationNameController.text.trim(),
        organizationUnitName:
            _organizationUnitNameController.text.trim().isEmpty
                ? null
                : _organizationUnitNameController.text.trim(),
        commonName: _commonNameController.text.trim().isEmpty
            ? null
            : _commonNameController.text.trim(),
        businessCategory: _businessCategoryController.text.trim().isEmpty
            ? null
            : _businessCategoryController.text.trim(),
        address: _addressController.text.trim(),
        registeredAddress: _registeredAddressController.text.trim().isEmpty
            ? null
            : _registeredAddressController.text.trim(),
        buildingNo: _buildingNoController.text.trim().isEmpty
            ? null
            : _buildingNoController.text.trim(),
        streetName: _streetNameController.text.trim().isEmpty
            ? null
            : _streetNameController.text.trim(),
        districtName: _districtNameController.text.trim().isEmpty
            ? null
            : _districtNameController.text.trim(),
        cityName: _cityNameController.text.trim().isEmpty
            ? null
            : _cityNameController.text.trim(),
        zipCode: _zipCodeController.text.trim().isEmpty
            ? null
            : _zipCodeController.text.trim(),
        additionalNo: _additionalNoController.text.trim().isEmpty
            ? null
            : _additionalNoController.text.trim(),
        unitNo: _unitNoController.text.trim().isEmpty
            ? null
            : _unitNoController.text.trim(),
        country: _countryController.text.trim().isEmpty
            ? null
            : _countryController.text.trim(),
        taxNumber: _taxNumberController.text.trim(),
        zatcaEnabled: _zatcaEnabled,
        crNumber: _crNumberController.text.trim().isEmpty
            ? null
            : _crNumberController.text.trim(),
        zatcaUsername: _zatcaUsernameController.text.trim().isEmpty
            ? null
            : _zatcaUsernameController.text.trim(),
        zatcaPassword: _zatcaPasswordController.text.trim().isEmpty
            ? null
            : _zatcaPasswordController.text.trim(),
        cloudStorageEnabled: _cloudStorageEnabled,
        cloudFinancialPeriodStartDate:
          _cloudFinancialPeriodStartDate?.toIso8601String(),
        cloudFinancialPeriodEndDate:
          _cloudFinancialPeriodEndDate?.toIso8601String(),
        financialPeriodStartDate: _financialPeriodStartDate?.toIso8601String(),
        financialPeriodEndDate: _financialPeriodEndDate?.toIso8601String(),
        editedById: context.read<AuthProvider>().currentUserId,
        editedByName: context.read<AuthProvider>().currentUserName,
        usedSoftwares: _selectedSoftwareNames,
        softwareActivations: _buildSoftwareActivations(),
        periodSectionId: _selectedPeriod?.id,
        periodSectionName: _selectedPeriod?.name,
        staff: _mainCustomerStaff
            .map((s) => Staff(
                  name: s.nameController.text.trim(),
                  phone: s.phoneController.text.trim(),
                ))
            .toList(),
        branches: List.generate(_branches.length, (index) {
          final branchData = _branches[index];
          return branchData.toModel(
            usedSoftwares: _branchSelectedSoftwares[index] ?? [],
            softwareActivations: _buildBranchSoftwareActivations(index),
          );
        }),
      );
      successMessage = 'Customer updated successfully!';
    } else {
      success = await provider.addCustomer(
        name: _nameController.text.trim(),
        careOf: _careOfController.text.trim().isEmpty
          ? null
          : _careOfController.text.trim(),
        phone: _phoneController.text.trim(),
        phone2: _phone2Controller.text.trim().isEmpty
            ? null
            : _phone2Controller.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        organizationName: _organizationNameController.text.trim().isEmpty
            ? null
            : _organizationNameController.text.trim(),
        organizationUnitName:
            _organizationUnitNameController.text.trim().isEmpty
                ? null
                : _organizationUnitNameController.text.trim(),
        commonName: _commonNameController.text.trim().isEmpty
            ? null
            : _commonNameController.text.trim(),
        businessCategory: _businessCategoryController.text.trim().isEmpty
            ? null
            : _businessCategoryController.text.trim(),
        address: _addressController.text.trim(),
        registeredAddress: _registeredAddressController.text.trim().isEmpty
            ? null
            : _registeredAddressController.text.trim(),
        buildingNo: _buildingNoController.text.trim().isEmpty
            ? null
            : _buildingNoController.text.trim(),
        streetName: _streetNameController.text.trim().isEmpty
            ? null
            : _streetNameController.text.trim(),
        districtName: _districtNameController.text.trim().isEmpty
            ? null
            : _districtNameController.text.trim(),
        cityName: _cityNameController.text.trim().isEmpty
            ? null
            : _cityNameController.text.trim(),
        zipCode: _zipCodeController.text.trim().isEmpty
            ? null
            : _zipCodeController.text.trim(),
        additionalNo: _additionalNoController.text.trim().isEmpty
            ? null
            : _additionalNoController.text.trim(),
        unitNo: _unitNoController.text.trim().isEmpty
            ? null
            : _unitNoController.text.trim(),
        country: _countryController.text.trim().isEmpty
            ? null
            : _countryController.text.trim(),
        taxNumber: _taxNumberController.text.trim(),
        zatcaEnabled: _zatcaEnabled,
        crNumber: _crNumberController.text.trim().isEmpty
            ? null
            : _crNumberController.text.trim(),
        zatcaUsername: _zatcaUsernameController.text.trim().isEmpty
            ? null
            : _zatcaUsernameController.text.trim(),
        zatcaPassword: _zatcaPasswordController.text.trim().isEmpty
            ? null
            : _zatcaPasswordController.text.trim(),
        cloudStorageEnabled: _cloudStorageEnabled,
        cloudFinancialPeriodStartDate:
          _cloudFinancialPeriodStartDate?.toIso8601String(),
        cloudFinancialPeriodEndDate:
          _cloudFinancialPeriodEndDate?.toIso8601String(),
        financialPeriodStartDate: _financialPeriodStartDate?.toIso8601String(),
        financialPeriodEndDate: _financialPeriodEndDate?.toIso8601String(),
        createdById: context.read<AuthProvider>().currentUserId,
        createdByName: context.read<AuthProvider>().currentUserName,
        usedSoftwares: _selectedSoftwareNames,
        softwareActivations: _buildSoftwareActivations(),
        periodSectionId: _selectedPeriod?.id,
        periodSectionName: _selectedPeriod?.name,
        staff: _mainCustomerStaff
            .map((s) => Staff(
                  name: s.nameController.text.trim(),
                  phone: s.phoneController.text.trim(),
                ))
            .toList(),
        branches: List.generate(_branches.length, (index) {
          final branchData = _branches[index];
          return branchData.toModel(
            usedSoftwares: _branchSelectedSoftwares[index] ?? [],
            softwareActivations: _buildBranchSoftwareActivations(index),
          );
        }),
      );
      successMessage = 'Customer created successfully!';
    }

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.checkCircle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(successMessage),
              ],
            ),
            backgroundColor: AppTheme.isDark(context)
                ? FuturisticColors.neonTeal
                : const Color(0xFF0D9488),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _closeScreen();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.alertCircle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(provider.errorMessage ?? 'Failed to save customer'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Custom Modern Text Field ────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = false,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    final isDark = AppTheme.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: isDark ? FuturisticColors.neonCrimson : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          obscureText: obscureText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hintText ?? 'Enter $label',
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? FuturisticColors.textMuted : const Color(0xFF94A3B8),
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            prefixIcon: Icon(icon, size: 18, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B)),
            suffixIcon: suffixIcon,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488), width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? FuturisticColors.neonCrimson : Colors.redAccent, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? FuturisticColors.neonCrimson : Colors.redAccent, width: 1.8),
            ),
          ),
          validator: required
              ? (value) => value == null || value.trim().isEmpty
                  ? 'Please enter $label'
                  : null
              : null,
        ),
      ],
    );
  }

  // ── Date Picker Field Component ─────────────────────────────────────────────
  Widget _buildDatePickerField({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
    IconData icon = LucideIcons.calendar,
  }) {
    final isDark = AppTheme.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selectedDate != null
                    ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488)).withValues(alpha: 0.4)
                    : (isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selectedDate != null
                      ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488))
                      : (isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedDate == null
                        ? 'Select date & time'
                        : DateFormat('dd MMM yyyy, hh:mm a').format(selectedDate),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selectedDate != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: selectedDate != null
                          ? (isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A))
                          : (isDark ? FuturisticColors.textMuted : const Color(0xFF94A3B8)),
                    ),
                  ),
                ),
                if (selectedDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488)).withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Set',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Section Card Container ──────────────────────────────────────────────────
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required Widget child,
    Widget? headerTrailing,
    Color accentColor = const Color(0xFF0D9488),
  }) {
    final isDark = AppTheme.isDark(context);
    final effectiveAccent = isDark
        ? (accentColor == const Color(0xFF0D9488)
            ? FuturisticColors.neonCyan
            : accentColor == const Color(0xFF6366F1)
                ? FuturisticColors.neonViolet
                : accentColor == const Color(0xFF0284C7)
                    ? FuturisticColors.neonCyan
                    : (accentColor == const Color(0xFF8B5CF6) || accentColor == const Color(0xFF7C3AED))
                        ? FuturisticColors.neonViolet
                        : accentColor == const Color(0xFF10B981)
                            ? FuturisticColors.neonTeal
                            : accentColor == const Color(0xFFF59E0B)
                                ? FuturisticColors.neonAmber
                                : accentColor)
        : accentColor;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgCard : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0), width: 1.2),
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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: effectiveAccent.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: effectiveAccent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
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
  }

  // ── Auto-Fill from Text / File ──────────────────────────────────────────────
  int _applyParsedCustomerData(ParsedCustomerData data) {
    int filled = 0;

    setState(() {
      // 1. Organization Unit Name & Primary Name
      if (data.organizationUnitName != null && data.organizationUnitName!.isNotEmpty) {
        _organizationUnitNameController.text = data.organizationUnitName!;
        filled++;
      }
      if (data.organizationName != null && data.organizationName!.isNotEmpty) {
        _organizationNameController.text = data.organizationName!;
        filled++;
      }
      if (data.commonName != null && data.commonName!.isNotEmpty) {
        _commonNameController.text = data.commonName!;
        filled++;
      }

      // Customer Primary Name (if empty, set from best available)
      if (_nameController.text.trim().isEmpty) {
        final bestName = data.primaryCustomerName;
        if (bestName.isNotEmpty) {
          _nameController.text = bestName;
          filled++;
        }
      }

      // 2. Business Category & Care Of
      if (data.businessCategory != null && data.businessCategory!.isNotEmpty) {
        _businessCategoryController.text = data.businessCategory!;
        filled++;
      }
      if (data.careOf != null && data.careOf!.isNotEmpty) {
        _careOfController.text = data.careOf!;
        filled++;
      }

      // 3. Contact Info
      if (data.phone != null && data.phone!.isNotEmpty) {
        _phoneController.text = data.phone!;
        filled++;
      }
      if (data.email != null && data.email!.isNotEmpty) {
        _emailController.text = data.email!;
        filled++;
      }

      // 4. Address Details
      if (data.country != null && data.country!.isNotEmpty) {
        _countryController.text = data.country!;
        filled++;
      }
      if (data.cityName != null && data.cityName!.isNotEmpty) {
        _cityNameController.text = data.cityName!;
        filled++;
      }
      if (data.districtName != null && data.districtName!.isNotEmpty) {
        _districtNameController.text = data.districtName!;
        filled++;
      }
      if (data.streetName != null && data.streetName!.isNotEmpty) {
        _streetNameController.text = data.streetName!;
        filled++;
      }
      if (data.buildingNo != null && data.buildingNo!.isNotEmpty) {
        _buildingNoController.text = data.buildingNo!;
        filled++;
      }
      if (data.zipCode != null && data.zipCode!.isNotEmpty) {
        _zipCodeController.text = data.zipCode!;
        filled++;
      }
      if (data.additionalNo != null && data.additionalNo!.isNotEmpty) {
        _additionalNoController.text = data.additionalNo!;
        filled++;
      }
      if (data.unitNo != null && data.unitNo!.isNotEmpty) {
        _unitNoController.text = data.unitNo!;
        filled++;
      }
      if (data.registeredAddress != null && data.registeredAddress!.isNotEmpty) {
        _registeredAddressController.text = data.registeredAddress!;
        filled++;
      }
      if (data.generalAddress != null && data.generalAddress!.isNotEmpty) {
        _addressController.text = data.generalAddress!;
        filled++;
      } else if (_addressController.text.trim().isEmpty) {
        final bestAddr = data.primaryAddress;
        if (bestAddr.isNotEmpty) {
          _addressController.text = bestAddr;
          filled++;
        }
      }

      // 5. Tax & ZATCA Registration
      if (data.vatNo != null && data.vatNo!.isNotEmpty) {
        _taxNumberController.text = data.vatNo!;
        _zatcaEnabled = true;
        filled++;
      }
      if (data.crNumber != null && data.crNumber!.isNotEmpty) {
        _crNumberController.text = data.crNumber!;
        filled++;
      }
      if (data.zatcaUsername != null && data.zatcaUsername!.isNotEmpty) {
        _zatcaUsernameController.text = data.zatcaUsername!;
        _zatcaEnabled = true;
        filled++;
      }
      if (data.zatcaPassword != null && data.zatcaPassword!.isNotEmpty) {
        _zatcaPasswordController.text = data.zatcaPassword!;
        filled++;
      }
    });

    return filled;
  }

  Future<void> _pickAndAutoFillFile({Function(String text)? onLoaded}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'ini', 'csv', 'text'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (!kIsWeb && file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        throw Exception('Could not read file content');
      }

      if (onLoaded != null) {
        onLoaded(content);
      } else {
        if (!mounted) return;
        _showAutoFillDialog(initialText: content, sourceFileName: file.name);
      }
    } catch (e) {
      debugPrint('Error importing file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read file: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showAutoFillDialog({String? initialText, String? sourceFileName}) {
    final textController = TextEditingController(text: initialText ?? '');
    String currentText = initialText ?? '';
    String? currentFileName = sourceFileName;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = AppTheme.isDark(dialogCtx);
        final isWide = MediaQuery.of(dialogCtx).size.width > 600;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final parsed = CustomerTextParser.parse(currentText);

            return AlertDialog(
              backgroundColor: AppTheme.cardBg(dialogCtx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.cardBorderColor(dialogCtx)),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              actionsPadding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? FuturisticColors.neonCyan.withValues(alpha: 0.15)
                          : const Color(0xFF0D9488).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      LucideIcons.fileSpreadsheet,
                      size: 20,
                      color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import & Auto-Fill Customer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary(dialogCtx),
                          ),
                        ),
                        Text(
                          currentFileName != null
                              ? 'Loaded from: $currentFileName'
                              : 'Select a .txt file or paste company details',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted(dialogCtx),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    icon: Icon(LucideIcons.x, size: 18, color: AppTheme.textMuted(dialogCtx)),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
              content: SizedBox(
                width: isWide ? 620 : double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Action buttons: Pick File, Paste Sample, Clear
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _pickAndAutoFillFile(
                                onLoaded: (loadedContent) {
                                  setModalState(() {
                                    currentText = loadedContent;
                                    textController.text = loadedContent;
                                  });
                                },
                              );
                            },
                            icon: const Icon(LucideIcons.folderOpen, size: 14),
                            label: const Text('Select .txt File'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              const sample = '''Country = SAUDI ARABIA
Organization Unit name  =Technology Computer 
Organization  name =مؤسسة عبدالرحمن عبدالله بن عبدالكريم الجهوري للصيانة
Organization Unit (TIN 10 Digit) =3108960731  
Common Name =Auto
Registered Address =Al Ajawad Street,Al Samir District,Jeddah Municipality – Buraiman Sub-Municipality,Jeddah, Saudi Arabia
Business Category = Trading
VAT No: 310896073100003
Email :
TelePhone :
Zatca credentials username :3108960731
  password :
Building no : 3525
street name :Al Ajawad
District Name : Al Samir
City Name : Jeddah
zip code : 23462
addit No : 7085
unit no :
Cr: 7021871715''';
                              setModalState(() {
                                currentText = sample;
                                textController.text = sample;
                                currentFileName = 'sample_format.txt';
                              });
                            },
                            icon: const Icon(LucideIcons.fileText, size: 13),
                            label: const Text('Paste Sample'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary(dialogCtx),
                              side: BorderSide(color: AppTheme.cardBorderColor(dialogCtx)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const Spacer(),
                          if (currentText.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  currentText = '';
                                  textController.clear();
                                  currentFileName = null;
                                });
                              },
                              icon: const Icon(LucideIcons.trash2, size: 12, color: Colors.redAccent),
                              label: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Text Editor
                      TextField(
                        controller: textController,
                        maxLines: 8,
                        onChanged: (val) {
                          setModalState(() {
                            currentText = val;
                          });
                        },
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: AppTheme.textPrimary(dialogCtx),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Paste text or select file here...\nExample:\nCountry = SAUDI ARABIA\nOrganization Unit name = Technology Computer\nVAT No: 310896073100003\nBuilding no : 3525\nCity Name : Jeddah\nCr: 7021871715',
                          hintStyle: TextStyle(
                            color: AppTheme.textMuted(dialogCtx),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                          filled: true,
                          fillColor: AppTheme.inputBg(dialogCtx),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppTheme.cardBorderColor(dialogCtx)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppTheme.cardBorderColor(dialogCtx)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Parsed Fields Live Summary
                      if (currentText.trim().isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? FuturisticColors.bgVoid.withValues(alpha: 0.5)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.cardBorderColor(dialogCtx)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    LucideIcons.checkCheck,
                                    size: 14,
                                    color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${parsed.filledFieldCount} Fields Detected',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (parsed.organizationUnitName != null)
                                    _buildParsedChip('Name: ${parsed.organizationUnitName}', isDark),
                                  if (parsed.organizationName != null)
                                    _buildParsedChip('Arabic: ${parsed.organizationName}', isDark),
                                  if (parsed.vatNo != null)
                                    _buildParsedChip('VAT: ${parsed.vatNo}', isDark),
                                  if (parsed.crNumber != null)
                                    _buildParsedChip('CR: ${parsed.crNumber}', isDark),
                                  if (parsed.zatcaUsername != null)
                                    _buildParsedChip('ZATCA User: ${parsed.zatcaUsername}', isDark),
                                  if (parsed.cityName != null)
                                    _buildParsedChip('City: ${parsed.cityName}', isDark),
                                  if (parsed.buildingNo != null)
                                    _buildParsedChip('Bldg: ${parsed.buildingNo}', isDark),
                                  if (parsed.streetName != null)
                                    _buildParsedChip('Street: ${parsed.streetName}', isDark),
                                  if (parsed.districtName != null)
                                    _buildParsedChip('District: ${parsed.districtName}', isDark),
                                  if (parsed.zipCode != null)
                                    _buildParsedChip('Zip: ${parsed.zipCode}', isDark),
                                  if (parsed.additionalNo != null)
                                    _buildParsedChip('Addit: ${parsed.additionalNo}', isDark),
                                  if (parsed.country != null)
                                    _buildParsedChip('Country: ${parsed.country}', isDark),
                                  if (parsed.businessCategory != null)
                                    _buildParsedChip('Category: ${parsed.businessCategory}', isDark),
                                  if (parsed.commonName != null)
                                    _buildParsedChip('Common: ${parsed.commonName}', isDark),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted(dialogCtx))),
                ),
                ElevatedButton.icon(
                  onPressed: parsed.filledFieldCount == 0
                      ? null
                      : () {
                          final count = _applyParsedCustomerData(parsed);
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text('Successfully auto-filled $count customer fields from text!'),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.teal.shade700,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  icon: const Icon(LucideIcons.sparkles, size: 14),
                  label: Text('Auto-Fill Form (${parsed.filledFieldCount} Fields)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildParsedChip(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? FuturisticColors.neonCyan.withValues(alpha: 0.1)
            : const Color(0xFF0D9488).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? FuturisticColors.neonCyan.withValues(alpha: 0.25)
              : const Color(0xFF0D9488).withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAutoFillBanner(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark
            ? FuturisticColors.neonCyan.withValues(alpha: 0.08)
            : const Color(0xFF0D9488).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? FuturisticColors.neonCyan.withValues(alpha: 0.3)
              : const Color(0xFF0D9488).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isDark
                  ? FuturisticColors.neonCyan.withValues(alpha: 0.15)
                  : const Color(0xFF0D9488).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              LucideIcons.fileSpreadsheet,
              size: 18,
              color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-fill Company Details from Text File',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Import Country, Org names, VAT, CR, ZATCA, and national address format instantly',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showAutoFillDialog(),
            icon: const Icon(LucideIcons.uploadCloud, size: 14),
            label: const Text('Import / Paste'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: General & Contact Information ────────────────────────────────────
  Widget _buildGeneralTab() {
    final isDark = AppTheme.isDark(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAutoFillBanner(context, isDark),
          // Basic Info
          _buildSectionCard(
            title: 'Customer Basic Information',
            subtitle: 'Primary contact name, phone, and optional email',
            icon: LucideIcons.user,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _nameController,
                        label: 'Customer / Business Name',
                        hintText: 'e.g. Al-Madina Trading Co.',
                        icon: LucideIcons.user,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        controller: _careOfController,
                        label: 'C/O By (Optional)',
                        hintText: 'e.g. Contact person or representative name',
                        icon: LucideIcons.userCheck,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _phoneController,
                        label: 'Primary Phone Number',
                        hintText: 'e.g. +966 50 123 4567',
                        icon: LucideIcons.phone,
                        keyboardType: TextInputType.phone,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        controller: _phone2Controller,
                        label: 'Secondary Phone (Optional)',
                        hintText: 'e.g. +966 55 987 6543',
                        icon: LucideIcons.phoneCall,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address (Optional)',
                  hintText: 'e.g. accounts@almadina.com',
                  icon: LucideIcons.mail,
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),

          // Period Section
          _buildSectionCard(
            title: 'Period Section',
            subtitle: 'Assign customer to a fiscal reporting period',
            icon: LucideIcons.calendarRange,
            accentColor: const Color(0xFF6366F1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_periodsLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                else if (_periods.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.info, size: 16, color: isDark ? FuturisticColors.textMuted : Colors.grey.shade500),
                        const SizedBox(width: 10),
                        Text(
                          'No periods available in system.',
                          style: TextStyle(
                            color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _PeriodPicker(
                    periods: _periods,
                    selected: _selectedPeriod,
                    onSelected: (p) => setState(() => _selectedPeriod = p),
                  ),
              ],
            ),
          ),

          // Organization Details
          _buildSectionCard(
            title: 'Organization Details',
            subtitle: 'Official corporate classification and units',
            icon: LucideIcons.building,
            accentColor: const Color(0xFF0284C7),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _organizationNameController,
                        label: 'Organization Name',
                        hintText: 'e.g. Al-Madina Group Ltd.',
                        icon: LucideIcons.building2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        controller: _organizationUnitNameController,
                        label: 'Unit / Division Name',
                        hintText: 'e.g. Retail Division',
                        icon: LucideIcons.network,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _commonNameController,
                        label: 'Common / Trade Name',
                        hintText: 'e.g. Al-Madina Supermarket',
                        icon: LucideIcons.tag,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        controller: _businessCategoryController,
                        label: 'Business Category',
                        hintText: 'e.g. Grocery & Retail',
                        icon: LucideIcons.layoutGrid,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Customer Staff
          _buildSectionCard(
            title: 'Main Customer Staff & Representatives',
            subtitle: 'Key point-of-contacts for this client',
            icon: LucideIcons.users,
            accentColor: const Color(0xFF8B5CF6),
            headerTrailing: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _mainCustomerStaff.add(_BranchStaff());
                });
              },
              icon: const Icon(LucideIcons.userPlus, size: 15),
              label: const Text('Add Contact'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? FuturisticColors.neonViolet : const Color(0xFF8B5CF6),
                side: BorderSide(color: isDark ? FuturisticColors.neonViolet : const Color(0xFF8B5CF6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_mainCustomerStaff.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(LucideIcons.users, size: 28, color: isDark ? FuturisticColors.textMuted : Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'No contact staff added yet',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Click "+ Add Contact" above to record contact persons.',
                            style: TextStyle(fontSize: 12, color: isDark ? FuturisticColors.textMuted : Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...List.generate(_mainCustomerStaff.length, (staffIndex) {
                    final staff = _mainCustomerStaff[staffIndex];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: (isDark ? FuturisticColors.neonViolet : const Color(0xFF8B5CF6)).withValues(alpha: 0.15),
                            child: Text(
                              '${staffIndex + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? FuturisticColors.neonViolet : const Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: staff.nameController,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: 'Staff Name',
                                      labelStyle: TextStyle(
                                        color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
                                      ),
                                      prefixIcon: Icon(
                                        LucideIcons.user,
                                        size: 16,
                                        color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
                                      ),
                                      filled: true,
                                      fillColor: isDark ? FuturisticColors.bgCard : Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: isDark ? FuturisticColors.neonViolet : const Color(0xFF8B5CF6),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: staff.phoneController,
                                    keyboardType: TextInputType.phone,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: 'Phone Number',
                                      labelStyle: TextStyle(
                                        color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
                                      ),
                                      prefixIcon: Icon(
                                        LucideIcons.phone,
                                        size: 16,
                                        color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
                                      ),
                                      filled: true,
                                      fillColor: isDark ? FuturisticColors.bgCard : Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: isDark ? FuturisticColors.neonViolet : const Color(0xFF8B5CF6),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2, size: 18),
                            color: Colors.red.shade400,
                            tooltip: 'Remove',
                            onPressed: () {
                              setState(() {
                                staff.dispose();
                                _mainCustomerStaff.removeAt(staffIndex);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Address & Location Details ───────────────────────────────────────
  Widget _buildAddressTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary Addresses
          _buildSectionCard(
            title: 'Primary & Registered Addresses',
            subtitle: 'National address and official correspondence address',
            icon: LucideIcons.mapPin,
            accentColor: const Color(0xFFF59E0B),
            child: Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _addressController,
                    label: 'Primary Street Address',
                    hintText: 'Enter complete street address / building details',
                    icon: LucideIcons.mapPin,
                    maxLines: 4,
                    required: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    controller: _registeredAddressController,
                    label: 'Registered / Legal Address (Optional)',
                    hintText: 'Enter registered legal address if different from primary',
                    icon: LucideIcons.building,
                    maxLines: 4,
                  ),
                ),
              ],
            ),
          ),

          // National Address Attributes
          _buildSectionCard(
            title: 'National Address Specification (Saudi Post / SPL)',
            subtitle: 'Detailed components for ZATCA standard e-invoicing address',
            icon: LucideIcons.compass,
            accentColor: const Color(0xFF10B981),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _buildingNoController,
                        label: 'Building No.',
                        hintText: '4 digits (e.g. 1234)',
                        icon: LucideIcons.home,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        controller: _additionalNoController,
                        label: 'Additional No.',
                        hintText: '4 digits (e.g. 5678)',
                        icon: LucideIcons.hash,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _streetNameController,
                        label: 'Street Name',
                        hintText: 'e.g. King Fahd Road',
                        icon: LucideIcons.navigation,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        controller: _districtNameController,
                        label: 'District Name',
                        hintText: 'e.g. Al Olaya',
                        icon: LucideIcons.map,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _cityNameController,
                        label: 'City Name',
                        hintText: 'e.g. Riyadh',
                        icon: LucideIcons.building2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        controller: _countryController,
                        label: 'Country',
                        hintText: 'e.g. Saudi Arabia (SA)',
                        icon: LucideIcons.globe,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _unitNoController,
                        label: 'Unit / Suite No.',
                        hintText: 'e.g. 102',
                        icon: LucideIcons.doorOpen,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        controller: _zipCodeController,
                        label: 'Postal / ZIP Code',
                        hintText: '5 digits (e.g. 12211)',
                        icon: LucideIcons.mail,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Tax, ZATCA & Financial Period ─────────────────────────────────────
  Widget _buildTaxAndZatcaTab() {
    final isDark = AppTheme.isDark(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tax & CR Information
          _buildSectionCard(
            title: 'Tax & Commercial Registration',
            subtitle: 'VAT identification and official company registry numbers',
            icon: LucideIcons.fileCheck,
            accentColor: const Color(0xFF0D9488),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _taxNumberController,
                        label: 'VAT / Tax Number',
                        hintText: '15-digit VAT number (e.g. 300000000000003)',
                        icon: LucideIcons.receipt,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        controller: _crNumberController,
                        label: 'CR Number (Optional)',
                        hintText: '10-digit Commercial Registration number',
                        icon: LucideIcons.briefcase,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ZATCA Integration Card
          _buildSectionCard(
            title: 'ZATCA (Fatoora Phase 2) Integration',
            subtitle: 'API credentials for automatic invoice clearance & reporting',
            icon: LucideIcons.shieldCheck,
            accentColor: const Color(0xFF10B981),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _zatcaEnabled
                        ? (isDark ? FuturisticColors.neonTeal.withValues(alpha: 0.08) : const Color(0xFF10B981).withValues(alpha: 0.08))
                        : (isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _zatcaEnabled
                          ? (isDark ? FuturisticColors.neonTeal.withValues(alpha: 0.4) : const Color(0xFF10B981).withValues(alpha: 0.4))
                          : (isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _zatcaEnabled
                              ? (isDark ? FuturisticColors.neonTeal : const Color(0xFF10B981))
                              : (isDark ? FuturisticColors.bgElevated : Colors.grey.shade400),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.shieldCheck,
                            size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enable ZATCA Integration',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _zatcaEnabled
                                  ? 'ZATCA credentials will be used for onboarding and compliance.'
                                  : 'Turn on to enable direct ZATCA e-invoicing features.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _zatcaEnabled,
                        activeTrackColor: (isDark ? FuturisticColors.neonTeal : const Color(0xFF10B981)).withValues(alpha: 0.5),
                        activeThumbColor: isDark ? FuturisticColors.neonTeal : const Color(0xFF10B981),
                        onChanged: (val) => setState(() => _zatcaEnabled = val),
                      ),
                    ],
                  ),
                ),
                if (_zatcaEnabled) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _zatcaUsernameController,
                          label: 'ZATCA Compliance Username / CSID',
                          hintText: 'e.g. ZATCA portal username / Binary security token',
                          icon: LucideIcons.userCheck,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: _zatcaPasswordController,
                          label: 'ZATCA Secret / Password',
                          hintText: 'Secret password / token',
                          icon: LucideIcons.lock,
                          obscureText: _obscureZatcaPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureZatcaPassword
                                  ? LucideIcons.eye
                                  : LucideIcons.eyeOff,
                              size: 18,
                              color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureZatcaPassword = !_obscureZatcaPassword;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

         // Financial Period
          _buildSectionCard(
            title: 'Zatca Financial Year',
            subtitle: 'Customer accounting cycle start and conclusion dates',
            icon: LucideIcons.calendarDays,
            accentColor: const Color(0xFF0284C7),
            child: Row(
              children: [
                Expanded(
                  child: _buildDatePickerField(
                    label: 'Zatca AMC Start Date & Time',
                    selectedDate: _financialPeriodStartDate,
                    onTap: () => _pickFinancialDate(isStartDate: true),
                    icon: LucideIcons.calendarCheck,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDatePickerField(
                    label: 'Zatca AMC End Date & Time',
                    selectedDate: _financialPeriodEndDate,
                    onTap: () => _pickFinancialDate(isStartDate: false),
                    icon: LucideIcons.calendarClock,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          _buildSectionCard(
            title: 'Cloud Storage',
            subtitle: 'Configure cloud storage and its financial period expiry dates',
            icon: LucideIcons.cloud,
            accentColor: const Color(0xFF7C3AED),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _cloudStorageEnabled
                        ? (isDark ? FuturisticColors.neonViolet.withValues(alpha: 0.08) : const Color(0xFF7C3AED).withValues(alpha: 0.08))
                        : (isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _cloudStorageEnabled
                          ? (isDark ? FuturisticColors.neonViolet.withValues(alpha: 0.4) : const Color(0xFF7C3AED).withValues(alpha: 0.4))
                          : (isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.cloud,
                        size: 21,
                        color: _cloudStorageEnabled
                            ? (isDark ? FuturisticColors.neonViolet : const Color(0xFF7C3AED))
                            : (isDark ? FuturisticColors.textMuted : Colors.grey.shade500),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Enable cloud storage',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Switch(
                        value: _cloudStorageEnabled,
                        activeTrackColor: (isDark ? FuturisticColors.neonViolet : const Color(0xFF7C3AED)).withValues(alpha: 0.5),
                        activeThumbColor: isDark ? FuturisticColors.neonViolet : const Color(0xFF7C3AED),
                        onChanged: (value) =>
                            setState(() => _cloudStorageEnabled = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildDatePickerField(
                        label: 'Cloud Start Date & Time',
                        selectedDate: _cloudFinancialPeriodStartDate,
                        onTap: () =>
                            _pickCloudFinancialDate(isStartDate: true),
                        icon: LucideIcons.calendarCheck,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDatePickerField(
                        label: 'Cloud Expiry Date & Time',
                        selectedDate: _cloudFinancialPeriodEndDate,
                        onTap: () =>
                            _pickCloudFinancialDate(isStartDate: false),
                        icon: LucideIcons.calendarClock,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        
        ],
      ),
    );
  }

  // ── Tab 4: Software Licenses & Devices ───────────────────────────────────────
  Widget _buildSoftwareTab() {
    final isDark = AppTheme.isDark(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Select Software Products',
            subtitle: 'Choose and activate licensed ERP and POS software products',
            icon: LucideIcons.laptop,
            accentColor: const Color(0xFF6366F1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Software checkboxes grid
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _availableSoftwares.map((software) {
                    final selected = _selectedSoftwareNames.contains(software);
                    final deviceCount = _softwareDevices[software]?.length ?? 0;

                    return InkWell(
                      onTap: () => _toggleSoftwareSelection(software, !selected),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? (isDark ? FuturisticColors.neonCyan.withValues(alpha: 0.12) : const Color(0xFF6366F1).withValues(alpha: 0.08))
                              : (isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF6366F1))
                                : (isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                            width: selected ? 1.6 : 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              selected
                                  ? LucideIcons.checkSquare
                                  : LucideIcons.square,
                              size: 18,
                              color: selected
                                  ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF6366F1))
                                  : (isDark ? FuturisticColors.textMuted : Colors.grey.shade400),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              software,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF6366F1))
                                    : (isDark ? FuturisticColors.textPrimary : const Color(0xFF1E293B)),
                              ),
                            ),
                            if (selected && deviceCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? FuturisticColors.neonCyan : const Color(0xFF6366F1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$deviceCount ${deviceCount == 1 ? "Device" : "Devices"}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
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

                if (_selectedSoftwareNames.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                  const SizedBox(height: 10),

                  // Device activations per selected software
                  ..._selectedSoftwareNames.map((software) {
                    final devices = _softwareDevices[software] ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? FuturisticColors.bgCard : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: (isDark ? FuturisticColors.neonCyan : const Color(0xFF6366F1)).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(LucideIcons.layers,
                                    size: 16, color: isDark ? FuturisticColors.neonCyan : const Color(0xFF6366F1)),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$software Activation Nodes',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                                ),
                              ),
                              const Spacer(),
                              OutlinedButton.icon(
                                onPressed: () => _addDevice(software),
                                icon: const Icon(LucideIcons.plus, size: 14),
                                label: const Text('Add Device'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF6366F1),
                                  side: BorderSide(color: isDark ? FuturisticColors.neonCyan : const Color(0xFF6366F1)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Device Items
                          ...List.generate(devices.length, (deviceIndex) {
                            final device = devices[deviceIndex];
                            final isExpired = device.expiryDate != null &&
                                !device.expiryDate!.isAfter(DateTime.now());

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? FuturisticColors.bgInput : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isExpired
                                      ? (isDark ? FuturisticColors.neonCrimson : Colors.red.shade300)
                                      : (isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                                  width: isExpired ? 1.4 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (isDark ? FuturisticColors.neonCyan : const Color(0xFF6366F1))
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Device ${deviceIndex + 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? FuturisticColors.neonCyan : const Color(0xFF6366F1),
                                          ),
                                        ),
                                      ),
                                      if (isExpired) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (isDark ? FuturisticColors.neonCrimson : Colors.red).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                                color: isDark ? FuturisticColors.neonCrimson.withValues(alpha: 0.4) : Colors.red.shade300),
                                          ),
                                          child: Text(
                                            'EXPIRED',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? FuturisticColors.neonCrimson : Colors.red.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      if (devices.length > 1)
                                        IconButton(
                                          icon: const Icon(LucideIcons.trash2,
                                              size: 16),
                                          color: Colors.red.shade400,
                                          tooltip: 'Remove device',
                                          onPressed: () =>
                                              _removeDevice(software, deviceIndex),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          controller: device.deviceLabelController,
                                          label: 'Device Label / Name',
                                          hintText: 'e.g. Server, POS Terminal 1',
                                          icon: LucideIcons.monitor,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildTextField(
                                          controller: device.userController,
                                          label: 'Activation User ID',
                                          hintText: 'e.g. USER-101',
                                          icon: LucideIcons.key,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _buildTextField(
                                    controller: device.keyController,
                                    label: 'Software License / Activation Key',
                                    hintText: 'e.g. XXXX-XXXX-XXXX-XXXX',
                                    icon: LucideIcons.lock,
                                    suffixIcon: IconButton(
                                      icon: Icon(LucideIcons.copy, size: 16, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF64748B)),
                                      tooltip: 'Copy Key',
                                      onPressed: () {
                                        if (device.keyController.text.isNotEmpty) {
                                          Clipboard.setData(ClipboardData(
                                              text: device.keyController.text));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Activation Key copied!'),
                                              duration: Duration(seconds: 2),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDatePickerField(
                                          label: 'Activation Date & Time',
                                          selectedDate: device.activationDate,
                                          onTap: () => _pickActivationDate(
                                              software, deviceIndex,
                                              isExpiry: false),
                                          icon: LucideIcons.calendarPlus,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildDatePickerField(
                                          label: 'License Expiry Date & Time',
                                          selectedDate: device.expiryDate,
                                          onTap: () => _pickActivationDate(
                                              software, deviceIndex,
                                              isExpiry: true),
                                          icon: LucideIcons.calendarX,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),

                  // Software Activation Summary Map
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? FuturisticColors.bgInput : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(LucideIcons.fileSpreadsheet,
                                size: 16, color: isDark ? FuturisticColors.textSecondary : const Color(0xFF475569)),
                            const SizedBox(width: 8),
                            Text(
                              'Software Activation Matrix Overview',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: isDark ? FuturisticColors.textPrimary : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._buildSoftwareActivations().map((entry) {
                          final label =
                              entry['deviceLabel']?.toString().isNotEmpty == true
                                  ? entry['deviceLabel']
                                  : 'Device';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488))),
                                Expanded(
                                  child: Text(
                                    '${entry['name']} ($label) — User: ${entry['activationUserId'].isEmpty ? "None" : entry['activationUserId']} | Key: ${entry['activationKey'].isEmpty ? "None" : entry['activationKey']}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? FuturisticColors.textSecondary : const Color(0xFF334155),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 5: Branches & Multi-Site Locations ───────────────────────────────────
  Widget _buildBranchesTab() {
    final isDark = AppTheme.isDark(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Branches & Multi-Location Outlets',
            subtitle: 'Manage client subsidiary branches, staff, and branch software licenses',
            icon: LucideIcons.gitBranch,
            accentColor: const Color(0xFF0D9488),
            headerTrailing: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _branches.add(_BranchData(staffList: [_BranchStaff()]));
                });
              },
              icon: const Icon(LucideIcons.plus, size: 15),
              label: const Text('Add Branch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_branches.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? FuturisticColors.bgElevated : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(LucideIcons.gitBranch,
                              size: 32, color: isDark ? FuturisticColors.neonCyan.withValues(alpha: 0.5) : Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            'No separate branches configured',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'If this customer operates multiple stores or branches, click "+ Add Branch" above.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...List.generate(_branches.length, (branchIndex) {
                    final branch = _branches[branchIndex];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? FuturisticColors.bgElevated : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Branch Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? FuturisticColors.neonCyan.withValues(alpha: 0.2) : const Color(0xFF0D9488),
                                  borderRadius: BorderRadius.circular(8),
                                  border: isDark ? Border.all(color: FuturisticColors.neonCyan.withValues(alpha: 0.5)) : null,
                                ),
                                child: Text(
                                  'Branch #${branchIndex + 1}',
                                  style: TextStyle(
                                    color: isDark ? FuturisticColors.neonCyan : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(LucideIcons.trash2, size: 18),
                                color: Colors.red.shade400,
                                tooltip: 'Remove branch',
                                onPressed: () {
                                  setState(() {
                                    _branches[branchIndex].dispose();
                                    _branches.removeAt(branchIndex);
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Branch Inputs
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.nameController,
                                  label: 'Branch Name',
                                  hintText: 'e.g. Jeddah Downtown Branch',
                                  icon: LucideIcons.building,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.phoneController,
                                  label: 'Branch Contact Phone',
                                  hintText: 'e.g. +966 12 654 3210',
                                  icon: LucideIcons.phone,
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            controller: branch.addressController,
                            label: 'Branch Address',
                            hintText: 'e.g. King Abdulaziz St., Al Andalus Dist.',
                            icon: LucideIcons.mapPin,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.careOfController,
                                  label: 'Care Of',
                                  icon: LucideIcons.user,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.phone2Controller,
                                  label: 'Alternative Phone',
                                  icon: LucideIcons.phone,
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.emailController,
                                  label: 'Email',
                                  icon: LucideIcons.mail,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.organizationNameController,
                                  label: 'Organization Name',
                                  icon: LucideIcons.building2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.organizationUnitNameController,
                                  label: 'Organization Unit Name',
                                  icon: LucideIcons.building,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.commonNameController,
                                  label: 'Common Name',
                                  icon: LucideIcons.badgeCheck,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.businessCategoryController,
                                  label: 'Business Category',
                                  icon: LucideIcons.briefcase,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.taxNumberController,
                                  label: 'VAT / TIN Number',
                                  icon: LucideIcons.fileDigit,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.crNumberController,
                                  label: 'CR Number',
                                  icon: LucideIcons.fileText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            controller: branch.registeredAddressController,
                            label: 'Registered Address',
                            icon: LucideIcons.building,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.buildingNoController,
                                  label: 'Building No.',
                                  icon: LucideIcons.hash,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.streetNameController,
                                  label: 'Street Name',
                                  icon: LucideIcons.compass,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.districtNameController,
                                  label: 'District Name',
                                  icon: LucideIcons.map,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.cityNameController,
                                  label: 'City Name',
                                  icon: LucideIcons.navigation,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.zipCodeController,
                                  label: 'ZIP Code',
                                  icon: LucideIcons.mailCheck,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.additionalNoController,
                                  label: 'Additional No.',
                                  icon: LucideIcons.plus,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.unitNoController,
                                  label: 'Unit No.',
                                  icon: LucideIcons.doorOpen,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTextField(
                                  controller: branch.countryController,
                                  label: 'Country',
                                  icon: LucideIcons.globe,
                                ),
                              ),
                              const Spacer(),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ── Branch ZATCA Integration Section ──
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: branch.zatcaEnabled
                                  ? (isDark
                                      ? FuturisticColors.neonCyan.withValues(alpha: 0.08)
                                      : const Color(0xFF0D9488).withValues(alpha: 0.04))
                                  : (isDark
                                      ? FuturisticColors.bgElevated
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: branch.zatcaEnabled
                                    ? (isDark
                                        ? FuturisticColors.neonCyan.withValues(alpha: 0.4)
                                        : const Color(0xFF0D9488).withValues(alpha: 0.35))
                                    : AppTheme.cardBorderColor(context),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Switch Header
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: (branch.zatcaEnabled
                                                ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488))
                                                : Colors.grey.shade400)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        LucideIcons.shieldCheck,
                                        size: 18,
                                        color: branch.zatcaEnabled
                                            ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488))
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'ZATCA Integration for this Branch',
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.textPrimary(context),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: (branch.zatcaEnabled
                                                          ? const Color(0xFF10B981)
                                                          : Colors.grey.shade400)
                                                      .withValues(alpha: 0.18),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  branch.zatcaEnabled ? 'ENABLED' : 'DISABLED',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: branch.zatcaEnabled
                                                        ? const Color(0xFF10B981)
                                                        : Colors.grey.shade600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            branch.zatcaEnabled
                                                ? 'Branch credentials & financial period are active for e-invoicing compliance.'
                                                : 'Enable if this branch operates under separate ZATCA credentials or fiscal period.',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: AppTheme.textMuted(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: branch.zatcaEnabled,
                                      activeThumbColor: isDark
                                          ? FuturisticColors.neonCyan
                                          : const Color(0xFF0D9488),
                                      activeTrackColor: (isDark
                                              ? FuturisticColors.neonCyan
                                              : const Color(0xFF0D9488))
                                          .withValues(alpha: 0.5),
                                      onChanged: (val) {
                                        setState(() {
                                          branch.zatcaEnabled = val;
                                        });
                                      },
                                    ),
                                  ],
                                ),

                                // ZATCA Details (Visible when enabled)
                                if (branch.zatcaEnabled) ...[
                                  const SizedBox(height: 12),
                                  Divider(height: 1, color: AppTheme.cardBorderColor(context)),
                                  const SizedBox(height: 12),

                                  // Credentials: Username & Password
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          controller: branch.zatcaUsernameController,
                                          label: 'Branch ZATCA Username / CSID',
                                          hintText: 'e.g. branch-csid-portal-user',
                                          icon: LucideIcons.userCheck,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildTextField(
                                          controller: branch.zatcaPasswordController,
                                          label: 'Branch ZATCA Secret / Password',
                                          hintText: '••••••••••••',
                                          icon: LucideIcons.lock,
                                          obscureText: branch.obscureZatcaPassword,
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              branch.obscureZatcaPassword
                                                  ? LucideIcons.eye
                                                  : LucideIcons.eyeOff,
                                              size: 16,
                                              color: AppTheme.textSecondary(context),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                branch.obscureZatcaPassword =
                                                    !branch.obscureZatcaPassword;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // Financial Period Header & Quick Sync
                                  Row(
                                    children: [
                                      Icon(
                                        LucideIcons.calendarDays,
                                        size: 15,
                                        color: isDark
                                            ? FuturisticColors.neonCyan
                                            : const Color(0xFF0284C7),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Branch ZATCA Financial Period',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary(context),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (_financialPeriodStartDate != null ||
                                          _financialPeriodEndDate != null ||
                                          _selectedPeriod != null)
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              branch.financialPeriodStartDate =
                                                  _financialPeriodStartDate;
                                              branch.financialPeriodEndDate =
                                                  _financialPeriodEndDate;
                                              branch.selectedPeriod =
                                                  _selectedPeriod;
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Copied main customer financial period to branch!'),
                                                duration: Duration(seconds: 2),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 3),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  LucideIcons.copy,
                                                  size: 13,
                                                  color: isDark
                                                      ? FuturisticColors.neonCyan
                                                      : const Color(0xFF0D9488),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Copy from Main Customer',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? FuturisticColors.neonCyan
                                                        : const Color(0xFF0D9488),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Fiscal Period Start & End Pickers
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDatePickerField(
                                          label: 'Fiscal Year Start Date',
                                          selectedDate:
                                              branch.financialPeriodStartDate,
                                          onTap: () =>
                                              _pickBranchFinancialDate(
                                                  branchIndex,
                                                  isStartDate: true),
                                          icon: LucideIcons.calendarCheck,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildDatePickerField(
                                          label: 'Fiscal Year End Date',
                                          selectedDate:
                                              branch.financialPeriodEndDate,
                                          onTap: () =>
                                              _pickBranchFinancialDate(
                                                  branchIndex,
                                                  isStartDate: false),
                                          icon: LucideIcons.calendarClock,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Accounting Period Picker (if periods loaded)
                                  if (_periods.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    _PeriodPicker(
                                      periods: _periods,
                                      selected: branch.selectedPeriod,
                                      onSelected: (p) => setState(
                                          () => branch.selectedPeriod = p),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Branch Softwares
                          Text(
                            'Branch Software Activations',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableSoftwares.map((software) {
                              final selected =
                                  (_branchSelectedSoftwares[branchIndex] ?? [])
                                      .contains(software);
                              return FilterChip(
                                label: Text(
                                  software,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                    color: selected
                                        ? (isDark ? Colors.black : Colors.white)
                                        : AppTheme.textPrimary(context),
                                  ),
                                ),
                                selected: selected,
                                selectedColor:
                                    isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                                backgroundColor: isDark ? FuturisticColors.bgInput : const Color(0xFFF1F5F9),
                                checkmarkColor: isDark ? Colors.black : Colors.white,
                                side: BorderSide(
                                  color: selected
                                      ? Colors.transparent
                                      : (isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                                ),
                                onSelected: (val) => _toggleBranchSoftwareSelection(
                                    branchIndex, software, val),
                              );
                            }).toList(),
                          ),

                          // Branch Device Activations
                          if ((_branchSelectedSoftwares[branchIndex] ?? [])
                              .isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ...(_branchSelectedSoftwares[branchIndex] ?? [])
                                .map((software) {
                              final devices =
                                  _branchSoftwareDevices[branchIndex]?[software] ??
                                      [];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? FuturisticColors.bgCard : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '$software Devices ($branchIndex)',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppTheme.textPrimary(context)),
                                        ),
                                        const Spacer(),
                                        TextButton.icon(
                                          onPressed: () => _addBranchDevice(
                                              branchIndex, software),
                                          icon: const Icon(LucideIcons.plus,
                                              size: 14),
                                          label: const Text('Add Device'),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                                          ),
                                        ),
                                      ],
                                    ),
                                    ...List.generate(devices.length, (dIdx) {
                                      final device = devices[dIdx];
                                      return Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    controller: device
                                                        .deviceLabelController,
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
                                                    decoration:
                                                        InputDecoration(
                                                      isDense: true,
                                                      labelText: 'Device Label',
                                                      labelStyle: TextStyle(
                                                        fontSize: 12,
                                                        color: isDark ? FuturisticColors.textMuted : const Color(0xFF64748B),
                                                      ),
                                                      filled: true,
                                                      fillColor: isDark ? FuturisticColors.bgCard : Colors.white,
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                        borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                        borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                        borderSide: BorderSide(color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488), width: 1.5),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextFormField(
                                                    controller:
                                                        device.userController,
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
                                                    decoration:
                                                        InputDecoration(
                                                      isDense: true,
                                                      labelText: 'User ID',
                                                      labelStyle: TextStyle(
                                                        fontSize: 12,
                                                        color: isDark ? FuturisticColors.textMuted : const Color(0xFF64748B),
                                                      ),
                                                      filled: true,
                                                      fillColor: isDark ? FuturisticColors.bgCard : Colors.white,
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                        borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                        borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                        borderSide: BorderSide(color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488), width: 1.5),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextFormField(
                                                    controller:
                                                        device.keyController,
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A)),
                                                    decoration:
                                                        InputDecoration(
                                                      isDense: true,
                                                      labelText: 'Key',
                                                      labelStyle: TextStyle(
                                                        fontSize: 12,
                                                        color: isDark ? FuturisticColors.textMuted : const Color(0xFF64748B),
                                                      ),
                                                      filled: true,
                                                      fillColor: isDark ? FuturisticColors.bgCard : Colors.white,
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                        borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                        borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                        borderSide: BorderSide(color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488), width: 1.5),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (devices.length > 1)
                                                  IconButton(
                                                    icon: const Icon(
                                                        LucideIcons.trash2,
                                                        size: 16),
                                                    color: Colors.red.shade400,
                                                    onPressed: () =>
                                                        _removeBranchDevice(
                                                            branchIndex,
                                                            software,
                                                            dIdx),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _buildDatePickerField(
                                                    label: 'Activation Date',
                                                    selectedDate:
                                                        device.activationDate,
                                                    onTap: () =>
                                                        _pickBranchActivationDate(
                                                            branchIndex,
                                                            software,
                                                            dIdx,
                                                            isExpiry: false),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: _buildDatePickerField(
                                                    label: 'Expiry Date',
                                                    selectedDate:
                                                        device.expiryDate,
                                                    onTap: () =>
                                                        _pickBranchActivationDate(
                                                            branchIndex,
                                                            software,
                                                            dIdx,
                                                            isExpiry: true),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }),
                          ],

                          const SizedBox(height: 16),

                          // Branch Staff Section
                          Row(
                            children: [
                              Text(
                                'Branch Staff Members',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    branch.staffList.add(_BranchStaff());
                                  });
                                },
                                icon: const Icon(LucideIcons.userPlus, size: 14),
                                label: const Text('Add Staff'),
                                style: TextButton.styleFrom(
                                  foregroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(branch.staffList.length, (staffIndex) {
                            final s = branch.staffList[staffIndex];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? FuturisticColors.bgCard : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: s.nameController,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        labelText: 'Staff Name',
                                        labelStyle: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? FuturisticColors.textMuted : const Color(0xFF64748B),
                                        ),
                                        filled: true,
                                        fillColor: isDark ? FuturisticColors.bgInput : Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: BorderSide(color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488), width: 1.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: s.phoneController,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                                      ),
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        labelText: 'Staff Phone',
                                        labelStyle: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? FuturisticColors.textMuted : const Color(0xFF64748B),
                                        ),
                                        filled: true,
                                        fillColor: isDark ? FuturisticColors.bgInput : Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: BorderSide(color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFCBD5E1)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: BorderSide(color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488), width: 1.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (branch.staffList.length > 1)
                                    IconButton(
                                      icon: const Icon(LucideIcons.trash2,
                                          size: 16),
                                      color: Colors.red.shade400,
                                      onPressed: () {
                                        setState(() {
                                          s.dispose();
                                          branch.staffList.removeAt(staffIndex);
                                        });
                                      },
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Navigation Tab Pill Button ──────────────────────────────────────────────
  Widget _buildTabPill({
    required int index,
    required String title,
    required IconData icon,
    int? countBadge,
  }) {
    final isSelected = _activeTabIndex == index;
    final isDark = AppTheme.isDark(context);

    return InkWell(
      onTap: () => setState(() => _activeTabIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? (isDark ? Colors.black : Colors.white) : AppTheme.textSecondary(context),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? (isDark ? Colors.black : Colors.white) : AppTheme.textSecondary(context),
              ),
            ),
            if (countBadge != null && countBadge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.25))
                      : (isDark ? FuturisticColors.neonCyan.withValues(alpha: 0.2) : const Color(0xFF0D9488).withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$countBadge',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CustomerProvider>(context);
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // ── Modern Top Navigation Header ────────────────────────────────
            Builder(
              builder: (context) {
                final isSmall = MediaQuery.of(context).size.width < 600;
                final isExtraSmall = MediaQuery.of(context).size.width < 400;

                return Container(
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBg(context),
                    border: Border(
                      bottom: BorderSide(color: AppTheme.cardBorderColor(context), width: 1.2),
                    ),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      // Icon Avatar
                      Container(
                        width: isSmall ? 36 : 42,
                        height: isSmall ? 36 : 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isEditing
                                ? (isDark
                                    ? [FuturisticColors.neonCyan.withValues(alpha: 0.8), FuturisticColors.neonCyan]
                                    : [const Color(0xFF0284C7), const Color(0xFF0369A1)])
                                : (isDark
                                    ? [FuturisticColors.neonTeal.withValues(alpha: 0.8), FuturisticColors.neonTeal]
                                    : [const Color(0xFF0D9488), const Color(0xFF0F766E)]),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isEditing ? LucideIcons.userCheck : LucideIcons.userPlus,
                          color: isDark ? Colors.black : Colors.white,
                          size: isSmall ? 18 : 22,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _isEditing
                                        ? 'Edit Customer: ${_nameController.text.isEmpty ? (widget.customer?.name ?? "") : _nameController.text}'
                                        : 'Create Customer',
                                    style: TextStyle(
                                      fontSize: isSmall ? 14 : 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary(context),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (!isExtraSmall)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _isEditing
                                          ? (isDark
                                              ? FuturisticColors.neonCyan.withValues(alpha: 0.15)
                                              : const Color(0xFF0284C7).withValues(alpha: 0.1))
                                          : (isDark
                                              ? FuturisticColors.neonTeal.withValues(alpha: 0.15)
                                              : const Color(0xFF0D9488).withValues(alpha: 0.1)),
                                      borderRadius: BorderRadius.circular(6),
                                      border: isDark
                                          ? Border.all(
                                              color: (_isEditing ? FuturisticColors.neonCyan : FuturisticColors.neonTeal)
                                                  .withValues(alpha: 0.3),
                                            )
                                          : null,
                                    ),
                                    child: Text(
                                      _isEditing ? 'EDITING' : 'NEW',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: _isEditing
                                            ? (isDark ? FuturisticColors.neonCyan : const Color(0xFF0284C7))
                                            : (isDark ? FuturisticColors.neonTeal : const Color(0xFF0D9488)),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (!isSmall) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Configure profile details, ZATCA tax numbers, software keys, and branches',
                                style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Auto-fill from text/file
                      if (isSmall)
                        IconButton(
                          tooltip: 'Auto-fill from Text / File',
                          onPressed: () => _showAutoFillDialog(),
                          icon: Icon(
                            LucideIcons.fileSpreadsheet,
                            size: 20,
                            color: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                          ),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () => _showAutoFillDialog(),
                          icon: const Icon(LucideIcons.fileSpreadsheet, size: 15),
                          label: const Text('Auto-Fill (.txt)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                            side: BorderSide(
                              color: isDark
                                  ? FuturisticColors.neonCyan.withValues(alpha: 0.5)
                                  : const Color(0xFF0D9488),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      const SizedBox(width: 6),
                      // Actions: Cancel & Save
                      if (isSmall)
                        IconButton(
                          tooltip: 'Discard',
                          onPressed: _closeScreen,
                          icon: Icon(LucideIcons.x, size: 20, color: AppTheme.textSecondary(context)),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _closeScreen,
                          icon: const Icon(LucideIcons.x, size: 16),
                          label: const Text('Discard'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary(context),
                            side: BorderSide(color: AppTheme.cardBorderColor(context)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: provider.isLoading ? null : _saveCustomer,
                        icon: provider.isLoading
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.black : Colors.white),
                                ),
                              )
                            : const Icon(LucideIcons.check, size: 16),
                        label: Text(
                          provider.isLoading
                              ? 'Saving...'
                              : (isSmall ? 'Save' : (_isEditing ? 'Save Changes' : 'Create Customer')),
                          style: TextStyle(fontSize: isSmall ? 12 : 13, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          elevation: isDark ? 0 : 1,
                          padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // ── Pill Tab Selector Bar ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.inputBg(context),
                border: Border(
                  bottom: BorderSide(color: AppTheme.cardBorderColor(context), width: 1),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabPill(
                       index: 0,
                      title: 'General & Contact',
                      icon: LucideIcons.user,
                      countBadge: _mainCustomerStaff.length,
                    ),
                    const SizedBox(width: 6),
                    _buildTabPill(
                      index: 1,
                      title: 'Address & Location',
                      icon: LucideIcons.mapPin,
                    ),
                    const SizedBox(width: 6),
                    _buildTabPill(
                      index: 2,
                      title: 'Tax & ZATCA',
                      icon: LucideIcons.shieldCheck,
                    ),
                    const SizedBox(width: 6),
                    _buildTabPill(
                      index: 3,
                      title: 'Software & Licenses',
                      icon: LucideIcons.laptop,
                      countBadge: _selectedSoftwareNames.length,
                    ),
                    const SizedBox(width: 6),
                    _buildTabPill(
                      index: 4,
                      title: 'Branches & Sites',
                      icon: LucideIcons.gitBranch,
                      countBadge: _branches.length,
                    ),
                  ],
                ),
              ),
            ),

            // ── Main Body with IndexedStack ──────────────────────────────────
            Expanded(
              child: IndexedStack(
                index: _activeTabIndex,
                children: [
                  _buildGeneralTab(),
                  _buildAddressTab(),
                  _buildTaxAndZatcaTab(),
                  _buildSoftwareTab(),
                  _buildBranchesTab(),
                ],
              ),
            ),

            // ── Sticky Footer Navigation ────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg(context),
                border: Border(
                  top: BorderSide(color: AppTheme.cardBorderColor(context), width: 1.2),
                ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
              ),
              child: Builder(
                builder: (context) {
                  final isSmall = MediaQuery.of(context).size.width < 600;

                  return Row(
                    children: [
                      // Step Indicator
                      Text(
                        'Step ${_activeTabIndex + 1}/5',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                      if (!isSmall) ...[
                        const SizedBox(width: 8),
                        Text(
                          _activeTabIndex == 0
                              ? 'General & Contact Info'
                              : _activeTabIndex == 1
                                  ? 'Address & National Spec'
                                  : _activeTabIndex == 2
                                      ? 'Tax, ZATCA & Financial'
                                      : _activeTabIndex == 3
                                          ? 'Software & Activations'
                                          : 'Branches & Outlets',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted(context),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (_activeTabIndex > 0) ...[
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _activeTabIndex = _activeTabIndex - 1),
                          icon: const Icon(LucideIcons.chevronLeft, size: 16),
                          label: Text(isSmall ? 'Prev' : 'Previous'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary(context),
                            side: BorderSide(color: AppTheme.cardBorderColor(context)),
                            padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (_activeTabIndex < 4) ...[
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _activeTabIndex = _activeTabIndex + 1),
                          icon: const Icon(LucideIcons.chevronRight, size: 16),
                          label: Text(isSmall ? 'Next' : 'Next Step'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? FuturisticColors.bgElevated : const Color(0xFF0F172A),
                            foregroundColor: isDark ? FuturisticColors.neonCyan : Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: provider.isLoading ? null : _saveCustomer,
                          icon: const Icon(LucideIcons.check, size: 16),
                          label: Text(
                            provider.isLoading
                                ? 'Saving...'
                                : (_isEditing ? 'Save' : 'Create'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? FuturisticColors.neonCyan : const Color(0xFF0D9488),
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            elevation: isDark ? 0 : 1,
                            padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Period Picker Dropdown Component ──────────────────────────────────────────
class _PeriodPicker extends StatefulWidget {
  const _PeriodPicker({
    required this.periods,
    required this.selected,
    required this.onSelected,
  });

  final List<_Period> periods;
  final _Period? selected;
  final ValueChanged<_Period?> onSelected;

  @override
  State<_PeriodPicker> createState() => _PeriodPickerState();
}

class _PeriodPickerState extends State<_PeriodPicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _expandAnim =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  late final Animation<double> _rotateAnim =
      Tween<double>(begin: 0, end: 0.5).animate(_expandAnim);

  bool _open = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  void _select(_Period? p) {
    widget.onSelected(p);
    setState(() => _open = false);
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final accent = isDark ? FuturisticColors.neonViolet : const Color(0xFF6366F1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Trigger
        GestureDetector(
          onTap: _toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: _open ? accent : (isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0)),
                width: _open ? 1.8 : 1.2,
              ),
              borderRadius: BorderRadius.circular(10),
              color: isDark ? FuturisticColors.bgInput : const Color(0xFFF8FAFC),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.calendarRange,
                  size: 18,
                  color: isDark ? FuturisticColors.textMuted : const Color(0xFF64748B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.selected?.name ?? 'Select Period Section',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: widget.selected != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: widget.selected != null
                          ? (isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A))
                          : (isDark ? FuturisticColors.textMuted : Colors.grey.shade400),
                    ),
                  ),
                ),
                if (widget.selected != null)
                  GestureDetector(
                    onTap: () => _select(null),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: isDark ? FuturisticColors.textMuted : Colors.grey.shade500,
                      ),
                    ),
                  ),
                RotationTransition(
                  turns: _rotateAnim,
                  child: Icon(
                    LucideIcons.chevronDown,
                    size: 18,
                    color: isDark ? FuturisticColors.textMuted : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded Dropdown List
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1,
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: isDark ? FuturisticColors.bgCard : Colors.white,
              border: Border.all(
                color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0),
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.periods.length + 1,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark ? FuturisticColors.borderSubtle : const Color(0xFFF1F5F9),
                ),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return InkWell(
                      onTap: () => _select(null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.minusCircle,
                              size: 16,
                              color: isDark ? FuturisticColors.textMuted : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'None / Clear selection',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? FuturisticColors.textMuted : Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final p = widget.periods[i - 1];
                  final isSelected = p.id == widget.selected?.id;

                  return InkWell(
                    onTap: () => _select(p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      color: isSelected
                          ? accent.withValues(alpha: isDark ? 0.15 : 0.08)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? accent
                                        : (isDark ? FuturisticColors.textPrimary : const Color(0xFF1E293B)),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.range,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? FuturisticColors.textSecondary : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(LucideIcons.check, size: 16, color: accent),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Selected Period Range Badge
        if (widget.selected != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: isDark ? 0.35 : 0.25)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.calendarCheck, size: 15, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Active Period: ${widget.selected!.name} (${widget.selected!.range})',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}