import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';
import '../services/activity_log_service.dart';

enum ActivationAlertState {
  none,
  warning,
  zatcaExpired,
  softwareExpired,
  bothExpired,
}

class CustomerProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ActivationAlertState getActivationAlertState(Customer customer) {
    final now = DateTime.now();
    final warningWindowEnd = now.add(const Duration(days: 2));
    final zatcaExpiryDate = parseActivationDate(customer.financialPeriodEndDate);
    final softwareExpired = customer.softwareActivations.any((activation) {
      final expiryDate = parseActivationDate(activation['expiryDate']);
      return expiryDate != null && !expiryDate.isAfter(now);
    });
    final zatcaExpired =
        zatcaExpiryDate != null && !zatcaExpiryDate.isAfter(now);

    if (zatcaExpired && softwareExpired) {
      return ActivationAlertState.bothExpired;
    }
    if (zatcaExpired) {
      return ActivationAlertState.zatcaExpired;
    }
    if (softwareExpired) {
      return ActivationAlertState.softwareExpired;
    }

    final zatcaExpiringSoon = zatcaExpiryDate != null &&
        !zatcaExpiryDate.isAfter(warningWindowEnd);
    final softwareExpiringSoon = customer.softwareActivations.any((activation) {
      final expiryDate = parseActivationDate(activation['expiryDate']);
      return expiryDate != null && !expiryDate.isAfter(warningWindowEnd);
    });

    return zatcaExpiringSoon || softwareExpiringSoon
        ? ActivationAlertState.warning
        : ActivationAlertState.none;
  }

  ActivationAlertState getBranchActivationAlertState(Branch branch) {
    final now = DateTime.now();
    final warningWindowEnd = now.add(const Duration(days: 2));
    final zatcaExpiryDate = parseActivationDate(branch.financialPeriodEndDate);
    final softwareExpired = branch.softwareActivations.any((activation) {
      final expiryDate = parseActivationDate(activation['expiryDate']);
      return expiryDate != null && !expiryDate.isAfter(now);
    });
    final zatcaExpired =
        zatcaExpiryDate != null && !zatcaExpiryDate.isAfter(now);

    if (zatcaExpired && softwareExpired) {
      return ActivationAlertState.bothExpired;
    }
    if (zatcaExpired) {
      return ActivationAlertState.zatcaExpired;
    }
    if (softwareExpired) {
      return ActivationAlertState.softwareExpired;
    }

    final zatcaExpiringSoon = zatcaExpiryDate != null &&
        !zatcaExpiryDate.isAfter(warningWindowEnd);
    final softwareExpiringSoon = branch.softwareActivations.any((activation) {
      final expiryDate = parseActivationDate(activation['expiryDate']);
      return expiryDate != null && !expiryDate.isAfter(warningWindowEnd);
    });

    return zatcaExpiringSoon || softwareExpiringSoon
        ? ActivationAlertState.warning
        : ActivationAlertState.none;
  }

  bool isActivationExpired(Customer customer) {
    final state = getActivationAlertState(customer);
    return state == ActivationAlertState.zatcaExpired ||
        state == ActivationAlertState.softwareExpired ||
        state == ActivationAlertState.bothExpired;
  }

  DateTime? parseActivationDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // Add a new customer
  Future<bool> addCustomer({
    required String name,
    required String phone,
    required String address,
    required String taxNumber,
    required bool zatcaEnabled,
    
    String? careOf,
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
    bool cloudStorageEnabled = false,
    String? cloudFinancialPeriodStartDate,
    String? cloudFinancialPeriodEndDate,
    String? financialPeriodStartDate,
    String? financialPeriodEndDate,
    String? createdById,
    String? createdByName,
    String? periodSectionId,        // kept for backward compatibility
    String? periodSectionName,
    List<String>? usedSoftwares,
    List<Map<String, dynamic>>? softwareActivations,
    List<Staff>? staff,
    List<Branch>? branches,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final id = _firestore.collection('customers').doc().id;
      
      final customer = Customer(
        id: id,
        name: name,
        careOf: careOf,
        phone: phone,
        address: address,
        taxNumber: taxNumber,
        zatcaEnabled: zatcaEnabled,
        
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
        cloudStorageEnabled: cloudStorageEnabled,
        cloudFinancialPeriodStartDate: cloudFinancialPeriodStartDate,
        cloudFinancialPeriodEndDate: cloudFinancialPeriodEndDate,
        financialPeriodStartDate: financialPeriodStartDate,
        financialPeriodEndDate: financialPeriodEndDate,
        createdById: createdById,
        createdByName: createdByName,
        createdAt: DateTime.now(),
        usedSoftwares: usedSoftwares ?? [],
        softwareActivations: softwareActivations ?? [],
        staff: staff ?? [],
        branches: branches ?? [],
      );

      await _firestore.collection('customers').doc(id).set(customer.toMap());
      await ActivityLogService.log(
        action: 'add',
        entity: 'customer',
        entityId: id,
        details: {'name': name},
      );

      await fetchCustomers();
      return true;
    } catch (e) {
      _errorMessage = 'Error saving customer: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }


bool showAddSupplierScreen = false;

 
void toggleShowAddSupplierScreen() {
    showAddSupplierScreen = true;
    notifyListeners();
  }
  void toggleCloseShowAddSupplierScreen() {
    showAddSupplierScreen = false;
    notifyListeners();
  }
  // Update customer
  Future<bool> updateCustomer({
    required String id,
    required String name,
    required String phone,
    required String address,
    required String taxNumber,
    required bool zatcaEnabled,
    
    String? careOf,
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
    bool cloudStorageEnabled = false,
    String? cloudFinancialPeriodStartDate,
    String? cloudFinancialPeriodEndDate,
    String? financialPeriodStartDate,
    String? financialPeriodEndDate,
    required String editedById,
    required String editedByName,
    String? periodSectionId,
    String? periodSectionName,
    List<String>? usedSoftwares,
    List<Map<String, dynamic>>? softwareActivations,
    List<Staff>? staff,
    List<Branch>? branches,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final updateData = {
        'name': name,
        'careOf': careOf,
        'phone': phone,
        'address': address,
        'taxNumber': taxNumber,
        'zatcaEnabled': zatcaEnabled,
        
        'phone2': phone2,
        'email': email,
        'organizationName': organizationName,
        'organizationUnitName': organizationUnitName,
        'commonName': commonName,
        'businessCategory': businessCategory,
        'registeredAddress': registeredAddress,
        'buildingNo': buildingNo,
        'streetName': streetName,
        'districtName': districtName,
        'cityName': cityName,
        'zipCode': zipCode,
        'additionalNo': additionalNo,
        'unitNo': unitNo,
        'country': country,
        'crNumber': crNumber,
        'zatcaUsername': zatcaUsername,
        'zatcaPassword': zatcaPassword,
        'cloudStorageEnabled': cloudStorageEnabled,
        'cloudFinancialPeriodStartDate': cloudFinancialPeriodStartDate,
        'cloudFinancialPeriodEndDate': cloudFinancialPeriodEndDate,
        'financialPeriodStartDate': financialPeriodStartDate,
        'financialPeriodEndDate': financialPeriodEndDate,
        'editedById': editedById,
        'editedByName': editedByName,
        'editedDate': DateTime.now().toIso8601String(),
        'periodSectionId': periodSectionId,
        'periodSectionName': periodSectionName,
        'usedSoftwares': usedSoftwares,
        'softwareActivations': softwareActivations,
        'staff': staff?.map((s) => s.toMap()).toList(),
        'branches': branches?.map((b) => b.toMap()).toList(),
      };

      await _firestore.collection('customers').doc(id).update(
        updateData..removeWhere((key, value) => value == null)
      );
      await ActivityLogService.log(
        action: 'edit',
        entity: 'customer',
        entityId: id,
        details: {'name': name},
      );

      await fetchCustomers();
      return true;
    } catch (e) {
      _errorMessage = 'Error updating customer: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Fetch all customers
  Future<void> fetchCustomers() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final querySnapshot = await _firestore
          .collection('customers')
          .orderBy('createdAt', descending: true)
          .get();

      _customers = querySnapshot.docs
          .map((doc) => Customer.fromMap(doc.data(), doc.id))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error fetching customers: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete customer
  Future<bool> deleteCustomer(String id) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection('customers').doc(id).delete();
      await ActivityLogService.log(
        action: 'delete',
        entity: 'customer',
        entityId: id,
      );

      await fetchCustomers();
      return true;
    } catch (e) {
      _errorMessage = 'Error deleting customer: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Get single customer
  Future<Customer?> getCustomerById(String id) async {
    try {
      final doc = await _firestore.collection('customers').doc(id).get();
      if (doc.exists) {
        return Customer.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      _errorMessage = 'Error fetching customer: $e';
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}