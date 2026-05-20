import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/customer_model.dart';
import 'models/supplier_model.dart';
import 'models/purchase_entry_model.dart';
import 'providers/customer_provider.dart';
import 'providers/supplier_provider.dart';
import 'providers/purchase_entry_provider.dart';

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
  final _invoiceNoController     = TextEditingController();
  final _amountExVatController   = TextEditingController();
  final _vatRateController       = TextEditingController(text: '15');
  final _vatAmountController     = TextEditingController();
  final _totalIncVatController   = TextEditingController();
  final _customerSearchController = TextEditingController();
  final _supplierSearchController = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  Customer? _selectedCustomer;
  Supplier? _selectedSupplier;
  DateTime? _invoiceDate;

  List<Customer> _filteredCustomers = [];
  List<Supplier> _filteredSuppliers = [];

  bool _showCustomerDropdown = false;
  bool _showSupplierDropdown = false;
  bool _isSaving = false;

  // ── Period sections from Firestore ────────────────────────────────────────
  List<_Period> _periods = [];
  bool _periodsLoading = true;
  _Period? _selectedPeriod;

  bool get _isEditMode => widget.invoice != null;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchPeriods();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CustomerProvider>().fetchCustomers();
      await context.read<SupplierProvider>().fetchSuppliers();
      if (_isEditMode) _populateFromInvoice();
    });
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
    if ( _periods.isNotEmpty) {
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
          taxNumber: '');
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
          address: '');
    }

    if (inv.items.isNotEmpty) {
      final last = inv.items.last;
      _amountExVatController.text = last.amountExVat.toStringAsFixed(2);
      _vatRateController.text     = last.vatRate.toStringAsFixed(0);
      _vatAmountController.text   = last.vatAmount.toStringAsFixed(2);
      _totalIncVatController.text = last.totalIncVat.toStringAsFixed(2);
    }

    setState(() {});
  }

  @override
  void dispose() {
    _invoiceNoController.dispose();
    _amountExVatController.dispose();
    _vatRateController.dispose();
    _vatAmountController.dispose();
    _totalIncVatController.dispose();
    _customerSearchController.dispose();
    _supplierSearchController.dispose();
    super.dispose();
  }

  // ── Customer search ───────────────────────────────────────────────────────
  void _filterCustomers(String query) {
    final customers = context.read<CustomerProvider>().customers;
    setState(() {
      _filteredCustomers = query.isEmpty
          ? customers
          : customers
              .where((c) =>
                  c.name.toLowerCase().contains(query.toLowerCase()) ||
                  c.phone.contains(query))
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
              .where((s) =>
                  s.name.toLowerCase().contains(query.toLowerCase()) ||
                  s.phone.contains(query))
              .toList();
      _showSupplierDropdown = true;
    });
  }

  void _selectSupplier(Supplier s) => setState(() {
        _selectedSupplier = s;
        _showSupplierDropdown = false;
        _supplierSearchController.clear();
      });

  // ── VAT calculations ──────────────────────────────────────────────────────
  void _calculateFromAmountExVat() {
    final amount = double.tryParse(_amountExVatController.text) ?? 0;
    final rate   = double.tryParse(_vatRateController.text)     ?? 0;
    setState(() {
      _vatAmountController.text   = (amount * rate / 100).toStringAsFixed(2);
      _totalIncVatController.text = (amount + amount * rate / 100).toStringAsFixed(2);
    });
  }

  void _calculateFromVatAmount() {
    final vat  = double.tryParse(_vatAmountController.text) ?? 0;
    final rate = double.tryParse(_vatRateController.text)   ?? 0;
    if (rate == 0) return;
    final amount = vat / (rate / 100);
    setState(() {
      _amountExVatController.text = amount.toStringAsFixed(2);
      _totalIncVatController.text = (amount + vat).toStringAsFixed(2);
    });
  }

  void _calculateFromTotal() {
    final total = double.tryParse(_totalIncVatController.text) ?? 0;
    final rate  = double.tryParse(_vatRateController.text)     ?? 0;
    if (rate == 0) return;
    final amount = total / (1 + rate / 100);
    setState(() {
      _amountExVatController.text = amount.toStringAsFixed(2);
      _vatAmountController.text   = (total - amount).toStringAsFixed(2);
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
    if (picked != null) setState(() => _invoiceDate = picked);
  }

  // ── Add entry ─────────────────────────────────────────────────────────────
  void _addEntry() {
    if (_selectedCustomer == null) { _showMsg('Please select a customer', Colors.orange); return; }
    if (_selectedSupplier == null) { _showMsg('Please select a supplier', Colors.orange); return; }
    if (_invoiceNoController.text.trim().isEmpty) { _showMsg('Please enter invoice number', Colors.orange); return; }
    if (_invoiceDate == null) { _showMsg('Please select invoice date', Colors.orange); return; }

    final amountExVat = double.tryParse(_amountExVatController.text) ?? 0;
    if (amountExVat <= 0) { _showMsg('Amount must be greater than 0', Colors.orange); return; }

    context.read<PurchaseEntryProvider>().addItem(
      date:          _invoiceDate!,
      invoiceNo:     _invoiceNoController.text.trim(),
      supplierName:  _selectedSupplier!.name,
      supplierId:    _selectedSupplier!.id!,
      vatNumber:     _selectedSupplier!.vatNumber,
      amountExVat:   amountExVat,
      vatRate:       double.tryParse(_vatRateController.text)   ?? 0,
      vatAmount:     double.tryParse(_vatAmountController.text)  ?? 0,
      totalIncVat:   double.tryParse(_totalIncVatController.text) ?? 0,
        // ← save period ID
    );

    _amountExVatController.clear();
    _vatAmountController.clear();
    _totalIncVatController.clear();
    _vatRateController.text = '15';
    _showMsg('Entry added', Colors.green);
  }

  // ── Save (create or update) ───────────────────────────────────────────────
  Future<void> _saveInvoice() async {
    final provider = context.read<PurchaseEntryProvider>();

    if (provider.items.isEmpty) { _showMsg('Please add at least one entry', Colors.orange); return; }
    if (_invoiceNoController.text.trim().isEmpty) { _showMsg('Please enter invoice number', Colors.orange); return; }
    if (_invoiceDate == null) { _showMsg('Please select invoice date', Colors.orange); return; }
    if (_selectedCustomer == null) { _showMsg('Please select a customer', Colors.orange); return; }
    if (_selectedSupplier == null) { _showMsg('Please select a supplier', Colors.orange); return; }

    setState(() => _isSaving = true);

    bool success;

    if (_isEditMode) {
      success = await provider.updateInvoice(
        invoiceId: widget.invoice!.id,
        customerId: _selectedCustomer!.id,
        customerName: _selectedCustomer!.name,
        customerVatNumber: _selectedCustomer!.taxNumber,
        supplierId: _selectedSupplier!.id!,
        supplierName: _selectedSupplier!.name,
        invoiceNo: _invoiceNoController.text.trim(),
        invoiceDate: _invoiceDate!,
        items: provider.items,
        periodSectionId: _selectedPeriod?.id,
        periodSectionName: _selectedPeriod?.name,
      );
      if (success && mounted) {
        _showMsg('Invoice updated successfully!', Colors.green);
        provider.clearItems();
        Navigator.pop(context, true);
      }
    } else {
      success = await provider.saveInvoice(
        customerId: _selectedCustomer!.id,
        customerName: _selectedCustomer!.name,
        customerVatNumber: _selectedCustomer!.taxNumber,
        supplierId: _selectedSupplier!.id!,
        supplierName: _selectedSupplier!.name,
        invoiceNo: _invoiceNoController.text.trim(),
        invoiceDate: _invoiceDate!,
        periodSectionId: _selectedPeriod?.id,
        periodSectionName: _selectedPeriod?.name,
      );
      if (success && mounted) {
        _showMsg('Invoice saved successfully!', Colors.green);
        _resetForm();
      }
    }

    if (!success && mounted) {
      _showMsg(provider.errorMessage ?? 'Error saving invoice', Colors.red);
    }
    setState(() => _isSaving = false);
  }

  void _resetForm() {
    _invoiceNoController.clear();
    _amountExVatController.clear();
    _vatAmountController.clear();
    _totalIncVatController.clear();
    _vatRateController.text = '15';
    _customerSearchController.clear();
    _supplierSearchController.clear();
    setState(() {
      _selectedCustomer = null;
      _selectedSupplier = null;
      _invoiceDate      = null;
      _selectedPeriod   = null;
    });
    context.read<PurchaseEntryProvider>().clearItems();
  }

  void _showMsg(String msg, Color color) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        toolbarHeight: 50,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () {
                context.read<PurchaseEntryProvider>().clearItems();
                Navigator.pop(context);
              },
              child: Container(
                height: 40, width: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(
                      color: Colors.grey.shade300, blurRadius: 4)],
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Icon(Icons.keyboard_arrow_left_rounded, size: 28),
              ),
            ),
            Text(
              _isEditMode ? 'Edit Purchase Entry' : 'New Purchase Entry',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (_isEditMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Editing',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600)),
              )
            else
              const SizedBox(width: 40),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Customer ───────────────────────────────────────────────
              _buildSectionHeader('Select Customer'),
              const SizedBox(height: 10),
              if (_selectedCustomer != null)
                _buildSelectedCard(
                  title: _selectedCustomer!.name,
                  subtitle: _selectedCustomer!.phone,
                  color: Colors.blue.shade50,
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
                  hintText: 'Search customer...',
                  onChanged: _filterCustomers,
                  showDropdown: _showCustomerDropdown,
                  items: _filteredCustomers.map((c) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(c.name[0].toUpperCase(),
                          style: TextStyle(color: Colors.blue.shade700)),
                    ),
                    title: Text(c.name),
                    subtitle: Text(c.phone),
                    onTap: () => _selectCustomer(c),
                  )).toList(),
                ),

              const SizedBox(height: 8),

              // ── Supplier ───────────────────────────────────────────────
              // if (_selectedCustomer != null) ...[
                _buildSectionHeader('Select Supplier'),
                const SizedBox(height: 10),
                if (_selectedSupplier != null)
                  _buildSelectedCard(
                    title: _selectedSupplier!.name,
                    subtitle: 'VAT: ${_selectedSupplier!.vatNumber}',
                    color: Colors.green.shade50,
                    accentColor: Colors.green.shade700,
                    icon: Icons.store_outlined,
                    onClear: () => setState(() => _selectedSupplier = null),
                  )
                else
                  _buildSearchField(
                    controller: _supplierSearchController,
                    hintText: 'Search supplier...',
                    onChanged: _filterSuppliers,
                    showDropdown: _showSupplierDropdown,
                    items: _filteredSuppliers.map((s) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade100,
                        child: Text(s.name[0].toUpperCase(),
                            style: TextStyle(color: Colors.green.shade700)),
                      ),
                      title: Text(s.name),
                      subtitle: Text('VAT: ${s.vatNumber}'),
                      onTap: () => _selectSupplier(s),
                    )).toList(),
                  ),
                const SizedBox(height: 8),
                _buildFieldLabel('Period Section'),
                _periodsLoading
                    ? Container(
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      )
                    : _periods.isEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              border:
                                  Border.all(color: Colors.orange.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'No period sections created yet',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange.shade800),
                              ),
                            ]),
                          )
                        : DropdownButtonFormField<_Period>(
                            value: _selectedPeriod,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: 'Select period section',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical:0),
                              prefixIcon: const Icon(
                                  Icons.date_range_outlined,
                                  size: 18),
                              // Clear button
                              suffixIcon: _selectedPeriod != null
                                  ? IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () => setState(
                                          () => _selectedPeriod = null),
                                    )
                                  : null,
                            ),
                            items: _periods.map((period) {
                              return DropdownMenuItem<_Period>(
                                value: period,
                                child: Row(children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4F8EF7),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(period.name,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600)),
                                        // Text(period.range,
                                        //     style: TextStyle(
                                        //         fontSize: 11,
                                        //         color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                ]),
                              );
                            }).toList(),
                            onChanged: (value) =>
                                setState(() => _selectedPeriod = value),
                          ),

                // Show selected period badge
                 if (_selectedPeriod != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F8EF7).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF4F8EF7).withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline,
                          size: 14, color: Color(0xFF4F8EF7)),
                      const SizedBox(width: 6),
                      Text(
                        '${_selectedPeriod!.name}  ·  ${_selectedPeriod!.range}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4F8EF7),
                            fontWeight: FontWeight.w500),
                      ),
                    ]),
                  ),
                ],
              // ],
const SizedBox(height: 8),
              // ── Invoice details ────────────────────────────────────────
              // if (_selectedSupplier != null) ...[
                _buildSectionHeader('Invoice Details'),
                const SizedBox(height: 8),

                // Invoice No + Date
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Invoice Number *'),
                        TextFormField(
                          controller: _invoiceNoController,
                          decoration: InputDecoration(
                            hintText: 'Invoice No',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Purchase Date *'),
                        GestureDetector(
                          onTap: _pickInvoiceDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              prefixIcon: const Icon(Icons.calendar_today, size: 18),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                            child: Text(
                              _invoiceDate != null
                                  ? DateFormat('dd/MM/yyyy').format(_invoiceDate!)
                                  : 'Select date',
                              style: TextStyle(
                                  color: _invoiceDate != null
                                      ? Colors.black
                                      : Colors.grey.shade500,
                                  fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),

                const SizedBox(height: 8),

                // ── Period Section dropdown (from Firestore) ───────────
                
               

                // const SizedBox(height: 8),

                // ── Amount fields ────────────────────────────────────────
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Amount (Excl. VAT) *'),
                        TextFormField(
                          controller: _amountExVatController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => _calculateFromAmountExVat(),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('VAT Rate (%)'),
                        TextFormField(
                          controller: _vatRateController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => _calculateFromAmountExVat(),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.percent_outlined, size: 18),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 8),

                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('VAT Amount'),
                        TextFormField(
                          controller: _vatAmountController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => _calculateFromVatAmount(),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Total (Incl. VAT)'),
                        TextFormField(
                          controller: _totalIncVatController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => _calculateFromTotal(),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // ── Add Entry button ─────────────────────────────────────
                GestureDetector(
                  onTap: _addEntry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6)
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 20),
                        SizedBox(width: 6),
                        Text('Add Entry',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Entries table ────────────────────────────────────────
                _buildSectionHeader('Purchase Entries'),
                const SizedBox(height: 10),
                _buildEntriesTable(),

                const SizedBox(height: 16),

                _buildTotalsSummary(),

                const SizedBox(height: 24),

                // ── Save / Cancel buttons ────────────────────────────────
                SafeArea(
                  child: Row(children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          context.read<PurchaseEntryProvider>().clearItems();
                          Navigator.pop(context);
                        },
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveInvoice,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade900,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white)))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_isEditMode
                                      ? Icons.update_rounded
                                      : Icons.save_rounded),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isEditMode
                                        ? 'Update Invoice'
                                        : 'Save Invoice',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),
              // ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Entries table ─────────────────────────────────────────────────────────
  Widget _buildEntriesTable() {
    return Consumer<PurchaseEntryProvider>(
      builder: (context, provider, _) {
        if (provider.items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Text('No entries added yet',
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            border: TableBorder.all(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8)),
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
            columns: const [
              DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Invoice No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('VAT NO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              
              DataColumn(label: Text('Amount (Excl. VAT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
              DataColumn(label: Text('VAT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
              DataColumn(label: Text('Total (Incl. VAT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
              DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
            rows: List.generate(provider.items.length, (index) {
              final item = provider.items[index];
              return DataRow(
                color: WidgetStateProperty.all(
                    index.isEven ? Colors.grey.shade50 : Colors.white),
                cells: [
                  DataCell(Text('${index + 1}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(DateFormat('dd/MM/yyyy').format(item.date), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(item.invoiceNo, style: const TextStyle(fontSize: 12))),
                  DataCell(SizedBox(
                    width: 110,
                    child: Text(item.supplierName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 12)),
                  )),
                  DataCell(Text(item.vatNumber, style: const TextStyle(fontSize: 12))),
                  DataCell(Align(
                    alignment: Alignment.centerRight,
                    child: Text(item.amountExVat.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 12)),
                  )),
                  DataCell(Align(
                    alignment: Alignment.centerRight,
                    child: Text(item.vatAmount.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 12, color: Colors.green)),
                  )),
                  DataCell(Align(
                    alignment: Alignment.centerRight,
                    child: Text(item.totalIncVat.toStringAsFixed(2),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple)),
                  )),
                  DataCell(IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    onPressed: () {
                      provider.removeItem(index);
                      _showMsg('Entry removed', Colors.red);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  // ── Totals summary ────────────────────────────────────────────────────────
  Widget _buildTotalsSummary() {
    return Consumer<PurchaseEntryProvider>(
      builder: (context, provider, _) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: Border.all(color: Colors.blue.shade100),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _totalItem('Excl. VAT',
                provider.getTotalAmountExVat().toStringAsFixed(2),
                Colors.blue),
            Container(width: 1, height: 36, color: Colors.blue.shade100),
            _totalItem('VAT',
                provider.getTotalVatAmount().toStringAsFixed(2),
                Colors.green),
            Container(width: 1, height: 36, color: Colors.blue.shade100),
            _totalItem('Grand Total',
                provider.getTotalAmountIncVat().toStringAsFixed(2),
                Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _totalItem(String label, String value, Color color) => Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      );

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) => Text(title,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87));

  Widget _buildFieldLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
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
        border: Border.all(color: accentColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: accentColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints()),
      ]),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hintText,
    required Function(String) onChanged,
    required bool showDropdown,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.search),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView(shrinkWrap: true, children: items),
          ),
      ],
    );
  }
}