import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supplier_model.dart';

class SupplierProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Supplier> _suppliers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Supplier> get suppliers => _suppliers;
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

  // Add a new supplier to Firebase
  Future<bool> addSupplier({
    
    required String name,
    required String vatNumber,
    required String phone,
    String? address,
    String? email,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final id = DateTime.now().millisecondsSinceEpoch.toString();

      final supplier = Supplier(
        id: id,
       
        name: name,
        vatNumber: vatNumber,
        phone: phone,
        address: address,
        email: email,
        createdAt: DateTime.now(),
      );

      // Use .doc(id).set() to save with custom document ID
      await _firestore.collection('suppliers').doc(id).set(supplier.toMap());

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error saving supplier: ${_getErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Fetch all suppliers for a specific customer
  Future<void> fetchSuppliers() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final querySnapshot = await _firestore
          .collection('suppliers')
         
          .orderBy('createdAt', descending: true)
          .get();

      _suppliers = querySnapshot.docs
          .map((doc) => Supplier.fromMap(doc.data(), doc.id))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error fetching suppliers: ${_getErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update a supplier
  Future<bool> updateSupplier({
    required String id,
    required String name,
    required String vatNumber,
    required String phone,
    String? address,
    String? email,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection('suppliers').doc(id).update({
        'name': name,
        'vatNumber': vatNumber,
        'phone': phone,
        'address': address,
        'email': email,
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error updating supplier: ${_getErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete a supplier
  Future<bool> deleteSupplier(String id) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection('suppliers').doc(id).delete();

      _suppliers.removeWhere((supplier) => supplier.id == id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error deleting supplier: ${_getErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Get a single supplier by ID
  Future<Supplier?> getSupplierById(String id) async {
    try {
      final doc = await _firestore.collection('suppliers').doc(id).get();
      if (doc.exists) {
        return Supplier.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      _errorMessage = 'Error fetching supplier: ${_getErrorMessage(e)}';
      notifyListeners();
      return null;
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
