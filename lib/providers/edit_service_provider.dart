import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/service_model.dart';

class EditServiceProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ServiceEntry? _service;
  bool _isLoading = false;
  String? _errorMessage;

  ServiceEntry? get service => _service;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> fetchServiceById(String id) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final doc = await _firestore.collection('services').doc(id).get();
      if (!doc.exists) {
        _service = null;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final data = doc.data();
      _service = data != null ? ServiceEntry.fromMap(data, doc.id) : null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error loading service: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
