import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:entryon/views/createCustomerScreen.dart';
import 'package:entryon/views/createSupplierScreen.dart';
import 'package:entryon/views/qr_scanner_screen.dart';
import 'package:entryon/utils/zatca_qr_parser.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/customer_model.dart';
import '../models/supplier_model.dart';
import '../models/purchase_entry_model.dart';
import '../providers/customer_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/purchase_entry_provider.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

// ── Lightweight period model (used only inside this screen) ──────────────────
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

  /// e.g.  "Jan 2026 – Mar 2026"
  String get range =>
      '${DateFormat('MMM yyyy').format(startDate)} – '
      '${DateFormat('MMM yyyy').format(endDate)}';

  /// Full label shown in dropdown
  String get label => '$name  ($range)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class PurchaseEntryScreen extends StatefulWidget {
  final PurchaseInvoice? invoice;
  const PurchaseEntryScreen({super.key, this.invoice});

  @override
  State<PurchaseEntryScreen> createState() => _PurchaseEntryScreenState();
}

class _PurchaseEntryScreenState extends State<PurchaseEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────────────────────
  final _invoiceNoController = TextEditingController();
  final _invoiceNoFocusNode = FocusNode();
  final _entryActionFocusNode = FocusNode();
  final _amountExVatController = TextEditingController();
  final _amountExVatFocusNode = FocusNode();
  final _vatRateController = TextEditingController(text: '15');
  final _vatRateFocusNode = FocusNode();
  final _vatAmountController = TextEditingController();
  final _vatAmountFocusNode = FocusNode();
  final _totalIncVatController = TextEditingController();
  final _totalIncVatFocusNode = FocusNode();
  final _customerSearchController = TextEditingController();
  final _customerSearchFocusNode = FocusNode();
  final _supplierSearchController = TextEditingController();
  final _supplierSearchFocusNode = FocusNode();
  final _periodSectionFocusNode = FocusNode();
  final _invoiceDateFocusNode = FocusNode();
  final _directScanController = TextEditingController();
  final _directScanFocusNode = FocusNode();

  // ── State ─────────────────────────────────────────────────────────────────
  Customer? _selectedCustomer;
  Supplier? _selectedSupplier;
  DateTime? _invoiceDate;
  String _sortBy = 'date_desc';

  List<Customer> _filteredCustomers = [];
  List<Supplier> _filteredSuppliers = [];

  bool _showCustomerDropdown = false;
  bool _showSupplierDropdown = false;
  bool _isSaving = false;
  int? _editingIndex;
  Timer? _autoSaveTimer;
  String? _directScanError;
  bool _initialLoadDone = false;
  bool _requestedInitialDirectScanFocus = false;
  String? _loadError;
  static const String _draftKey = 'purchase_entry_screen_draft_v1';

  void _clearEntryFields() {
    _editingIndex = null;
    _amountExVatController.clear();
    _vatAmountController.clear();
    _totalIncVatController.clear();
    _vatRateController.text = '15';
    _invoiceNoController.clear();
    _invoiceDate = null;
    _selectedSupplier = null;
    _supplierSearchController.clear();
    _directScanController.clear();
    _directScanError = null;
    _showSupplierDropdown = false;
  }

  List<PurchaseItem> _getSortedItems(List<PurchaseItem> items) {
    final sorted = List<PurchaseItem>.from(items);
    sorted.sort((a, b) {
      switch (_sortBy) {
        case 'date_asc':
          return a.date.compareTo(b.date);
        case 'date_desc':
          return b.date.compareTo(a.date);
        case 'supplier_asc':
          return a.supplierName.toLowerCase().compareTo(
            b.supplierName.toLowerCase(),
          );
        case 'supplier_desc':
          return b.supplierName.toLowerCase().compareTo(
            a.supplierName.toLowerCase(),
          );
        case 'amount_asc':
          return a.totalIncVat.compareTo(b.totalIncVat);
        case 'amount_desc':
          return b.totalIncVat.compareTo(a.totalIncVat);
        default:
          return b.id.compareTo(a.id);
      }
    });
    return sorted;
  }

  void _startEditEntry(int index) {
    final provider = context.read<PurchaseEntryProvider>();
    if (index < 0 || index >= provider.items.length) return;
    final item = provider.items[index];

    setState(() {
      _editingIndex = index;
      _invoiceNoController.text = item.invoiceNo;
      _invoiceDate = item.date;
      _amountExVatController.text = item.amountExVat.toStringAsFixed(2);
      _vatAmountController.text = item.vatAmount.toStringAsFixed(2);
      _totalIncVatController.text = item.totalIncVat.toStringAsFixed(2);
      _vatRateController.text = item.vatRate.toStringAsFixed(0);

      // Try to match supplier from provider; if not found, create a minimal instance
      final suppliers = context.read<SupplierProvider>().suppliers;
      try {
        _selectedSupplier = suppliers.firstWhere(
          (s) => s.id == item.supplierId,
        );
      } catch (_) {
        _selectedSupplier = Supplier(
          id: item.supplierId,
          name: item.supplierName,
          vatNumber: item.vatNumber,
          phone: '',
        );
      }
    });
  }

  // ── Period sections from Firestore ────────────────────────────────────────
  List<_Period> _periods = [];
  bool _periodsLoading = true;
  _Period? _selectedPeriod;

  bool get _isEditMode => widget.invoice != null;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleShortcutKey);
    _invoiceNoController.addListener(_scheduleAutoSave);
    _amountExVatController.addListener(_scheduleAutoSave);
    _vatRateController.addListener(_scheduleAutoSave);
    _vatAmountController.addListener(_scheduleAutoSave);
    _totalIncVatController.addListener(_scheduleAutoSave);
    _loadEverything();
  }

  bool _handleShortcutKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        (event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.numpadEnter) ||
        !HardwareKeyboard.instance.isControlPressed ||
        !_initialLoadDone ||
        _isSaving ||
        ModalRoute.of(context)?.isCurrent != true) {
      return false;
    }

    _addEntry();
    return true;
  }

  Future<void> _loadEverything() async {
    try {
      await Future.wait([
        _fetchPeriods(),
        context.read<CustomerProvider>().fetchCustomers(),
        context.read<SupplierProvider>().ensureSuppliersLoaded(),
      ]);

      if (!mounted) return;

      if (_isEditMode) {
        _populateFromInvoice();
      } else {
        await _restoreDraft();
      }

      setState(() {
        _loadError = null;
        _initialLoadDone = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Unable to load purchase entry details.';
        _initialLoadDone = true;
      });
    }
  }

  void _scheduleAutoSave() {
    if (_isEditMode || _isSaving) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 700), () async {
      await _saveDraft();
    });
  }

  Future<void> _saveDraft() async {
    if (_isEditMode || _isSaving) return;

    final provider = context.read<PurchaseEntryProvider>();
    final draft = {
      'invoiceNo': _invoiceNoController.text.trim(),
      'invoiceDate': _invoiceDate?.toIso8601String(),
      'customerId': _selectedCustomer?.id ?? '',
      'customerName': _selectedCustomer?.name ?? '',
      'supplierId': _selectedSupplier?.id ?? '',
      'supplierName': _selectedSupplier?.name ?? '',
      'amountExVat': _amountExVatController.text,
      'vatRate': _vatRateController.text,
      'vatAmount': _vatAmountController.text,
      'totalIncVat': _totalIncVatController.text,
      'periodSectionId': _selectedPeriod?.id ?? '',
      'items': provider.items
          .map(
            (item) => {
              'id': item.id,
              'date': item.date.toIso8601String(),
              'invoiceNo': item.invoiceNo,
              'supplierName': item.supplierName,
              'vatNumber': item.vatNumber,
              'supplierId': item.supplierId,
              'amountExVat': item.amountExVat,
              'vatRate': item.vatRate,
              'vatAmount': item.vatAmount,
              'totalIncVat': item.totalIncVat,
              'createdAt': item.createdAt.toIso8601String(),
            },
          )
          .toList(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(draft));
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> _restoreDraft() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      if (!mounted) return;

      final customerId = (decoded['customerId'] as String?) ?? '';
      final supplierId = (decoded['supplierId'] as String?) ?? '';
      final periodSectionId = (decoded['periodSectionId'] as String?) ?? '';
      final itemsData = (decoded['items'] as List?) ?? const [];

      final customerProvider = context.read<CustomerProvider>();
      final supplierProvider = context.read<SupplierProvider>();
      final provider = context.read<PurchaseEntryProvider>();

      Customer? restoredCustomer;
      if (customerId.isNotEmpty) {
        try {
          restoredCustomer = customerProvider.customers.firstWhere(
            (c) => c.id == customerId,
          );
        } catch (_) {}
      }

      Supplier? restoredSupplier;
      if (supplierId.isNotEmpty) {
        try {
          restoredSupplier = supplierProvider.suppliers.firstWhere(
            (s) => s.id == supplierId,
          );
        } catch (_) {}
      }

      provider.clearItems();
      for (final item in itemsData) {
        final itemMap = Map<String, dynamic>.from(item as Map);
        final purchaseItem = PurchaseItem.fromMap(itemMap);
        provider.addItem(
          date: purchaseItem.date,
          invoiceNo: purchaseItem.invoiceNo,
          supplierName: purchaseItem.supplierName,
          supplierId: purchaseItem.supplierId,
          vatNumber: purchaseItem.vatNumber,
          amountExVat: purchaseItem.amountExVat,
          vatRate: purchaseItem.vatRate,
          vatAmount: purchaseItem.vatAmount,
          totalIncVat: purchaseItem.totalIncVat,
        );
      }

      final restoredDate = decoded['invoiceDate'] as String?;
      setState(() {
        _selectedCustomer = restoredCustomer;
        _selectedSupplier = restoredSupplier;
        _invoiceDate = restoredDate != null && restoredDate.isNotEmpty
            ? DateTime.tryParse(restoredDate)
            : null;
        _invoiceNoController.text = (decoded['invoiceNo'] as String?) ?? '';
        _amountExVatController.text = (decoded['amountExVat'] as String?) ?? '';
        _vatRateController.text = (decoded['vatRate'] as String?) ?? '15';
        _vatAmountController.text = (decoded['vatAmount'] as String?) ?? '';
        _totalIncVatController.text = (decoded['totalIncVat'] as String?) ?? '';
        if (periodSectionId.isNotEmpty) {
          _matchPeriod(periodSectionId);
        }
      });
    } catch (_) {
      await _clearDraft();
    }
  }

  // ── Fetch period sections from Firestore ──────────────────────────────────
  Future<void> _fetchPeriods() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('period_sections')
          .orderBy('sectionNumber')
          .get();

      setState(() {
        _periods = snap.docs.map((doc) {
          final data = doc.data();
          DateTime parse(dynamic d) =>
              d is Timestamp ? d.toDate() : DateTime.parse(d.toString());
          return _Period(
            id: doc.id,
            name: data['name'] ?? '',
            startDate: parse(data['startDate']),
            endDate: parse(data['endDate']),
          );
        }).toList();
        _periodsLoading = false;
      });

      // If edit mode and period already set, match the object
      if (_isEditMode && widget.invoice?.periodSectionId != null) {
        _matchPeriod(widget.invoice!.periodSectionId);
      }
    } catch (e) {
      setState(() => _periodsLoading = false);
      debugPrint('Error fetching periods: $e');
    }
  }

  /// Find and select a period by its ID (used in edit mode)
  void _matchPeriod(String periodId) {
    try {
      final match = _periods.firstWhere((p) => p.id == periodId);
      setState(() => _selectedPeriod = match);
    } catch (_) {
      // Period no longer exists — leave unset
    }
  }

  // ── Populate edit mode ────────────────────────────────────────────────────
  void _populateFromInvoice() {
    final inv = widget.invoice!;
    final provider = context.read<PurchaseEntryProvider>();

    provider.clearItems();
    for (final item in inv.items) {
      provider.addItem(
        date: item.date,
        invoiceNo: item.invoiceNo,
        supplierName: item.supplierName,
        supplierId: item.supplierId,
        vatNumber: item.vatNumber,
        amountExVat: item.amountExVat,
        vatRate: item.vatRate,
        vatAmount: item.vatAmount,
        totalIncVat: item.totalIncVat,
      );
    }

    _invoiceNoController.text = inv.invoiceNo;
    _invoiceDate = inv.invoiceDate;

    // Try to match period (periods may or may not be loaded yet)
    if (_periods.isNotEmpty) {
      _matchPeriod(inv.periodSectionId);
    }

    final customers = context.read<CustomerProvider>().customers;
    try {
      _selectedCustomer = customers.firstWhere((c) => c.id == inv.customerId);
    } catch (_) {
      _selectedCustomer = Customer(
        id: inv.customerId,
        name: inv.customerName,
        phone: '',
        address: '',
        taxNumber: '',
        zatcaEnabled: false,
      );
    }

    final suppliers = context.read<SupplierProvider>().suppliers;
    try {
      _selectedSupplier = suppliers.firstWhere((s) => s.id == inv.supplierId);
    } catch (_) {
      _selectedSupplier = Supplier(
        id: inv.supplierId,
        name: inv.supplierName,
        vatNumber: '',
        phone: '',
        address: '',
      );
    }

    _clearEntryAmountFields();

    setState(() {});
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleShortcutKey);
    _autoSaveTimer?.cancel();
    _invoiceNoController.removeListener(_scheduleAutoSave);
    _amountExVatController.removeListener(_scheduleAutoSave);
    _vatRateController.removeListener(_scheduleAutoSave);
    _vatAmountController.removeListener(_scheduleAutoSave);
    _totalIncVatController.removeListener(_scheduleAutoSave);
    _invoiceNoController.dispose();
    _invoiceNoFocusNode.dispose();
    _entryActionFocusNode.dispose();
    _amountExVatController.dispose();
    _amountExVatFocusNode.dispose();
    _vatRateController.dispose();
    _vatRateFocusNode.dispose();
    _vatAmountController.dispose();
    _vatAmountFocusNode.dispose();
    _totalIncVatController.dispose();
    _totalIncVatFocusNode.dispose();
    _customerSearchController.dispose();
    _customerSearchFocusNode.dispose();
    _supplierSearchController.dispose();
    _supplierSearchFocusNode.dispose();
    _periodSectionFocusNode.dispose();
    _invoiceDateFocusNode.dispose();
    _directScanController.dispose();
    _directScanFocusNode.dispose();
    super.dispose();
  }

  // ── Customer search ───────────────────────────────────────────────────────
  void _filterCustomers(String query) {
    final customers = context.read<CustomerProvider>().customers;
    setState(() {
      _filteredCustomers = query.isEmpty
          ? customers
          : customers
                .where(
                  (c) =>
                      c.name.toLowerCase().contains(query.toLowerCase()) ||
                      c.phone.contains(query),
                )
                .toList();
      _showCustomerDropdown = true;
    });
  }

  void _selectCustomer(Customer c) {
    setState(() {
      _selectedCustomer = c;
      _selectedSupplier = null;
      _showCustomerDropdown = false;
      _customerSearchController.clear();
    });
    _scheduleAutoSave();
  }

  // ── Supplier search ───────────────────────────────────────────────────────
  void _filterSuppliers(String query) {
    final suppliers = context.read<SupplierProvider>().suppliers;
    setState(() {
      _filteredSuppliers = query.isEmpty
          ? suppliers
          : suppliers
                .where(
                  (s) =>
                      s.name.toLowerCase().contains(query.toLowerCase()) ||
                      s.phone.contains(query),
                )
                .toList();
      _showSupplierDropdown = true;
    });
  }

  void _selectSupplier(Supplier s) {
    setState(() {
      _selectedSupplier = s;
      _showSupplierDropdown = false;
      _supplierSearchController.clear();
    });
    _scheduleAutoSave();
  }

  // ── VAT calculations ──────────────────────────────────────────────────────
  void _calculateFromAmountExVat() {
    final amount = double.tryParse(_amountExVatController.text) ?? 0;
    final rate = double.tryParse(_vatRateController.text) ?? 0;
    setState(() {
      _vatAmountController.text = (amount * rate / 100).toStringAsFixed(2);
      _totalIncVatController.text = (amount + amount * rate / 100)
          .toStringAsFixed(2);
    });
  }

  void _calculateFromVatAmount() {
    final vat = double.tryParse(_vatAmountController.text) ?? 0;
    final rate = double.tryParse(_vatRateController.text) ?? 0;
    if (rate == 0) return;
    final amount = vat / (rate / 100);
    setState(() {
      _amountExVatController.text = amount.toStringAsFixed(2);
      _totalIncVatController.text = (amount + vat).toStringAsFixed(2);
    });
  }

  void _calculateFromTotal() {
    final total = double.tryParse(_totalIncVatController.text) ?? 0;
    final rate = double.tryParse(_vatRateController.text) ?? 0;
    if (rate == 0) return;
    final amount = total / (1 + rate / 100);
    setState(() {
      _amountExVatController.text = amount.toStringAsFixed(2);
      _vatAmountController.text = (total - amount).toStringAsFixed(2);
    });
  }

  // ── Date picker ───────────────────────────────────────────────────────────
  Future<void> _pickInvoiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _invoiceDate = picked);
      _scheduleAutoSave();
      _amountExVatFocusNode.requestFocus();
    }
  }

  // ── Add entry ─────────────────────────────────────────────────────────────
  Future<void> _addEntry() async {
    final provider = context.read<PurchaseEntryProvider>();

    if (!_validateInvoiceForm()) return;

    if (!await _checkInvoiceNumberUnique(
      supplierName: _selectedSupplier!.name,
    )) {
      return;
    }

    final amountExVat = double.tryParse(_amountExVatController.text) ?? 0;

    if (_editingIndex != null) {
      final success = provider.updateItem(
        _editingIndex!,
        date: _invoiceDate!,
        invoiceNo: _invoiceNoController.text.trim(),
        supplierName: _selectedSupplier!.name,
        supplierId: _selectedSupplier!.id!,
        vatNumber: _selectedSupplier!.vatNumber,
        amountExVat: amountExVat,
        vatRate: double.tryParse(_vatRateController.text) ?? 0,
        vatAmount: double.tryParse(_vatAmountController.text) ?? 0,
        totalIncVat: double.tryParse(_totalIncVatController.text) ?? 0,
      );
      if (!success) {
        _showMsg(
          'Invoice number duplicates another entry for this supplier',
          Colors.orange,
        );
        return;
      }
      setState(_clearEntryFields);
      _scheduleAutoSave();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _directScanFocusNode.canRequestFocus) {
          FocusScope.of(context).requestFocus(_directScanFocusNode);
        }
      });
      _showMsg('Entry updated', Colors.green);
      return;
    }

    final added = provider.addItem(
      date: _invoiceDate!,
      invoiceNo: _invoiceNoController.text.trim(),
      supplierName: _selectedSupplier!.name,
      supplierId: _selectedSupplier!.id!,
      vatNumber: _selectedSupplier!.vatNumber,
      amountExVat: amountExVat,
      vatRate: double.tryParse(_vatRateController.text) ?? 0,
      vatAmount: double.tryParse(_vatAmountController.text) ?? 0,
      totalIncVat: double.tryParse(_totalIncVatController.text) ?? 0,
    );

    if (!added) {
      _showMsg(
        'This invoice number is already added for this supplier',
        Colors.orange,
      );
      return;
    }

    setState(_clearEntryFields);
    _scheduleAutoSave();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _directScanFocusNode.canRequestFocus) {
        FocusScope.of(context).requestFocus(_directScanFocusNode);
      }
    });
    _showMsg('Entry added', Colors.green);
  }

  // ── Save (create or update) ───────────────────────────────────────────────
  Future<void> _saveInvoice() async {
    // Prevent double-tap submission
    if (_isSaving) return;

    final provider = context.read<PurchaseEntryProvider>();

    if (provider.items.isEmpty) {
      _showMsg('Please add at least one entry', Colors.orange);
      return;
    }
    if (_selectedCustomer == null) {
      _showMsg('Please select a customer', Colors.orange);
      return;
    }

    final lastItem = provider.items.last;
    final existingInvoice = widget.invoice;
    final invoiceNo = _invoiceNoController.text.trim().isNotEmpty
        ? _invoiceNoController.text.trim()
        : (existingInvoice?.invoiceNo.isNotEmpty ?? false)
        ? existingInvoice!.invoiceNo
        : lastItem.invoiceNo;
    final invoiceDate =
        _invoiceDate ?? existingInvoice?.invoiceDate ?? lastItem.date;
    final existingSupplierId = existingInvoice?.supplierId;
    final supplierId =
        _selectedSupplier?.id ??
        (existingSupplierId != null && existingSupplierId.isNotEmpty
            ? existingSupplierId
            : lastItem.supplierId);
    final existingSupplierName = existingInvoice?.supplierName;
    final supplierName =
        _selectedSupplier?.name ??
        (existingSupplierName != null && existingSupplierName.isNotEmpty
            ? existingSupplierName
            : lastItem.supplierName);

    setState(() => _isSaving = true);
    try {
      if (!await _checkInvoiceNumberUnique(
        invoiceNo: invoiceNo,
        supplierName: supplierName,
      )) {
        return;
      }

      final bool success;
      if (_isEditMode) {
        success = await provider.updateInvoice(
          invoiceId: existingInvoice!.id,
          customerId: _selectedCustomer!.id,
          customerName: _selectedCustomer!.name,
          customerVatNumber: _selectedCustomer!.taxNumber,
          supplierId: supplierId,
          supplierName: supplierName,
          invoiceNo: invoiceNo,
          invoiceDate: invoiceDate,
          items: provider.items,
          periodSectionId: _selectedPeriod?.id,
          periodSectionName: _selectedPeriod?.name,
        );
        if (success && mounted) {
          _showMsg('Invoice updated successfully!', Colors.green);
          provider.clearItems();
          await _clearDraft();
          if (mounted) Navigator.pop(context, true);
        }
      } else {
        success = await provider.saveInvoice(
          customerId: _selectedCustomer!.id,
          customerName: _selectedCustomer!.name,
          customerVatNumber: _selectedCustomer!.taxNumber,
          supplierId: supplierId,
          supplierName: supplierName,
          invoiceNo: invoiceNo,
          invoiceDate: invoiceDate,
          periodSectionId: _selectedPeriod?.id,
          periodSectionName: _selectedPeriod?.name,
        );
        if (success && mounted) {
          _showMsg('Invoice saved successfully!', Colors.green);
          await _clearDraft();
          if (mounted) _resetForm();
        }
      }

      if (!success && mounted) {
        _showMsg(provider.errorMessage ?? 'Error saving invoice', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    _invoiceNoController.clear();
    _clearEntryAmountFields();
    _customerSearchController.clear();
    _supplierSearchController.clear();
    setState(() {
      _selectedCustomer = null;
      _selectedSupplier = null;
      _invoiceDate = null;
      _selectedPeriod = null;
    });
    context.read<PurchaseEntryProvider>().clearItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _directScanFocusNode.canRequestFocus) {
        FocusScope.of(context).requestFocus(_directScanFocusNode);
      }
    });
  }

  void _clearEntryAmountFields() {
    _amountExVatController.clear();
    _vatAmountController.clear();
    _totalIncVatController.clear();
    _vatRateController.text = '15';
  }

  bool _validateInvoiceForm() {
    if (_selectedCustomer == null) {
      _showMsg('Please select a customer', Colors.orange);
      return false;
    }
    if (_selectedSupplier == null) {
      _showMsg('Please select a supplier', Colors.orange);
      return false;
    }
    if (_invoiceNoController.text.trim().isEmpty) {
      _showMsg('Please enter invoice number', Colors.orange);
      return false;
    }
    if (_invoiceDate == null) {
      _showMsg('Please select invoice date', Colors.orange);
      return false;
    }
    return true;
  }

  Future<bool> _checkInvoiceNumberUnique({
    String? invoiceNo,
    required String supplierName,
  }) async {
    final normalizedInvoiceNo = (invoiceNo ?? _invoiceNoController.text).trim();
    if (normalizedInvoiceNo.isEmpty) return false;

    final provider = context.read<PurchaseEntryProvider>();
    final exists = await provider.invoiceNumberExists(
      normalizedInvoiceNo,
      supplierName: supplierName,
      excludeInvoiceId: _isEditMode ? widget.invoice!.id : null,
    );

    if (provider.errorMessage != null) {
      _showMsg(provider.errorMessage!, Colors.red);
      return false;
    }

    if (exists) {
      _showMsg(
        'Invoice number "$normalizedInvoiceNo" already exists for "$supplierName".',
        Colors.orange,
      );
      return false;
    }
    return true;
  }

  // ── Bulk import helpers ─────────────────────────────────────────────────
  void _openBulkImportDialog() {
    final isDark = AppTheme.isDark(context);
    final pasteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.cardBorderColor(ctx)),
        ),
        title: Text(
          'Bulk Import',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(ctx),
          ),
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paste CSV/text (columns: invoiceNo,date(dd/MM/yyyy),supplierId|supplierName,amountExVat,vatRate,total[,vatNumber])',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary(ctx),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pasteController,
                  minLines: 6,
                  maxLines: 14,
                  style: TextStyle(color: AppTheme.textPrimary(ctx)),
                  decoration: InputDecoration(
                    hintText: 'Paste CSV lines here',
                    hintStyle: TextStyle(color: AppTheme.textMuted(ctx)),
                    filled: true,
                    fillColor: AppTheme.inputBg(ctx),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppTheme.cardBorderColor(ctx),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppTheme.cardBorderColor(ctx),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? FuturisticColors.neonCyan : Colors.teal,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _processBulkText(pasteController.text);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? FuturisticColors.neonCyan
                            : const Color(0xFF4F8EF7),
                        foregroundColor: isDark ? Colors.black : Colors.white,
                      ),
                      child: const Text('Import Paste'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _pickCsvFile();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? FuturisticColors.neonTeal
                            : Colors.teal,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                      ),
                      child: const Text('Upload CSV'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickCsvFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final content = file.bytes != null
          ? utf8.decode(file.bytes!)
          : await File(file.path!).readAsString();
      await _processBulkText(content);
    } catch (e) {
      _showMsg('Error reading file: $e', Colors.red);
    }
  }

  Future<void> _processBulkText(String text) async {
    if (text.trim().isEmpty) {
      _showMsg('No data provided', Colors.orange);
      return;
    }

    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    int added = 0;
    int skipped = 0;
    final errors = <String>[];

    final supplierList = context.read<SupplierProvider>().suppliers;
    final provider = context.read<PurchaseEntryProvider>();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final cols = line.split(',').map((c) => c.trim()).toList();
      if (cols.length < 6) {
        errors.add('Line ${i + 1}: not enough columns');
        skipped++;
        continue;
      }

      final invoiceNo = cols[0].trim();
      final dateStr = cols[1].trim();
      final supplierKey = cols[2].trim();
      final amountStr = cols[3].trim();
      final vatRateStr = cols[4].trim();
      final totalStr = cols[5].trim();
      final vatNumber = cols.length > 6 ? cols[6].trim() : '';

      // Parse date
      DateTime date;
      try {
        final parts = dateStr.split('/');
        if (parts.length != 3) throw 'Invalid date';
        date = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      } catch (e) {
        errors.add('Line ${i + 1}: invalid date "$dateStr"');
        skipped++;
        continue;
      }

      final amount =
          double.tryParse(amountStr.replaceAll(',', '')) ?? double.nan;
      final vatRate = double.tryParse(vatRateStr.replaceAll(',', '')) ?? 0;
      final total = double.tryParse(totalStr.replaceAll(',', '')) ?? double.nan;
      if (amount.isNaN) {
        errors.add('Line ${i + 1}: invalid amount "$amountStr"');
        skipped++;
        continue;
      }

      // Resolve supplier
      Supplier? supplier;
      supplier = supplierList.firstWhere(
        (s) =>
            s.id == supplierKey ||
            s.name.toLowerCase() == supplierKey.toLowerCase(),
        orElse: () =>
            Supplier(id: '', name: '', vatNumber: '', phone: '', address: ''),
      );
      if (supplier.id!.isEmpty) {
        errors.add('Line ${i + 1}: supplier "$supplierKey" not found');
        skipped++;
        continue;
      }

      // Check global duplicate in Firestore
      final existsGlobal = await provider.invoiceNumberExists(
        invoiceNo,
        supplierName: supplier.name,
      );
      if (existsGlobal) {
        errors.add(
          'Line ${i + 1}: invoiceNo "$invoiceNo" already exists for "${supplier.name}" in database',
        );
        skipped++;
        continue;
      }

      // Add to local provider (addItem returns false if local duplicate)
      final addedLocal = provider.addItem(
        date: date,
        invoiceNo: invoiceNo,
        supplierName: supplier.name,
        supplierId: supplier.id ?? '',
        vatNumber: vatNumber,
        amountExVat: amount,
        vatRate: vatRate,
        vatAmount: (total - amount).isNaN
            ? (amount * vatRate / 100)
            : (total - amount),
        totalIncVat: total.isNaN ? (amount + amount * vatRate / 100) : total,
      );

      if (!addedLocal) {
        errors.add(
          'Line ${i + 1}: duplicate invoiceNo "$invoiceNo" for "${supplier.name}" in current session',
        );
        skipped++;
        continue;
      }

      added++;
    }

    final msg = 'Bulk import finished: $added added, $skipped skipped.';
    _showMsg(msg, errors.isEmpty ? Colors.green : Colors.orange);
    if (errors.isNotEmpty) {
      // Show detailed errors in dialog
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Import Errors'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Text(
                errors.join('\n'),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  void _showMsg(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _scanQr() async {
    final data = await showDialog<ZatcaQrData>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.all(20),
          child: SizedBox(width: 400, height: 450, child: QrScannerScreen()),
        );
      },
    );
    if (data == null || !mounted) return;

    // ── Fill supplier fields ───────────────────────────────────────────────
    final matched =
        context.read<SupplierProvider>().findSupplierByVatNumber(
          data.vatNumber,
        ) ??
        Supplier(
          id: '',
          name: data.sellerName,
          vatNumber: data.vatNumber,
          phone: '',
          address: '',
        );

    // ── Fill invoice date ──────────────────────────────────────────────────
    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(data.invoiceDate);
    } catch (_) {
      // Some QR codes use "dd/MM/yyyy HH:mm:ss" — try that too
      try {
        final parts = data.invoiceDate.split(' ');
        final dateParts = parts[0].split('/');
        if (dateParts.length == 3) {
          parsedDate = DateTime(
            int.parse(dateParts[2]),
            int.parse(dateParts[1]),
            int.parse(dateParts[0]),
          );
        }
      } catch (_) {}
    }

    // ── Fill amount fields ─────────────────────────────────────────────────

    final totalIncVat = double.tryParse(data.totalIncVat) ?? 0;
    final vatAmount = double.tryParse(data.vatAmount) ?? 0;
    final amountExVat = totalIncVat - vatAmount;
    final vatRate = (amountExVat > 0)
        ? ((vatAmount / amountExVat) * 100).roundToDouble()
        : 15.0;

    setState(() {
      _directScanError = null;
      _selectedSupplier = matched;

      if (parsedDate != null) _invoiceDate = parsedDate;
      _amountExVatController.text = amountExVat.toStringAsFixed(2);
      _vatAmountController.text = vatAmount.toStringAsFixed(2);
      _totalIncVatController.text = totalIncVat.toStringAsFixed(2);
      _vatRateController.text = vatRate.toStringAsFixed(0);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _invoiceNoFocusNode.canRequestFocus) {
        FocusScope.of(context).requestFocus(_invoiceNoFocusNode);
      }
    });
    _showMsg('QR scanned: ${data.sellerName}', Colors.green);
  }

  void _processDirectScan(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) return;

    final data = ZatcaQrParser.parse(raw);
    if (data == null || data.vatNumber.trim().isEmpty) {
      setState(() => _directScanError = 'Invalid ZATCA QR payload. Try again.');
      _directScanController.clear();
      _directScanFocusNode.requestFocus();
      return;
    }

    final matched =
        context.read<SupplierProvider>().findSupplierByVatNumber(
          data.vatNumber,
        ) ??
        Supplier(
          id: '',
          name: data.sellerName,
          vatNumber: data.vatNumber,
          phone: '',
          address: '',
        );

    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(data.invoiceDate);
    } catch (_) {
      final dateParts = data.invoiceDate.split(' ').first.split('/');
      if (dateParts.length == 3) {
        parsedDate = DateTime.tryParse(
          '${dateParts[2]}-${dateParts[1]}-${dateParts[0]}',
        );
      }
    }

    final totalIncVat = double.tryParse(data.totalIncVat) ?? 0;
    final vatAmount = double.tryParse(data.vatAmount) ?? 0;
    final amountExVat = totalIncVat - vatAmount;
    final vatRate = amountExVat > 0
        ? ((vatAmount / amountExVat) * 100).roundToDouble()
        : 15.0;

    setState(() {
      _directScanError = null;
      _selectedSupplier = matched;
      if (parsedDate != null) _invoiceDate = parsedDate;
      _amountExVatController.text = amountExVat.toStringAsFixed(2);
      _vatAmountController.text = vatAmount.toStringAsFixed(2);
      _totalIncVatController.text = totalIncVat.toStringAsFixed(2);
      _vatRateController.text = vatRate.toStringAsFixed(0);
    });

    _directScanController.clear();
    _scheduleAutoSave();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _invoiceNoFocusNode.canRequestFocus) {
        FocusScope.of(context).requestFocus(_invoiceNoFocusNode);
      }
    });
    _showMsg('QR scanned: ${data.sellerName}', Colors.green);
  }

  Widget _buildDirectScanField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.tab &&
                _directScanController.text.trim().isNotEmpty) {
              _processDirectScan(_directScanController.text);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: _directScanController,
            focusNode: _directScanFocusNode,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: _processDirectScan,
            decoration: InputDecoration(
              hintText: 'Direct scan ZATCA QR code...',
              hintStyle: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary(context),
              ),
              prefixIcon: Icon(
                Icons.sensors,
                size: 17,
                color: AppTheme.accent(context),
              ),
              filled: true,
              fillColor: AppTheme.inputBg(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppTheme.cardBorderColor(context),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppTheme.cardBorderColor(context),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppTheme.accent(context),
                  width: 1.5,
                ),
              ),
              isDense: true,
            ),
          ),
        ),
        if (_directScanError != null) ...[
          const SizedBox(height: 4),
          Text(
            _directScanError!,
            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
          ),
        ],
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_initialLoadDone && !_requestedInitialDirectScanFocus) {
      _requestedInitialDirectScanFocus = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_directScanFocusNode.canRequestFocus) {
          FocusScope.of(context).requestFocus(_directScanFocusNode);
        }
      });
    }

    if (!_initialLoadDone) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBg(context),
        appBar: AppBar(
          toolbarHeight: 52,
          backgroundColor: AppTheme.surfaceBg(context),
          elevation: 0,
          centerTitle: true,
          title: Text(
            _isEditMode ? 'Edit Purchase Entry' : 'New Purchase Entry',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(context),
            ),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent(context)),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBg(context),
        appBar: AppBar(
          toolbarHeight: 52,
          backgroundColor: AppTheme.surfaceBg(context),
          elevation: 0,
          centerTitle: true,
          title: Text(
            _isEditMode ? 'Edit Purchase Entry' : 'New Purchase Entry',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(context),
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 42),
                const SizedBox(height: 12),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final provider = context.watch<PurchaseEntryProvider>();
    final isDesktop = context.isDesktop;
    final isMobile = context.isMobile;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleFocusedShortcut,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg(context),
        appBar: AppBar(
          toolbarHeight: 52,
          backgroundColor: AppTheme.surfaceBg(context),
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Go back',
            icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary(context)),
            onPressed: () {
              context.read<PurchaseEntryProvider>().clearItems();
              Navigator.pop(context);
            },
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _isEditMode ? 'Edit Purchase Entry' : 'New Purchase Entry',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
              if (!isMobile && provider.items.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildHeaderBadge(
                  '${provider.items.length} items',
                  AppTheme.accent(context).withValues(alpha: 0.12),
                  AppTheme.accent(context),
                ),
              ],
              if (_isEditMode) ...[
                const SizedBox(width: 6),
                _buildHeaderBadge(
                  'Editing',
                  Colors.orange.withValues(alpha: 0.15),
                  Colors.orange.shade800,
                ),
              ],
            ],
          ),
          actions: [
            if (!isMobile)
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.inputBg(context),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.cardBorderColor(context)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    isDense: true,
                    dropdownColor: AppTheme.surfaceBg(context),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary(context),
                      fontWeight: FontWeight.w500,
                    ),
                    items: _sortOptions(),
                    onChanged: _setSortBy,
                  ),
                ),
              )
            else
              PopupMenuButton<String>(
                tooltip: 'Sort entries',
                icon: Icon(Icons.sort, color: AppTheme.textPrimary(context)),
                onSelected: _setSortBy,
                itemBuilder: (context) => _sortOptions()
                    .map(
                      (item) => PopupMenuItem<String>(
                        value: item.value,
                        child: item.child,
                      ),
                    )
                    .toList(),
              ),
            IconButton(
              tooltip: 'Bulk Import',
              icon: Icon(
                Icons.upload_file,
                size: 18,
                color: AppTheme.textPrimary(context),
              ),
              onPressed: _openBulkImportDialog,
            ),
            IconButton(
              tooltip: 'Clear Current Fields',
              icon: Icon(
                Icons.refresh,
                size: 17,
                color: AppTheme.textSecondary(context),
              ),
              onPressed: () => setState(() {
                _isSaving = false;
                _clearEntryFields();
              }),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveInvoice,
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isEditMode ? Icons.update_rounded : Icons.save_rounded,
                        size: 17,
                      ),
                label: Text(
                  _isEditMode ? 'Update Invoice' : 'Save Invoice',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 12),
            ] else
              const SizedBox(width: 4),
          ],
        ),
        bottomNavigationBar: !isDesktop
            ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBg(context),
                    border: Border(
                      top: BorderSide(color: AppTheme.cardBorderColor(context)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Grand Total: SAR ${provider.getTotalAmountIncVat().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent(context),
                              ),
                            ),
                            Text(
                              '${provider.items.length} line item${provider.items.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveInvoice,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _isEditMode ? Icons.update : Icons.save,
                                size: 16,
                              ),
                        label: Text(_isEditMode ? 'Update' : 'Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent(context),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        body: Form(
          key: _formKey,
          child: isDesktop
              ? _buildDesktopLayout(context, provider)
              : _buildMobileTabletLayout(context, provider),
        ),
      ),
    );
  }

  Widget _buildHeaderBadge(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  KeyEventResult _handleFocusedShortcut(FocusNode node, KeyEvent event) {
    final isEnter =
        event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter);
    if (isEnter &&
        HardwareKeyboard.instance.isControlPressed &&
        _initialLoadDone &&
        !_isSaving) {
      _addEntry();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<DropdownMenuItem<String>> _sortOptions() => const [
    DropdownMenuItem(value: 'date_desc', child: Text('Sort: Newest')),
    DropdownMenuItem(value: 'date_asc', child: Text('Sort: Oldest')),
    DropdownMenuItem(value: 'supplier_asc', child: Text('Sort: Supplier A-Z')),
    DropdownMenuItem(value: 'supplier_desc', child: Text('Sort: Supplier Z-A')),
    DropdownMenuItem(
      value: 'amount_desc',
      child: Text('Sort: Amount High-Low'),
    ),
    DropdownMenuItem(value: 'amount_asc', child: Text('Sort: Amount Low-High')),
  ];

  void _setSortBy(String? value) {
    if (value != null) setState(() => _sortBy = value);
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    PurchaseEntryProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTotalsKpiRow(context, provider),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.cardBorderColor(context),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Line Items (${provider.items.length})',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                            if (provider.items.isNotEmpty)
                              TextButton.icon(
                                onPressed: () {
                                  provider.clearItems();
                                  _scheduleAutoSave();
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 14,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Clear All',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(child: _buildEntriesTable()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: context.screenWidth >= 1400 ? 380 : 350,
            child: SingleChildScrollView(child: _buildFormCard(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTabletLayout(
    BuildContext context,
    PurchaseEntryProvider provider,
  ) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: AppTheme.surfaceBg(context),
            child: TabBar(
              indicatorColor: AppTheme.accent(context),
              labelColor: AppTheme.accent(context),
              unselectedLabelColor: AppTheme.textSecondary(context),
              tabs: [
                const Tab(
                  icon: Icon(Icons.add_card_outlined, size: 18),
                  text: 'Entry Form',
                ),
                Tab(
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  text: 'Items (${provider.items.length})',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: _buildFormCard(context),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildTotalsKpiRow(context, provider),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.cardBorderColor(context),
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Line Items (${provider.items.length})',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(height: 360, child: _buildEntriesTable()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('Period Section'),
          _buildPeriodSectionDropdown(),
          if (_selectedPeriod != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.accent(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.accent(context).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 13,
                    color: AppTheme.accent(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_selectedPeriod!.name} · ${_selectedPeriod!.range}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.accent(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildSectionHeader('Customer'),
          const SizedBox(height: 6),
          if (_selectedCustomer != null)
            _buildSelectedCard(
              title: _selectedCustomer!.name,
              subtitle: _selectedCustomer!.phone,
              color: Colors.blue.withValues(alpha: 0.08),
              accentColor: Colors.blue.shade700,
              icon: Icons.person_outline,
              onClear: () => setState(() {
                _selectedCustomer = null;
                _selectedSupplier = null;
              }),
            )
          else
            _buildSearchField(
              controller: _customerSearchController,
              focusNode: _customerSearchFocusNode,
              hintText: 'Search customer...',
              onChanged: _filterCustomers,
              showDropdown: _showCustomerDropdown,
              items: _filteredCustomers
                  .map(
                    (customer) => ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.accent(
                          context,
                        ).withValues(alpha: 0.15),
                        child: Text(
                          customer.name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.accent(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        customer.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        customer.phone,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onTap: () => _selectCustomer(customer),
                    ),
                  )
                  .toList(),
              onTap: () => _showCreateCustomerDialog(context),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Supplier'),
              TextButton.icon(
                onPressed: _scanQr,
                icon: const Icon(Icons.qr_code_scanner, size: 14),
                label: const Text('Scan QR', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accent(context),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  backgroundColor: AppTheme.accent(
                    context,
                  ).withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildDirectScanField(),
          const SizedBox(height: 6),
          if (_selectedSupplier != null)
            _buildSelectedCard(
              title: _selectedSupplier!.name,
              subtitle: 'VAT: ${_selectedSupplier!.vatNumber}',
              color: Colors.green.withValues(alpha: 0.08),
              accentColor: Colors.green.shade700,
              icon: Icons.store_outlined,
              onClear: () => setState(() => _selectedSupplier = null),
            )
          else
            _buildSearchField(
              controller: _supplierSearchController,
              focusNode: _supplierSearchFocusNode,
              hintText: 'Search supplier...',
              onChanged: _filterSuppliers,
              showDropdown: _showSupplierDropdown,
              items: _filteredSuppliers
                  .map(
                    (supplier) => ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.green.withValues(alpha: 0.15),
                        child: Text(
                          supplier.name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        supplier.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        'VAT: ${supplier.vatNumber}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onTap: () => _selectSupplier(supplier),
                    ),
                  )
                  .toList(),
              onTap: () => _showCreateSupplierDialog(context),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Invoice Number *'),
                    TextFormField(
                      controller: _invoiceNoController,
                      focusNode: _invoiceNoFocusNode,
                      onFieldSubmitted: (_) =>
                          _invoiceDateFocusNode.requestFocus(),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary(context),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'INV-001',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 11,
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Purchase Date *'),
                    InkWell(
                      focusNode: _invoiceDateFocusNode,
                      onTap: _pickInvoiceDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.inputBg(context),
                          border: Border.all(
                            color: AppTheme.cardBorderColor(context),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                _invoiceDate != null
                                    ? DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(_invoiceDate!)
                                    : 'Select date',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: _invoiceDate != null
                                      ? AppTheme.textPrimary(context)
                                      : AppTheme.textSecondary(context),
                                  fontWeight: _invoiceDate != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 15,
                              color: AppTheme.accent(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Amount (Excl. VAT) *'),
                    TextFormField(
                      controller: _amountExVatController,
                      focusNode: _amountExVatFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary(context),
                      ),
                      onChanged: (_) => _calculateFromAmountExVat(),
                      onFieldSubmitted: (_) => _vatRateFocusNode.requestFocus(),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (double.tryParse(value) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 64,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('VAT %'),
                    TextFormField(
                      textAlign: TextAlign.center,
                      controller: _vatRateController,
                      focusNode: _vatRateFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary(context),
                      ),
                      onChanged: (_) => _calculateFromAmountExVat(),
                      onFieldSubmitted: (_) =>
                          _vatAmountFocusNode.requestFocus(),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '15',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('VAT Amount'),
                    TextFormField(
                      controller: _vatAmountController,
                      focusNode: _vatAmountFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary(context),
                      ),
                      onChanged: (_) => _calculateFromVatAmount(),
                      onFieldSubmitted: (_) =>
                          _totalIncVatFocusNode.requestFocus(),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Total (Incl. VAT)'),
                    TextFormField(
                      controller: _totalIncVatController,
                      focusNode: _totalIncVatFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary(context),
                      ),
                      onChanged: (_) => _calculateFromTotal(),
                      onFieldSubmitted: (_) =>
                          _entryActionFocusNode.requestFocus(),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              focusNode: _entryActionFocusNode,
              onPressed: _isSaving ? null : _addEntry,
              icon: Icon(
                _editingIndex != null
                    ? Icons.update_rounded
                    : Icons.add_rounded,
              ),
              label: Text(
                _editingIndex != null
                    ? 'Update Entry (Ctrl + Enter)'
                    : 'Add Entry (Ctrl + Enter)',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildLastAddedItemPreview(),
        ],
      ),
    );
  }

  Widget _buildLastAddedItemPreview() {
    return Consumer<PurchaseEntryProvider>(
      builder: (context, provider, _) {
        if (provider.items.isEmpty) return const SizedBox.shrink();

        final item = provider.items.last;
        final accent = AppTheme.accent(context);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.inputBg(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.cardBorderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 15, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    'Last added item',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.invoiceNo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${item.supplierName}  •  ${DateFormat('dd/MM/yyyy').format(item.date)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary(context),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Ex VAT: ${item.amountExVat.toStringAsFixed(2)}  •  '
                'VAT: ${item.vatAmount.toStringAsFixed(2)}  •  '
                'Total: ${item.totalIncVat.toStringAsFixed(2)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodSectionDropdown() {
    if (_periodsLoading) {
      return Container(
        height: 42,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.cardBorderColor(context)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.accent(context),
            ),
          ),
        ),
      );
    }
    if (_periods.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No period sections created yet',
                style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
              ),
            ),
          ],
        ),
      );
    }
    return DropdownButtonFormField<_Period>(
      initialValue: _selectedPeriod,
      focusNode: _periodSectionFocusNode,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Select period section',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        prefixIcon: const Icon(Icons.date_range_outlined, size: 18),
        suffixIcon: _selectedPeriod == null
            ? null
            : IconButton(
                tooltip: 'Clear period section',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  setState(() => _selectedPeriod = null);
                  _scheduleAutoSave();
                },
              ),
      ),
      items: _periods
          .map(
            (period) => DropdownMenuItem<_Period>(
              value: period,
              child: Text(period.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() => _selectedPeriod = value);
        _scheduleAutoSave();
      },
    );
  }

  Widget _buildTotalsKpiRow(
    BuildContext context,
    PurchaseEntryProvider provider,
  ) {
    final cards = [
      _buildKpiCard(
        label: 'Amount (Ex-VAT)',
        value: 'SAR ${provider.getTotalAmountExVat().toStringAsFixed(2)}',
        icon: Icons.calculate_outlined,
        color: const Color(0xFF3B82F6),
      ),
      _buildKpiCard(
        label: 'Total VAT',
        value: 'SAR ${provider.getTotalVatAmount().toStringAsFixed(2)}',
        icon: Icons.percent,
        color: const Color(0xFFF59E0B),
      ),
      _buildKpiCard(
        label: 'Grand Total',
        value: 'SAR ${provider.getTotalAmountIncVat().toStringAsFixed(2)}',
        icon: Icons.payments_outlined,
        color: const Color(0xFF10B981),
      ),
      _buildKpiCard(
        label: 'Bills Count',
        value: '${provider.items.length}',
        icon: Icons.receipt_long_outlined,
        color: AppTheme.accent(context),
      ),
    ];
    if (context.isMobile) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cards
                .map((card) => SizedBox(width: itemWidth, child: card))
                .toList(),
          );
        },
      );
    }
    return Row(
      children: cards
          .map(
            (card) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: card,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppTheme.isDark(context) ? 0.2 : 0.02,
            ),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateCustomerDialog(BuildContext context) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          contentPadding: EdgeInsets.zero,
          insetPadding: const EdgeInsets.all(16),
          content: SizedBox(
            width: (context.screenWidth - 48).clamp(0.0, 820.0).toDouble(),
            child: CreateCustomerScreen(),
          ),
        ),
      );

  Future<void> _showCreateSupplierDialog(BuildContext context) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          contentPadding: EdgeInsets.zero,
          insetPadding: const EdgeInsets.all(16),
          content: SizedBox(
            width: (context.screenWidth - 48).clamp(0.0, 500.0).toDouble(),
            height: (context.screenHeight - 64).clamp(0.0, 500.0).toDouble(),
            child: CreateSupplierScreen(),
          ),
        ),
      );

  // ── Entries table ─────────────────────────────────────────────────────────
  Widget _buildEntriesTable() {
    return Consumer<PurchaseEntryProvider>(
      builder: (context, provider, _) {
        if (provider.items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              border: Border.all(color: AppTheme.cardBorderColor(context)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'No entries added yet',
                style: TextStyle(
                  color: AppTheme.textMuted(context),
                  fontSize: 14,
                ),
              ),
            ),
          );
        }

        final sortedItems = _getSortedItems(provider.items);
        final borderColor = AppTheme.cardBorderColor(context);

        final columns = <PlutoColumn>[
          PlutoColumn(
            title: 'SL',
            field: 'sl',
            type: PlutoColumnType.number(format: '#,##0'),
            width: 56,
            minWidth: 56,
            readOnly: true,
            enableEditingMode: false,
            enableColumnDrag: false,
            enableDropToResize: false,
            enableContextMenu: false,
            enableSorting: false,
          ),
          PlutoColumn(
            title: 'Date',
            field: 'date',
            type: PlutoColumnType.text(),
            width: 100,
            minWidth: 100,
            readOnly: true,
            enableEditingMode: false,
            enableColumnDrag: false,
            enableDropToResize: false,
            enableContextMenu: false,
            enableSorting: false,
          ),
          PlutoColumn(
            title: 'Invoice No',
            field: 'invoiceNo',
            type: PlutoColumnType.text(),
            width: 150,
            minWidth: 120,
            readOnly: true,
            enableEditingMode: false,
            enableColumnDrag: false,
            enableContextMenu: false,
            enableSorting: false,
          ),
          PlutoColumn(
            title: 'Supplier',
            field: 'supplier',
            type: PlutoColumnType.text(),
            width: 160,
            minWidth: 120,
            readOnly: true,
            enableEditingMode: false,
            enableColumnDrag: false,
            enableContextMenu: false,
            enableSorting: false,
          ),
          PlutoColumn(
            title: 'VAT Number',
            field: 'vatNumber',
            type: PlutoColumnType.text(),
            width: 120,
            minWidth: 100,
            readOnly: true,
            enableEditingMode: false,
            enableColumnDrag: false,
            enableContextMenu: false,
            enableSorting: false,
          ),
          PlutoColumn(
            title: 'Amount (Ex)',
            field: 'amountExVat',
            type: PlutoColumnType.number(format: '#,##0.00'),
            width: 110,
            minWidth: 100,
            textAlign: PlutoColumnTextAlign.right,
            readOnly: true,
            enableEditingMode: false,
            enableColumnDrag: false,
            enableContextMenu: false,
            enableSorting: false,
          ),
          PlutoColumn(
            title: 'VAT',
            field: 'vatAmount',
            type: PlutoColumnType.number(format: '#,##0.00'),
            width: 100,
            minWidth: 90,
            textAlign: PlutoColumnTextAlign.right,
            readOnly: true,
            enableEditingMode: false,
            enableColumnDrag: false,
            enableContextMenu: false,
            enableSorting: false,
          ),
          PlutoColumn(
            title: 'Total (Inc)',
            field: 'totalIncVat',
            type: PlutoColumnType.number(format: '#,##0.00'),
            width: 120,
            minWidth: 110,
            textAlign: PlutoColumnTextAlign.right,
            readOnly: true,
            enableEditingMode: false,
            enableColumnDrag: false,
            enableContextMenu: false,
            enableSorting: false,
          ),
          PlutoColumn(
            title: 'Actions',
            field: 'actions',
            type: PlutoColumnType.text(),
            width: 88,
            minWidth: 88,
            readOnly: true,
            enableEditingMode: false,
            enableColumnDrag: false,
            enableDropToResize: false,
            enableContextMenu: false,
            enableSorting: false,
            renderer: (rendererContext) {
              final itemId = rendererContext.cell.value as String;
              final originalIndex = provider.items.indexWhere(
                (item) => item.id == itemId,
              );

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Edit entry',
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Colors.blue,
                      size: 16,
                    ),
                    onPressed: originalIndex < 0
                        ? null
                        : () => _startEditEntry(originalIndex),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete entry',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 16,
                    ),
                    onPressed: originalIndex < 0
                        ? null
                        : () {
                            provider.removeItem(originalIndex);
                            _scheduleAutoSave();
                            if (_editingIndex == originalIndex) {
                              setState(_clearEntryFields);
                            }
                            _showMsg('Entry removed', Colors.red);
                          },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                  ),
                ],
              );
            },
          ),
        ];

        final rows = sortedItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return PlutoRow(
            cells: {
              'sl': PlutoCell(value: index + 1),
              'date': PlutoCell(
                value: DateFormat('dd/MM/yyyy').format(item.date),
              ),
              'invoiceNo': PlutoCell(value: item.invoiceNo),
              'supplier': PlutoCell(value: item.supplierName),
              'vatNumber': PlutoCell(value: item.vatNumber),
              'amountExVat': PlutoCell(value: item.amountExVat),
              'vatAmount': PlutoCell(value: item.vatAmount),
              'totalIncVat': PlutoCell(value: item.totalIncVat),
              'actions': PlutoCell(value: item.id),
            },
          );
        }).toList();

        return PlutoGrid(
          key: ValueKey(
            jsonEncode(
              sortedItems
                  .map(
                    (item) => [
                      item.id,
                      item.date.toIso8601String(),
                      item.invoiceNo,
                      item.supplierName,
                      item.vatNumber,
                      item.amountExVat,
                      item.vatAmount,
                      item.totalIncVat,
                    ],
                  )
                  .toList(),
            ),
          ),
          columns: columns,
          rows: rows,
          configuration: PlutoGridConfiguration(
            style: PlutoGridStyleConfig(
              gridBackgroundColor: AppTheme.cardBg(context),
              rowColor: AppTheme.cardBg(context),
              evenRowColor: AppTheme.cardBg(context),
              oddRowColor: AppTheme.scaffoldBg(context),
              activatedColor: AppTheme.accent(context).withValues(alpha: 0.12),
              borderColor: borderColor,
              gridBorderColor: borderColor,
              columnHeight: 40,
              rowHeight: 40,
              columnTextStyle: TextStyle(
                color: AppTheme.textSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              cellTextStyle: TextStyle(
                color: AppTheme.textPrimary(context),
                fontSize: 12,
              ),
              gridBorderRadius: BorderRadius.circular(8),
            ),
            scrollbar: const PlutoGridScrollbarConfig(
              isAlwaysShown: true,
              draggableScrollbar: true,
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) => Text(
    title,
    style: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: AppTheme.textPrimary(context),
    ),
  );

  Widget _buildFieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary(context),
      ),
    ),
  );

  Widget _buildSelectedCard({
    required String title,
    required String subtitle,
    required Color color,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onClear,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required Function(String) onChanged,
    required bool showDropdown,
    required List<Widget> items,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 45,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: hintText,

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              GestureDetector(
                onTap: onTap,
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (showDropdown && items.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView(shrinkWrap: true, children: items),
          ),
      ],
    );
  }
}
