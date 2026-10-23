import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:provider/provider.dart';

import '../models/customer_model.dart';
import '../models/purchase_entry_model.dart';
import '../models/supplier_model.dart';
import '../providers/customer_provider.dart';
import '../providers/editPurchaseEntryProvider.dart';
import '../providers/supplier_provider.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';
import '../utils/zatca_qr_parser.dart';
import 'createCustomerScreen.dart';
import 'createSupplierScreen.dart';
import 'qr_scanner_screen.dart';

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

  String get range =>
      '${DateFormat('MMM yyyy').format(startDate)} – '
      '${DateFormat('MMM yyyy').format(endDate)}';

  String get label => '$name  ($range)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen — EDIT an existing purchase invoice.
// Powered by EditPurchaseEntryProvider and loads its data by [invoiceId].
// ─────────────────────────────────────────────────────────────────────────────

class EditPurchaseEntryScreen extends StatefulWidget {
  final String invoiceId;
  const EditPurchaseEntryScreen({super.key, required this.invoiceId});

  @override
  State<EditPurchaseEntryScreen> createState() =>
      _EditPurchaseEntryScreenState();
}

class _EditPurchaseEntryScreenState extends State<EditPurchaseEntryScreen> {
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
  String _sortBy = 'lifo';

  List<Customer> _filteredCustomers = [];
  List<Supplier> _filteredSuppliers = [];

  bool _showCustomerDropdown = false;
  bool _showSupplierDropdown = false;
  bool _isSaving = false;
  int? _editingIndex;
  int _entriesSinceAutoSave = 0;
  String? _directScanError;
  static const int _autoSaveEntryBatchSize = 10;

  bool _initialLoadDone = false;
  String? _loadError;

  // ── Periods ───────────────────────────────────────────────────────────────
  List<_Period> _periods = [];
  bool _periodsLoading = true;
  _Period? _selectedPeriod;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleShortcutKey);
    _loadEverything();
  }

  bool _handleShortcutKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        !_initialLoadDone ||
        _isSaving ||
        ModalRoute.of(context)?.isCurrent != true) {
      return false;
    }

    if (event.logicalKey == LogicalKeyboardKey.f5) {
      _saveInvoice();
      return true;
    }

    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (isEnter && HardwareKeyboard.instance.isControlPressed) {
      _addEntry();
      return true;
    }
    return false;
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

  Future<void> _loadEverything() async {
    await Future.wait([
      _fetchPeriods(),
      context.read<CustomerProvider>().fetchCustomers(),
      context.read<SupplierProvider>().ensureSuppliersLoaded(),
    ]);

    if (!mounted) return;
    final provider = context.read<EditPurchaseEntryProvider>();
    final loaded = await provider.fetchInvoiceById(widget.invoiceId);

    if (!mounted) return;

    if (!loaded) {
      setState(() {
        _loadError = provider.errorMessage ?? 'Failed to load invoice';
        _initialLoadDone = true;
      });
      return;
    }

    _populateFromInvoice(provider.originalInvoice!);

    setState(() {
      _initialLoadDone = true;
    });
  }

  Future<void> _fetchPeriods() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('period_sections')
          .orderBy('sectionNumber')
          .get();

      if (!mounted) return;
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
    } catch (e) {
      if (mounted) setState(() => _periodsLoading = false);
      debugPrint('Error fetching periods: $e');
    }
  }

  void _matchPeriod(String periodId) {
    try {
      final match = _periods.firstWhere((p) => p.id == periodId);
      setState(() => _selectedPeriod = match);
    } catch (_) {}
  }

  void _populateFromInvoice(PurchaseInvoice inv) {
    _invoiceNoController.text = inv.invoiceNo;
    _invoiceDate = inv.invoiceDate;

    if (inv.periodSectionId.isNotEmpty && _periods.isNotEmpty) {
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
        taxNumber: inv.customerVatNumber,
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
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleShortcutKey);
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

  void _clearEntryFields() {
    _editingIndex = null;
    _clearEntryAmountFields();
    _invoiceNoController.clear();
    _invoiceDate = null;
    _selectedSupplier = null;
    _supplierSearchController.clear();
    _directScanController.clear();
    _directScanError = null;
    _showSupplierDropdown = false;
  }

  void _clearEntryAmountFields() {
    _amountExVatController.clear();
    _vatAmountController.clear();
    _totalIncVatController.clear();
    _vatRateController.text = '15';
  }

  void _focusDirectScanField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _directScanFocusNode.requestFocus();
    });
  }

  List<PurchaseItem> _getSortedItems(List<PurchaseItem> items) {
    final sorted = List<PurchaseItem>.from(items);
    if (_sortBy == 'lifo') return sorted.reversed.toList();

    sorted.sort((a, b) {
      switch (_sortBy) {
        case 'date_asc':
          return a.createdAt.compareTo(b.createdAt);
        case 'date_desc':
          return b.createdAt.compareTo(a.createdAt);
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
    final provider = context.read<EditPurchaseEntryProvider>();
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
          address: '',
        );
      }
    });
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

  void _selectCustomer(Customer c) => setState(() {
    _selectedCustomer = c;
    _selectedSupplier = null;
    _showCustomerDropdown = false;
    _customerSearchController.clear();
  });

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _invoiceNoFocusNode.requestFocus();
    });
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
      _amountExVatFocusNode.requestFocus();
    }
  }

  // ── Add / update a local entry ────────────────────────────────────────────
  Future<void> _addEntry() async {
    if (_isSaving) return;
    if (!_validateInvoiceForm()) return;
    final provider = context.read<EditPurchaseEntryProvider>();
    if (!await _checkInvoiceNumberUnique()) return;
    if (!mounted) return;

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
      final saved = await _saveInvoice(
        closeOnSuccess: false,
        showSuccessMessage: false,
      );
      if (!saved || !mounted) return;

      _clearEntryFields();
      _focusDirectScanField();
      _showMsg('Entry updated and invoice saved', Colors.green);
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

    _entriesSinceAutoSave++;
    if (_entriesSinceAutoSave >= _autoSaveEntryBatchSize) {
      final saved = await _saveInvoice(
        closeOnSuccess: false,
        showSuccessMessage: false,
      );
      if (!saved || !mounted) return;

      _entriesSinceAutoSave = 0;
      _clearEntryFields();
      _focusDirectScanField();
      _showMsg('10 entries auto-saved to the invoice', Colors.green);
      return;
    }

    _clearEntryFields();
    _focusDirectScanField();
    _showMsg(
      'Entry added ($_entriesSinceAutoSave/$_autoSaveEntryBatchSize before auto-save)',
      Colors.green,
    );
  }

  // ── Save (update) ─────────────────────────────────────────────────────────
  Future<bool> _saveInvoice({
    bool closeOnSuccess = true,
    bool showSuccessMessage = true,
  }) async {
    if (_isSaving) return false;

    final provider = context.read<EditPurchaseEntryProvider>();

    if (provider.items.isEmpty) {
      _showMsg('Please add at least one entry', Colors.orange);
      return false;
    }

    final originalInvoice = provider.originalInvoice;
    final lastItem = provider.items.last;
    final supplier =
        _selectedSupplier ??
        (originalInvoice != null && originalInvoice.supplierName.isNotEmpty
            ? Supplier(
                id: originalInvoice.supplierId,
                name: originalInvoice.supplierName,
                vatNumber: '',
                phone: '',
                address: '',
              )
            : lastItem.supplierName.isNotEmpty
            ? Supplier(
                id: lastItem.supplierId,
                name: lastItem.supplierName,
                vatNumber: lastItem.vatNumber,
                phone: '',
                address: '',
              )
            : null);
    final invoiceNo = _invoiceNoController.text.trim().isNotEmpty
        ? _invoiceNoController.text.trim()
        : originalInvoice?.invoiceNo.isNotEmpty == true
        ? originalInvoice!.invoiceNo
        : lastItem.invoiceNo;
    final invoiceDate =
        _invoiceDate ?? originalInvoice?.invoiceDate ?? lastItem.date;

    if (!_validateInvoiceForm(
      supplier: supplier,
      invoiceNo: invoiceNo,
      invoiceDate: invoiceDate,
    )) {
      return false;
    }
    if (!await _checkInvoiceNumberUnique(
      invoiceNo: invoiceNo,
      supplierName: supplier!.name,
    )) {
      return false;
    }

    setState(() => _isSaving = true);

    try {
      final success = await provider.updateInvoice(
        invoiceId: widget.invoiceId,
        customerId: _selectedCustomer!.id,
        customerName: _selectedCustomer!.name,
        customerVatNumber: _selectedCustomer!.taxNumber,
        supplierId: supplier.id ?? '',
        supplierName: supplier.name,
        invoiceNo: invoiceNo,
        invoiceDate: invoiceDate,
        periodSectionId: _selectedPeriod?.id,
        periodSectionName: _selectedPeriod?.name,
      );

      if (!mounted) return success;
      if (success) {
        _entriesSinceAutoSave = 0;
        if (showSuccessMessage) {
          _showMsg('Invoice updated successfully!', Colors.green);
        }
        if (closeOnSuccess) Navigator.pop(context, true);
      } else {
        _showMsg(provider.errorMessage ?? 'Error updating invoice', Colors.red);
      }
      return success;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _validateInvoiceForm({
    Supplier? supplier,
    String? invoiceNo,
    DateTime? invoiceDate,
  }) {
    if (_selectedCustomer == null) {
      _showMsg('Please select a customer', Colors.orange);
      return false;
    }
    if ((supplier ?? _selectedSupplier) == null) {
      _showMsg('Please select a supplier', Colors.orange);
      return false;
    }
    if ((invoiceNo ?? _invoiceNoController.text).trim().isEmpty) {
      _showMsg('Please enter invoice number', Colors.orange);
      return false;
    }
    if (invoiceDate == null && _invoiceDate == null) {
      _showMsg('Please select invoice date', Colors.orange);
      return false;
    }
    return true;
  }

  Future<bool> _checkInvoiceNumberUnique({
    String? invoiceNo,
    String? supplierName,
  }) async {
    final normalizedInvoiceNo = (invoiceNo ?? _invoiceNoController.text).trim();
    if (normalizedInvoiceNo.isEmpty) return false;

    final provider = context.read<EditPurchaseEntryProvider>();
    final normalizedSupplierName =
        supplierName ?? _selectedSupplier?.name ?? '';
    final exists = await provider.invoiceNumberExists(
      normalizedInvoiceNo,
      supplierName: normalizedSupplierName,
      excludeInvoiceId: widget.invoiceId,
    );

    if (provider.errorMessage != null) {
      _showMsg(provider.errorMessage!, Colors.red);
      return false;
    }

    if (exists) {
      _showMsg(
        'Invoice number "$normalizedInvoiceNo" already exists for "$normalizedSupplierName".',
        Colors.orange,
      );
      return false;
    }
    return true;
  }

  // ── Bulk import helpers ───────────────────────────────────────────────────
  void _openBulkImportDialog() {
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
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paste CSV/text: invoiceNo,date(dd/MM/yyyy),supplierId|supplierName,amountExVat,vatRate,total[,vatNumber]',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary(ctx),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pasteController,
                  minLines: 5,
                  maxLines: 12,
                  style: TextStyle(color: AppTheme.textPrimary(ctx)),
                  decoration: InputDecoration(
                    hintText: 'Paste CSV lines here...',
                    hintStyle: TextStyle(color: AppTheme.textMuted(ctx)),
                    filled: true,
                    fillColor: AppTheme.inputBg(ctx),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppTheme.cardBorderColor(ctx),
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
                        backgroundColor: AppTheme.accent(ctx),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Import Paste'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _pickCsvFile();
                      },
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
    final provider = context.read<EditPurchaseEntryProvider>();

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

      final existsGlobal = await provider.invoiceNumberExists(
        invoiceNo,
        supplierName: supplier.name,
        excludeInvoiceId: widget.invoiceId,
      );
      if (existsGlobal) {
        errors.add(
          'Line ${i + 1}: invoiceNo "$invoiceNo" already exists for "${supplier.name}" in database',
        );
        skipped++;
        continue;
      }

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
    if (errors.isNotEmpty && mounted) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: AppTheme.cardBg(c),
          title: Text(
            'Import Errors',
            style: TextStyle(color: AppTheme.textPrimary(c)),
          ),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Text(
                errors.join('\n'),
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary(c),
                ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _scanQr() async {
    final data = await showDialog<ZatcaQrData>(
      context: context,
      builder: (context) {
        return const Dialog(
          insetPadding: EdgeInsets.all(20),
          child: SizedBox(width: 400, height: 450, child: QrScannerScreen()),
        );
      },
    );
    if (data == null || !mounted) return;

    _applyScannedQrData(data);
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

    _applyScannedQrData(data);
    _directScanController.clear();
  }

  void _applyScannedQrData(ZatcaQrData data) {
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
      if (mounted) _invoiceNoFocusNode.requestFocus();
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
                event.logicalKey == LogicalKeyboardKey.tab) {
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
    final isDesktop = context.isDesktop;
    final isMobile = context.isMobile;

    if (!_initialLoadDone) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBg(context),
        appBar: AppBar(
          toolbarHeight: 52,
          backgroundColor: AppTheme.surfaceBg(context),
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Edit Purchase Entry',
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
            'Edit Purchase Entry',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(context),
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text(
                _loadError!,
                style: TextStyle(color: AppTheme.textSecondary(context)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final provider = context.watch<EditPurchaseEntryProvider>();

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
            icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary(context)),
            onPressed: () {
              context.read<EditPurchaseEntryProvider>().reset();
              Navigator.pop(context);
            },
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Edit Purchase Entry',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              if (provider.items.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${provider.items.length} items',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent(context),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Editing',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            // Sort Dropdown
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
                  items: const [
                    DropdownMenuItem(
                      value: 'lifo',
                      child: Text('Sort: LIFO (Newest Added)'),
                    ),
                    DropdownMenuItem(
                      value: 'date_desc',
                      child: Text('Sort: Created Date Descending'),
                    ),
                    DropdownMenuItem(
                      value: 'date_asc',
                      child: Text('Sort: Created Date Ascending'),
                    ),
                    DropdownMenuItem(
                      value: 'supplier_asc',
                      child: Text('Sort: Supplier Alphabetical (A-Z)'),
                    ),
                    DropdownMenuItem(
                      value: 'supplier_desc',
                      child: Text('Sort: Supplier Alphabetical (Z-A)'),
                    ),
                    DropdownMenuItem(
                      value: 'amount_desc',
                      child: Text('Sort: Amt High-Low'),
                    ),
                    DropdownMenuItem(
                      value: 'amount_asc',
                      child: Text('Sort: Amt Low-High'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortBy = value);
                  },
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Bulk Import
            IconButton(
              tooltip: 'Bulk Import',
              icon: Icon(
                LucideIcons.fileSpreadsheet,
                size: 18,
                color: AppTheme.textPrimary(context),
              ),
              onPressed: _openBulkImportDialog,
            ),

            // Reset button
            IconButton(
              tooltip: 'Clear Current Fields',
              icon: Icon(
                LucideIcons.rotateCcw,
                size: 17,
                color: AppTheme.textSecondary(context),
              ),
              onPressed: () {
                setState(() {
                  _isSaving = false;
                  _clearEntryFields();
                });
              },
            ),

            // Save / Update Action Button (Desktop & Tablet)
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
                    : const Icon(Icons.update_rounded, size: 17),
                label: const Text(
                  'Update Invoice (F5)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
            ] else ...[
              const SizedBox(width: 6),
            ],
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
                            : const Icon(Icons.update, size: 16),
                        label: const Text(
                          'Update',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
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

  // ── Desktop Layout (2-Column Side-by-Side) ─────────────────────────────────
  Widget _buildDesktopLayout(
    BuildContext context,
    EditPurchaseEntryProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: KPI Cards + Line Items Table
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTotalsKpiRow(context, provider),
                const SizedBox(height: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Line Items (${provider.items.length} total; '
                            'latest entry shown below)',
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
                              },
                              icon: const Icon(
                                LucideIcons.trash2,
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
                      Expanded(child: _buildEntriesTable(provider)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Right Column: Form Panel
          SizedBox(
            width: 320,
            child: SingleChildScrollView(child: _buildFormCard(context)),
          ),
        ],
      ),
    );
  }

  // ── Mobile / Tablet Layout (Adaptive TabBar) ──────────────────────────────
  Widget _buildMobileTabletLayout(
    BuildContext context,
    EditPurchaseEntryProvider provider,
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
                  icon: Icon(LucideIcons.filePlus, size: 18),
                  text: 'Entry Form',
                ),
                Tab(
                  icon: const Icon(LucideIcons.listOrdered, size: 18),
                  text: 'Items (${provider.items.length})',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Form Entry
                SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: _buildFormCard(context),
                ),

                // Tab 2: Items Table & Totals
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
                              'Line Items (${provider.items.length} total; '
                              'latest entry shown below)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 360,
                              child: _buildEntriesTable(provider),
                            ),
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

  // ── Form Card ─────────────────────────────────────────────────────────────
  Widget _buildFormCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Period Section ───────────────────────────────────────────────
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
                    LucideIcons.checkCircle2,
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

          // ── Customer ─────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Customer'),
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      contentPadding: EdgeInsets.zero,
                      insetPadding: const EdgeInsets.all(16),
                      content: SizedBox(
                        width: 820,
                        child: const CreateCustomerScreen(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 15),
                label: const Text('New', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accent(context),
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_selectedCustomer != null)
            _buildSelectedCard(
              title: _selectedCustomer!.name,
              subtitle: _selectedCustomer!.phone,
              color: Colors.blue.withValues(alpha: 0.08),
              accentColor: Colors.blue.shade700,
              icon: LucideIcons.user,
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
                    (c) => ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.accent(
                          context,
                        ).withValues(alpha: 0.15),
                        child: Text(
                          c.name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.accent(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(c.name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        c.phone,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onTap: () => _selectCustomer(c),
                    ),
                  )
                  .toList(),
            ),

          const SizedBox(height: 12),
          // ── Supplier ─────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Supplier'),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _scanQr,
                    icon: const Icon(LucideIcons.qrCode, size: 14),
                    label: const Text(
                      'Scan QR',
                      style: TextStyle(fontSize: 12),
                    ),
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
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          contentPadding: EdgeInsets.zero,
                          insetPadding: const EdgeInsets.all(16),
                          content: SizedBox(
                            width: 500,
                            height: 500,
                            child: const CreateSupplierScreen(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('New', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accent(context),
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDirectScanField(),
          const SizedBox(height: 6),
          if (_selectedSupplier != null)
            _buildSelectedCard(
              title: _selectedSupplier!.name,
              subtitle: 'VAT: ${_selectedSupplier!.vatNumber}',
              color: Colors.green.withValues(alpha: 0.08),
              accentColor: Colors.green.shade700,
              icon: LucideIcons.store,
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
                    (s) => ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.green.withValues(alpha: 0.15),
                        child: Text(
                          s.name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(s.name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        'VAT: ${s.vatNumber}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onTap: () => _selectSupplier(s),
                    ),
                  )
                  .toList(),
            ),

          const SizedBox(height: 12),

          // ── Invoice Number + Purchase Date ───────────────────────────────
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
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                      child: Container(
                        height: 35,
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
                            Text(
                              _invoiceDate != null
                                  ? DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(_invoiceDate!)
                                  : 'Select date',
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
                            Icon(
                              LucideIcons.calendar,
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

          // ── Amounts & VAT ────────────────────────────────────────────────
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
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 40,
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
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade700,
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
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent(context),
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

          // ── Action Buttons ───────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  focusNode: _entryActionFocusNode,
                  onPressed: _addEntry,
                  icon: Icon(
                    _editingIndex != null ? Icons.update : Icons.add,
                    size: 18,
                  ),
                  label: Text(
                    _editingIndex != null
                        ? 'Update (Ctrl + Enter)'
                        : 'Add (Ctrl + Enter)',

                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
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
              if (_editingIndex != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _clearEntryFields();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel Edit'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSectionDropdown() {
    if (_periodsLoading) {
      return Container(
        height: 35,
        decoration: BoxDecoration(
          color: AppTheme.inputBg(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.cardBorderColor(context)),
        ),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text(
              'No period sections created yet',
              style: TextStyle(fontSize: 12.5, color: Colors.orange.shade800),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<_Period>(
      initialValue: _selectedPeriod,
      focusNode: _periodSectionFocusNode,
      isExpanded: true,
      dropdownColor: AppTheme.surfaceBg(context),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Select period section',
        hintStyle: TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary(context),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        prefixIcon: Icon(
          LucideIcons.calendarRange,
          size: 16,
          color: AppTheme.accent(context),
        ),
        suffixIcon: _selectedPeriod != null
            ? IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  setState(() => _selectedPeriod = null);
                },
              )
            : null,
      ),
      items: _periods.map((period) {
        return DropdownMenuItem<_Period>(
          value: period,
          child: Text(
            period.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(context),
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _selectedPeriod = value);
      },
    );
  }

  // ── Totals KPI Row ────────────────────────────────────────────────────────
  Widget _buildTotalsKpiRow(
    BuildContext context,
    EditPurchaseEntryProvider provider,
  ) {
    final isMobile = context.isMobile;

    final cards = [
      _buildKpiCard(
        label: 'Amount (Ex-VAT)',
        value: 'SAR ${provider.getTotalAmountExVat().toStringAsFixed(2)}',
        icon: LucideIcons.calculator,
        color: const Color(0xFF3B82F6),
      ),
      _buildKpiCard(
        label: 'Total VAT',
        value: 'SAR ${provider.getTotalVatAmount().toStringAsFixed(2)}',
        icon: LucideIcons.percent,
        color: const Color(0xFFF59E0B),
      ),
      _buildKpiCard(
        label: 'Grand Total',
        value: 'SAR ${provider.getTotalAmountIncVat().toStringAsFixed(2)}',
        icon: LucideIcons.badgePercent,
        color: const Color(0xFF10B981),
      ),
      _buildKpiCard(
        label: 'Bills Count',
        value: '${provider.items.length}',
        icon: LucideIcons.receipt,
        color: AppTheme.accent(context),
      ),
    ];

    if (isMobile) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final itemW = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cards
                .map((c) => SizedBox(width: itemW, child: c))
                .toList(),
          );
        },
      );
    }

    return Row(
      children: cards
          .map(
            (c) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: c,
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
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Entries Table ─────────────────────────────────────────────────────────
  Widget _buildEntriesTable(EditPurchaseEntryProvider provider) {
    if (provider.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.layers,
                size: 36,
                color: AppTheme.textSecondary(context),
              ),
              const SizedBox(height: 10),
              Text(
                'No line items in this invoice yet',
                style: TextStyle(
                  color: AppTheme.textSecondary(context),
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fill the entry form and click "Add to Entry"',
                style: TextStyle(
                  color: AppTheme.textMuted(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sortedItems = _getSortedItems(provider.items);
    var latestCreatedItem = provider.items.first;
    for (final item in provider.items.skip(1)) {
      if (!item.createdAt.isBefore(latestCreatedItem.createdAt)) {
        latestCreatedItem = item;
      }
    }
    final tableItems = sortedItems;
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
        width: 150,
        minWidth: 140,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
        enableDropToResize: false,
        enableContextMenu: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'Created Date',
        field: 'createdDate',
        type: PlutoColumnType.text(),
        width: 130,
        minWidth: 120,
        readOnly: true,
        enableEditingMode: false,
        enableColumnDrag: false,
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
                  LucideIcons.pencil,
                  color: Colors.blue,
                  size: 15,
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
                  LucideIcons.trash2,
                  color: Colors.red,
                  size: 15,
                ),
                onPressed: originalIndex < 0
                    ? null
                    : () {
                        provider.removeItem(originalIndex);
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

    final rows = tableItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      return PlutoRow(
        cells: {
          'sl': PlutoCell(value: index + 1),
          'date': PlutoCell(
            value: DateFormat('dd/MM/yy h:mm a').format(item.date),
          ),
          'createdDate': PlutoCell(
            value: DateFormat('dd/MM/yy h:mm a').format(item.createdAt),
          ),
          'invoiceNo': PlutoCell(value: item.invoiceNo),
          'supplier': PlutoCell(value: item.supplierName),
          'vatNumber': PlutoCell(
            value: item.vatNumber.isNotEmpty ? item.vatNumber : '—',
          ),
          'amountExVat': PlutoCell(value: item.amountExVat),
          'vatAmount': PlutoCell(value: item.vatAmount),
          'totalIncVat': PlutoCell(value: item.totalIncVat),
          'actions': PlutoCell(value: item.id),
        },
      );
    }).toList();

    return Column(
      children: [
        Expanded(
          child: PlutoGrid(
            key: ValueKey(
              jsonEncode(
                tableItems
                    .map(
                      (item) => [
                        item.id,
                        item.date.toIso8601String(),
                        item.createdAt.toIso8601String(),
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
                activatedColor: AppTheme.accent(
                  context,
                ).withValues(alpha: 0.12),
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
          ),
        ),
        const SizedBox(height: 8),
        _buildLatestCreatedEntryRow(provider, latestCreatedItem),
      ],
    );
  }

  Widget _buildLatestCreatedEntryRow(
    EditPurchaseEntryProvider provider,
    PurchaseItem item,
  ) {
    final itemIndex = provider.items.indexOf(item);
    final accent = AppTheme.accent(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.fiber_new_outlined, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Latest created',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  item.invoiceNo,
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item.supplierName,
                  style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: 11,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yy h:mm a').format(item.createdAt),
                  style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: 11,
                  ),
                ),
                Text(
                  'Total: ${item.totalIncVat.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit latest entry',
            visualDensity: VisualDensity.compact,
            onPressed: itemIndex < 0 ? null : () => _startEditEntry(itemIndex),
            icon: const Icon(LucideIcons.pencil, size: 16, color: Colors.blue),
          ),
          IconButton(
            tooltip: 'Delete latest entry',
            visualDensity: VisualDensity.compact,
            onPressed: itemIndex < 0
                ? null
                : () {
                    provider.removeItem(itemIndex);
                    if (_editingIndex == itemIndex) {
                      setState(_clearEntryFields);
                    }
                    _showMsg('Entry removed', Colors.red);
                  },
            icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.red),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) => Text(
    title,
    style: TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: AppTheme.textPrimary(context),
    ),
  );

  Widget _buildFieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimary(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: Icon(
              Icons.close,
              size: 16,
              color: AppTheme.textSecondary(context),
            ),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: AppTheme.textMuted(context),
                fontSize: 12.5,
              ),
              filled: true,
              fillColor: AppTheme.inputBg(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppTheme.cardBorderColor(context),
                ),
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 17,
                color: AppTheme.textSecondary(context),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
            ),
          ),
        ),
        if (showDropdown && items.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.cardBorderColor(context)),
              borderRadius: BorderRadius.circular(8),
              color: AppTheme.surfaceBg(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: AppTheme.isDark(context) ? 0.3 : 0.08,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView(shrinkWrap: true, children: items),
          ),
      ],
    );
  }
}
