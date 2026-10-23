import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/service_model.dart';
import '../models/transaction_model.dart';
import '../services/activity_log_service.dart';

class ServiceEntryProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<ServiceEntry> _services = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ServiceEntry> get services => _services;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  

  Future<void> fetchServices() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final snapshot = await _firestore
          .collection('services')
          .orderBy('serviceDate', descending: true)
          .get();

      _services.clear();
      _services.addAll(snapshot.docs.map((doc) => ServiceEntry.fromMap(doc.data(), doc.id)).toList());
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error fetching services: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

Future<bool> addService({
  required String title,
  required String customerName,
  String? customerId,
  String? branchName,
  String? staffName,
  String? staffPhone,
  String? softwareName,
  String? description,
  required DateTime serviceDate,
  required double amount,
  required double serviceFee,
  required double customerPaidAmount,
  required String paymentStatus,
  required String serviceStatus,
  required String paymentType,
  required DateTime? paymentExpiryDate,
  required List<ServicePurchaseLine> purchaseLines,
  String? addedById,      
  String? addedByName, 
  String? editedById,      
  String? editedByName,   
}) async {
  try {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final service = ServiceEntry(
      id: id,
      title: title.trim(),
      customerName: customerName.trim(),
      customerId: customerId,
      branchName: branchName?.trim(),
      staffName: staffName?.trim(),
      staffPhone: staffPhone?.trim(),
      softwareName: softwareName?.trim(),
      description: description?.trim(),
      serviceDate: serviceDate,
      amount: amount,
      serviceFee: serviceFee,
      customerPaidAmount: customerPaidAmount,
      balanceAmount: amount - customerPaidAmount,
      paymentStatus: paymentStatus,
      serviceStatus: serviceStatus,
      paymentType: paymentType,
      paymentExpiryDate: paymentExpiryDate,
      purchaseLines: purchaseLines,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      addedById: addedById,       // ✅
      addedByName: addedByName, 
      editedById: editedById,       // ✅
      editedByName: editedByName,
        // ✅
    );

    await _firestore.collection('services').doc(id).set(service.toMap());
    await ActivityLogService.log(
      action: 'add',
      entity: 'service',
      entityId: id,
      details: {'title': title, 'customerName': customerName},
    );

     if (customerPaidAmount > 0) {
        final txn = TransactionModel(
          id: id,
          serviceId: id,
          customerId: customerId,
          customerName: customerName.trim(),
          amount: customerPaidAmount,
          balanceAmount: amount - customerPaidAmount,
          purchaseAmount: amount,
          pendingAmount: amount,
          paymentType: paymentType,

          paymentDetails: paymentType == 'Card' ? {'note': 'Initial payment during service creation'} : {},
          createdAt: DateTime.now(),
          addedById: addedById??'',
          addedByName: addedByName??''
        );
        await _firestore.collection('transactions').doc(txn.id).set(txn.toMap());
      }

    _services.insert(0, service);
    _isLoading = false;
    notifyListeners();
    return true;
  } catch (e) {
    _errorMessage = 'Error saving service: $e';
    _isLoading = false;
    notifyListeners();
    return false;
  }
}
  Future<bool> updateService({
    required String id,
    required String title,
    required String customerName,
    String? customerId,
    String? branchName,
    String? staffName,
    String? staffPhone,
    String? softwareName,
    String? description,
    required DateTime serviceDate,
    required double amount,
    required double serviceFee,
    required double customerPaidAmount,
    required String paymentStatus,
    required String serviceStatus,
    required String paymentType,
    required DateTime? paymentExpiryDate,
    required List<ServicePurchaseLine> purchaseLines,
    String? addedById,      
    String? addedByName,
    String? editedById,      
    String? editedByName,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final updated = ServiceEntry(
        id: id,
        title: title.trim(),
        customerName: customerName.trim(),
        customerId: customerId,
        branchName: branchName?.trim(),
        staffName: staffName?.trim(),
        staffPhone: staffPhone?.trim(),
        softwareName: softwareName?.trim(),
        description: description?.trim(),
        serviceDate: serviceDate,
        amount: amount,
        serviceFee: serviceFee,
        customerPaidAmount: customerPaidAmount,
        balanceAmount: amount - customerPaidAmount,
        paymentStatus: paymentStatus,
        serviceStatus: serviceStatus,
        paymentType: paymentType,
        paymentExpiryDate: paymentExpiryDate,
        purchaseLines: purchaseLines,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        addedById: addedById,       // ✅
        addedByName: addedByName,
        editedById: editedById,       // ✅
        editedByName: editedByName,
      );

      await _firestore.collection('services').doc(id).update(updated.toMap());
      await ActivityLogService.log(
        action: 'edit',
        entity: 'service',
        entityId: id,
        details: {'title': title, 'customerName': customerName},
      );

      final index = _services.indexWhere((s) => s.id == id);
      if (index >= 0) {
        _services[index] = updated;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error updating service: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteService(String id) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection('services').doc(id).delete();
      await ActivityLogService.log(
        action: 'delete',
        entity: 'service',
        entityId: id,
      );
      _services.removeWhere((service) => service.id == id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error deleting service: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
