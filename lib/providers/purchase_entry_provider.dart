import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase_entry_model.dart';

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
  void addItem({
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
    _items.add(
      PurchaseItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: date,
        invoiceNo: invoiceNo,
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

  // ── Totals ────────────────────────────────────────────────────────────────
  double getTotalAmountExVat() =>
      _items.fold(0.0, (sum, item) => sum + item.amountExVat);

  double getTotalVatAmount() =>
      _items.fold(0.0, (sum, item) => sum + item.vatAmount);

  double getTotalAmountIncVat() =>
      _items.fold(0.0, (sum, item) => sum + item.totalIncVat);

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

      final invoiceRef = _firestore.collection('purchase_invoices').doc();

      // Save invoice header
      await invoiceRef.set({
        'customerId': customerId,
        'customerName': customerName,
        'customerVatNumber': customerVatNumber,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'invoiceNo': invoiceNo,
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
        final itemRef = invoiceRef.collection('items').doc();
        batch.set(itemRef, item.toMap());
      }
      await batch.commit();

      _items.clear();
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

      final invoiceRef =
          _firestore.collection('purchase_invoices').doc(invoiceId);

      // Recalculate totals from provided items
      final totalExVat =
          items.fold(0.0, (sum, item) => sum + item.amountExVat);
      final totalVat =
          items.fold(0.0, (sum, item) => sum + item.vatAmount);
      final totalIncVat =
          items.fold(0.0, (sum, item) => sum + item.totalIncVat);

      // Update invoice header
      await invoiceRef.update({
        'customerId': customerId,
        'customerName': customerName,
        'customerVatNumber': customerVatNumber,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'invoiceNo': invoiceNo,
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
      final existingItems =
          await invoiceRef.collection('items').get();
      final deleteBatch = _firestore.batch();
      for (final doc in existingItems.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();

      // Write updated items
      final addBatch = _firestore.batch();
      for (final item in items) {
        final itemRef = invoiceRef.collection('items').doc();
        addBatch.set(itemRef, item.toMap());
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

  // ── Delete invoice (header + subcollection items) ─────────────────────────
  Future<bool> deleteInvoice(String invoiceId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final invoiceRef =
          _firestore.collection('purchase_invoices').doc(invoiceId);

      // Delete subcollection items first (Firestore doesn't cascade)
      final itemsSnapshot =
          await invoiceRef.collection('items').get();
      final batch = _firestore.batch();
      for (final doc in itemsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete the invoice document
      await invoiceRef.delete();

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
      String customerId) async {
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
        final itemsSnapshot =
            await doc.reference.collection('items').get();
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
          final itemsSnapshot =
              await doc.reference.collection('items').get();
          final items = itemsSnapshot.docs
              .map((d) => PurchaseItem.fromMap(d.data()))
              .toList();
          final invoice = PurchaseInvoice.fromMap(doc.data(), items);
          invoices.add(PurchaseInvoice(
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
          ));
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