import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase_entry_model.dart';

/// Provider responsible for EDITING an existing purchase invoice.
///
/// Flow:
///   1. Call [fetchInvoiceById] with the invoice's Firestore doc id — this
///      loads the invoice header + its `items` subcollection into local
///      state ([items], [originalInvoice]).
///   2. Use [addItem] / [updateItem] / [removeItem] to modify the local
///      working copy (nothing touches Firestore yet).
///   3. Call [updateInvoice] to persist the header + a full replace of the
///      `items` subcollection back to Firestore.
class EditPurchaseEntryProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<PurchaseItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingInvoice = false;
  String? _errorMessage;
  PurchaseInvoice? _originalInvoice;

  List<PurchaseItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get isLoadingInvoice => _isLoadingInvoice;
  String? get errorMessage => _errorMessage;
  PurchaseInvoice? get originalInvoice => _originalInvoice;

  // Helper method to safely convert exceptions to strings
  String _getErrorMessage(dynamic error) {
    try {
      if (error is FirebaseException) {
        return 'Firebase Error: ${error.message}';
      }
      return error.toString();
    } catch (_) {
      return 'An unknown error occurred';
    }
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  // ── Load an existing invoice (header + items) from Firestore ─────────────
  /// Returns true on success. On failure, [errorMessage] is populated and
  /// false is returned.
  Future<bool> fetchInvoiceById(String invoiceId) async {
    try {
      _isLoadingInvoice = true;
      _errorMessage = null;
      notifyListeners();

      final invoiceDoc = await _firestore
          .collection('purchase_invoices')
          .doc(invoiceId)
          .get();

      if (!invoiceDoc.exists || invoiceDoc.data() == null) {
        _errorMessage = 'Invoice not found';
        _isLoadingInvoice = false;
        notifyListeners();
        return false;
      }

      final data = invoiceDoc.data()!;

      final itemsSnapshot = await invoiceDoc.reference
          .collection('items')
          .get();
      final loadedItems = itemsSnapshot.docs
          .map((d) => PurchaseItem.fromMap(d.data()))
          .toList();

      _originalInvoice = PurchaseInvoice(
        id: invoiceDoc.id,
        customerId: (data['customerId'] as String?) ?? '',
        customerName: (data['customerName'] as String?) ?? '',
        customerVatNumber: (data['customerVatNumber'] as String?) ?? '',
        supplierId: (data['supplierId'] as String?) ?? '',
        supplierName: (data['supplierName'] as String?) ?? '',
        invoiceNo: (data['invoiceNo'] as String?) ?? '',
        invoiceDate: _parseDate(data['invoiceDate']),
        items: loadedItems,
        createdAt: _parseDate(data['createdAt']),
        periodSectionName: (data['periodSectionName'] as String?) ?? '',
        periodSectionId: (data['periodSectionId'] as String?) ?? '',
      );

      _items
        ..clear()
        ..addAll(loadedItems);

      _isLoadingInvoice = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error loading invoice: ${_getErrorMessage(e)}';
      _isLoadingInvoice = false;
      notifyListeners();
      return false;
    }
  }

  // ── Add item to local working list ────────────────────────────────────────
  bool addItem({
    required DateTime date,
    required String invoiceNo,
    required String supplierName,
    required String supplierId,
    required String vatNumber,
    required double amountExVat,
    required double vatRate,
    required double vatAmount,
    required double totalIncVat,
  }) {
    final trimmedInvoiceNo = invoiceNo.trim();
    final normalizedSupplierName = supplierName.trim().toLowerCase();
    final existsLocally = _items.any(
      (it) =>
          it.invoiceNo.trim() == trimmedInvoiceNo &&
          it.supplierName.trim().toLowerCase() == normalizedSupplierName,
    );
    if (existsLocally) return false;

    final customItemId = _firestore.collection('purchase_invoices').doc().id;

    _items.add(
      PurchaseItem(
        id: customItemId,
        date: date,
        invoiceNo: trimmedInvoiceNo,
        supplierName: supplierName,
        supplierId: supplierId,
        vatNumber: vatNumber,
        amountExVat: amountExVat,
        vatRate: vatRate,
        vatAmount: vatAmount,
        totalIncVat: totalIncVat,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  // ── Remove item from local working list ───────────────────────────────────
  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  // ── Clear local working list ──────────────────────────────────────────────
  void clearItems() {
    _items.clear();
    notifyListeners();
  }

  // ── Update an existing local item by index ────────────────────────────────
  /// Returns true if update succeeded, false if index invalid or duplicate.
  bool updateItem(
    int index, {
    required DateTime date,
    required String invoiceNo,
    required String supplierName,
    required String supplierId,
    required String vatNumber,
    required double amountExVat,
    required double vatRate,
    required double vatAmount,
    required double totalIncVat,
  }) {
    if (index < 0 || index >= _items.length) return false;

    final trimmed = invoiceNo.trim();
    final normalizedSupplierName = supplierName.trim().toLowerCase();
    final exists = _items.asMap().entries.any(
      (e) =>
          e.key != index &&
          e.value.invoiceNo.trim() == trimmed &&
          e.value.supplierName.trim().toLowerCase() == normalizedSupplierName,
    );
    if (exists) return false;

    final old = _items[index];
    _items[index] = PurchaseItem(
      id: old.id,
      date: date,
      invoiceNo: trimmed,
      supplierName: supplierName,
      supplierId: supplierId,
      vatNumber: vatNumber,
      amountExVat: amountExVat,
      vatRate: vatRate,
      vatAmount: vatAmount,
      totalIncVat: totalIncVat,
      createdAt: old.createdAt,
    );
    notifyListeners();
    return true;
  }

  // ── Totals ────────────────────────────────────────────────────────────────
  double getTotalAmountExVat() =>
      _items.fold(0.0, (sum, item) => sum + item.amountExVat);

  double getTotalVatAmount() =>
      _items.fold(0.0, (sum, item) => sum + item.vatAmount);

  double getTotalAmountIncVat() =>
      _items.fold(0.0, (sum, item) => sum + item.totalIncVat);

  int getTotalBills() => _items.length;

  // ── Commit the update to Firestore ────────────────────────────────────────
  Future<bool> updateInvoice({
    required String invoiceId,
    required String customerId,
    required String customerName,
    required String customerVatNumber,
    required String supplierId,
    required String supplierName,
    required String invoiceNo,
    required DateTime invoiceDate,
    String? periodSectionId,
    String? periodSectionName,
  }) async {
    if (_items.isEmpty) {
      _errorMessage = 'Please add at least one item';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final invoiceRef = _firestore
          .collection('purchase_invoices')
          .doc(invoiceId);

      // Recalculate totals from current local items
      final totalExVat = _items.fold(
        0.0,
        (sum, item) => sum + item.amountExVat,
      );
      final totalVat = _items.fold(0.0, (sum, item) => sum + item.vatAmount);
      final totalIncVat = _items.fold(
        0.0,
        (sum, item) => sum + item.totalIncVat,
      );

      final normalizedInvoiceNo = invoiceNo.trim();
      await invoiceRef.update({
        'customerId': customerId,
        'customerName': customerName,
        'customerVatNumber': customerVatNumber,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'invoiceNo': normalizedInvoiceNo,
        'invoiceDate': Timestamp.fromDate(invoiceDate),
        'totalAmountExVat': totalExVat,
        'totalVatAmount': totalVat,
        'totalAmountIncVat': totalIncVat,
        'itemCount': _items.length,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'periodSectionId': periodSectionId,
        'periodSectionName': periodSectionName,
      });

      // Delete all existing items first (subcollection isn't cascaded)
      final existingItems = await invoiceRef.collection('items').get();
      final deleteBatch = _firestore.batch();
      for (final doc in existingItems.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();

      // Write the updated items
      final addBatch = _firestore.batch();
      for (final item in _items) {
        final itemId = item.id.isNotEmpty
            ? item.id
            : DateTime.now().millisecondsSinceEpoch.toString();
        final itemRef = invoiceRef.collection('items').doc(itemId);
        addBatch.set(itemRef, {...item.toMap(), 'id': itemId});
      }
      await addBatch.commit();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error updating invoice: ${_getErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Check invoice number uniqueness (excluding the invoice being edited) ──
  Future<bool> invoiceNumberExists(
    String invoiceNo, {
    required String supplierName,
    String? excludeInvoiceId,
  }) async {
    try {
      _errorMessage = null;
      final trimmedInvoiceNo = invoiceNo.trim();
      final query = _firestore
          .collection('purchase_invoices')
          .where('invoiceNo', isEqualTo: trimmedInvoiceNo);
      final snapshot = await query.get();
      final normalizedSupplierName = supplierName.trim().toLowerCase();

      for (final doc in snapshot.docs) {
        if (excludeInvoiceId != null && doc.id == excludeInvoiceId) {
          continue;
        }
        final existingSupplierName =
            (doc.data()['supplierName'] as String?)?.trim().toLowerCase() ?? '';
        if (existingSupplierName == normalizedSupplierName) return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Error checking invoice number: ${_getErrorMessage(e)}';
      notifyListeners();
      return false;
    }
  }

  // ── Reset provider state (call when leaving the edit screen) ─────────────
  void reset() {
    _items.clear();
    _originalInvoice = null;
    _errorMessage = null;
    _isLoading = false;
    _isLoadingInvoice = false;
    notifyListeners();
  }

  // ── Clear error ───────────────────────────────────────────────────────────
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
