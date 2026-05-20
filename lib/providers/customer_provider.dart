import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';

class CustomerProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Customer> get customers => _customers;
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

  // Add a new customer to Firebase
  Future<bool> addCustomer({
    required String name,
    required String phone,
    required String address,
    required String taxNumber,
    String? phone2,
    String? email,
    String? organizationName,
    String? organizationUnitName,
    String? commonName,
    String? businessCategory,
    String? registeredAddress,
    String? buildingNo,
    String? streetName,
    String? districtName,
    String? cityName,
    String? zipCode,
    String? additionalNo,
    String? unitNo,
    String? country,
    String? crNumber,
    String? zatcaUsername,
    String? zatcaPassword,
    String? periodSectionId,
    String? periodSectionName,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final id = DateTime.now().millisecondsSinceEpoch.toString();
      
      final customer = Customer(
        id: id,
        name: name,
        phone: phone,
        address: address,
        taxNumber: taxNumber,
        phone2: phone2,
        email: email,
        organizationName: organizationName,
        organizationUnitName: organizationUnitName,
        commonName: commonName,
        businessCategory: businessCategory,
        registeredAddress: registeredAddress,
        buildingNo: buildingNo,
        streetName: streetName,
        districtName: districtName,
        cityName: cityName,
        zipCode: zipCode,
        additionalNo: additionalNo,
        unitNo: unitNo,
        country: country,
        crNumber: crNumber,
        zatcaUsername: zatcaUsername,
        zatcaPassword: zatcaPassword,
        periodSectionId: periodSectionId,
        periodSectionName: periodSectionName,
        createdAt: DateTime.now(),
      );

      // Use .doc(id).set() to save with custom document ID
      await _firestore.collection('customers').doc(id).set(customer.toMap());

      _isLoading = false;
      fetchCustomers(); // Refresh the customer list after adding
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error saving customer: ${_getErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Fetch all customers from Firebase
  Future<void> fetchCustomers() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final querySnapshot =
          await _firestore.collection('customers').orderBy('createdAt', descending: true).get();

      _customers = querySnapshot.docs
          .map((doc) => Customer.fromMap(doc.data(), doc.id))
          .toList();

      _isLoading = false;
     
      notifyListeners();
      
    } catch (e) {
      _errorMessage = 'Error fetching customers: ${_getErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update a customer
  Future<bool> updateCustomer({
    required String id,
    required String name,
    required String phone,
    required String address,
    required String taxNumber,
    String? phone2,
    String? email,
    String? organizationName,
    String? organizationUnitName,
    String? commonName,
    String? businessCategory,
    String? registeredAddress,
    String? buildingNo,
    String? streetName,
    String? districtName,
    String? cityName,
    String? zipCode,
    String? additionalNo,
    String? unitNo,
    String? country,
    String? crNumber,
    String? zatcaUsername,
    String? zatcaPassword,
    String? periodSectionId,
    String? periodSectionName,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection('customers').doc(id).update({
        'name': name,
        'phone': phone,
        'phone2': phone2,
        'email': email,
        'organizationName': organizationName,
        'organizationUnitName': organizationUnitName,
        'commonName': commonName,
        'businessCategory': businessCategory,
        'address': address,
        'registeredAddress': registeredAddress,
        'buildingNo': buildingNo,
        'streetName': streetName,
        'districtName': districtName,
        'cityName': cityName,
        'zipCode': zipCode,
        'additionalNo': additionalNo,
        'unitNo': unitNo,
        'country': country,
        'taxNumber': taxNumber,
        'crNumber': crNumber,
        'zatcaUsername': zatcaUsername,
        'zatcaPassword': zatcaPassword,
        'periodSectionId': periodSectionId,
        'periodSectionName': periodSectionName,
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error updating customer: ${_getErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete a customer
  Future<bool> deleteCustomer(String id) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection('customers').doc(id).delete();

      _customers.removeWhere((customer) => customer.id == id);
      _isLoading = false;
      fetchCustomers(); 
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error deleting customer: ${_getErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Get a single customer by ID
  Future<Customer?> getCustomerById(String id) async {
    try {
      final doc = await _firestore.collection('customers').doc(id).get();
      if (doc.exists) {
        return Customer.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      _errorMessage = 'Error fetching customer: ${_getErrorMessage(e)}';
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
