import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase_entry_model.dart';
import '../services/activity_log_service.dart';

class PurchaseEntryProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<PurchaseItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<PurchaseItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  // ── Add item to local list ────────────────────────────────────────────────
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

  // ── Remove item from local list ───────────────────────────────────────────
  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  // ── Clear all local items ─────────────────────────────────────────────────
  void clearItems() {
    _items.clear();
    notifyListeners();
  }

  // ── Update an existing local item by index ──────────────────────────────
  /// Returns true if update succeeded, false if index invalid or duplicate
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

  // ── Save NEW invoice ──────────────────────────────────────────────────────
  Future<bool> saveInvoice({
    required String customerId,
    required String customerName,
    required String customerVatNumber,
    required String supplierId,
    required String supplierName,
    required String invoiceNo,
    required DateTime invoiceDate,
    String? periodSectionId,
    String? periodSectionName,
    String? invoiceId,
    bool clearItemsOnSuccess = true,
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

      final customInvoiceId =
          invoiceId ?? _firestore.collection('purchase_invoices').doc().id;
      final invoiceRef = _firestore
          .collection('purchase_invoices')
          .doc(customInvoiceId);

      // Save invoice header
      final normalizedInvoiceNo = invoiceNo.trim();
      await invoiceRef.set({
        'id': customInvoiceId,
        'customerId': customerId,
        'customerName': customerName,
        'customerVatNumber': customerVatNumber,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'invoiceNo': normalizedInvoiceNo,
        'invoiceDate': Timestamp.fromDate(invoiceDate),
        'totalAmountExVat': getTotalAmountExVat(),
        'totalVatAmount': getTotalVatAmount(),
        'totalAmountIncVat': getTotalAmountIncVat(),
        'itemCount': _items.length,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'periodSectionId': periodSectionId,
        'periodSectionName': periodSectionName,
      });

      // Save items using batch write (atomic + faster)
      final batch = _firestore.batch();
      for (final item in _items) {
        final itemId = item.id.isNotEmpty
            ? item.id
            : DateTime.now().millisecondsSinceEpoch.toString();
        final itemRef = invoiceRef.collection('items').doc(itemId);
        batch.set(itemRef, {...item.toMap(), 'id': itemId});
      }
      await batch.commit();
      await ActivityLogService.log(
        action: 'add',
        entity: 'purchase_invoice',
        entityId: customInvoiceId,
        details: {
          'invoiceNo': normalizedInvoiceNo,
          'customerName': customerName,
        },
      );

      if (clearItemsOnSuccess) {
        _items.clear();
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error saving invoice: ${_getErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Update EXISTING invoice ───────────────────────────────────────────────
  Future<bool> updateInvoice({
    required String invoiceId,
    required String customerId,
    required String customerName,
    required String customerVatNumber,
    required String supplierId,
    required String supplierName,
    required String invoiceNo,
    required DateTime invoiceDate,
    required List<PurchaseItem> items,
    String? periodSectionId,
    String? periodSectionName,
  }) async {
    if (items.isEmpty) {
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

      // Recalculate totals from provided items
      final totalExVat = items.fold(0.0, (sum, item) => sum + item.amountExVat);
      final totalVat = items.fold(0.0, (sum, item) => sum + item.vatAmount);
      final totalIncVat = items.fold(
        0.0,
        (sum, item) => sum + item.totalIncVat,
      );

      // Update invoice header
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
        'itemCount': items.length,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'periodSectionId': periodSectionId,
        'periodSectionName': periodSectionName,
      });

      // Delete all existing items first
      final existingItems = await invoiceRef.collection('items').get();
      final deleteBatch = _firestore.batch();
      for (final doc in existingItems.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();

      // Write updated items
      final addBatch = _firestore.batch();
      for (final item in items) {
        final itemId = item.id.isNotEmpty
            ? item.id
            : DateTime.now().millisecondsSinceEpoch.toString();
        final itemRef = invoiceRef.collection('items').doc(itemId);
        addBatch.set(itemRef, {...item.toMap(), 'id': itemId});
      }
      await addBatch.commit();
      await ActivityLogService.log(
        action: 'edit',
        entity: 'purchase_invoice',
        entityId: invoiceId,
        details: {
          'invoiceNo': normalizedInvoiceNo,
          'customerName': customerName,
        },
      );

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

  // ── Check invoice number uniqueness ──────────────────────────────────────
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

  // ── Delete invoice (header + subcollection items) ─────────────────────────
  Future<bool> deleteInvoice(String invoiceId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final invoiceRef = _firestore
          .collection('purchase_invoices')
          .doc(invoiceId);

      // Delete subcollection items first (Firestore doesn't cascade)
      final itemsSnapshot = await invoiceRef.collection('items').get();
      final batch = _firestore.batch();
      for (final doc in itemsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete the invoice document
      await invoiceRef.delete();
      await ActivityLogService.log(
        action: 'delete',
        entity: 'purchase_invoice',
        entityId: invoiceId,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error deleting invoice: ${_getErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Fetch invoices by customer ────────────────────────────────────────────
  Future<List<PurchaseInvoice>> fetchInvoicesByCustomer(
    String customerId,
  ) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final snapshot = await _firestore
          .collection('purchase_invoices')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();

      List<PurchaseInvoice> invoices = [];
      for (final doc in snapshot.docs) {
        final itemsSnapshot = await doc.reference.collection('items').get();
        final items = itemsSnapshot.docs
            .map((d) => PurchaseItem.fromMap(d.data()))
            .toList();
        invoices.add(PurchaseInvoice.fromMap(doc.data(), items));
      }

      _isLoading = false;
      notifyListeners();
      return invoices;
    } catch (e) {
      _errorMessage = 'Error fetching invoices: ${_getErrorMessage(e)}';
      debugPrint(_errorMessage);
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  // ── Fetch ALL invoices ────────────────────────────────────────────────────
  Future<List<PurchaseInvoice>> fetchAllInvoices() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final snapshot = await _firestore
          .collection('purchase_invoices')
          .orderBy('createdAt', descending: true)
          .get();

      List<PurchaseInvoice> invoices = [];
      for (final doc in snapshot.docs) {
        try {
          final itemsSnapshot = await doc.reference.collection('items').get();
          final items = itemsSnapshot.docs
              .map((d) => PurchaseItem.fromMap(d.data()))
              .toList();
          final invoice = PurchaseInvoice.fromMap(doc.data(), items);
          invoices.add(
            PurchaseInvoice(
              id: doc.id,
              customerId: invoice.customerId,
              customerName: invoice.customerName,
              supplierId: invoice.supplierId,
              supplierName: invoice.supplierName,
              customerVatNumber: invoice.customerVatNumber,
              invoiceNo: invoice.invoiceNo,
              invoiceDate: invoice.invoiceDate,
              items: items,
              createdAt: invoice.createdAt,
              periodSectionName: invoice.periodSectionName,
              periodSectionId: invoice.periodSectionId,
            ),
          );
        } catch (e) {
          debugPrint('Error parsing invoice ${doc.id}: $e');
        }
      }

      _isLoading = false;
      notifyListeners();
      return invoices;
    } catch (e) {
      _errorMessage = 'Error fetching all invoices: ${_getErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  // ── Clear error ───────────────────────────────────────────────────────────
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
