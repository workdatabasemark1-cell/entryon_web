import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/profit_calculation_model.dart';

class ProfitCalculationProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSaving = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<ProfitCalculation> _calculations = [];
  StreamSubscription<QuerySnapshot>? _subscription;

  bool get isSaving => _isSaving;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ProfitCalculation> get calculations => _calculations;

  /// Start listening to live updates from the `profit_calculations` collection.
  void listenToCalculations() {
    if (_subscription != null) return;
    _isLoading = true;
    notifyListeners();

    _subscription = _firestore
        .collection('profit_calculations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        _calculations = snapshot.docs
            .map((doc) => ProfitCalculation.fromMap(
                  doc.data(),
                  doc.id,
                ))
            .toList();
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = 'Unable to stream calculations: $error';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// One-time fetch of all calculations
  Future<void> fetchCalculations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('profit_calculations')
          .orderBy('createdAt', descending: true)
          .get();

      _calculations = snapshot.docs
          .map((doc) => ProfitCalculation.fromMap(
                doc.data(),
                doc.id,
              ))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Unable to fetch calculations: $error';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create / Save a new calculation
  Future<bool> saveCalculation(ProfitCalculation calculation) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestore
          .collection('profit_calculations')
          .doc(calculation.id)
          .set(calculation.toMap());

      // If not streaming, insert at top
      if (_subscription == null) {
        _calculations.removeWhere((c) => c.id == calculation.id);
        _calculations.insert(0, calculation);
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = 'Unable to save calculation: $error';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Update an existing calculation
  Future<bool> updateCalculation(ProfitCalculation calculation) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestore
          .collection('profit_calculations')
          .doc(calculation.id)
          .update(calculation.toMap());

      if (_subscription == null) {
        final index = _calculations.indexWhere((c) => c.id == calculation.id);
        if (index != -1) {
          _calculations[index] = calculation;
        }
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = 'Unable to update calculation: $error';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete a calculation by ID
  Future<bool> deleteCalculation(String id) async {
    _errorMessage = null;

    try {
      await _firestore.collection('profit_calculations').doc(id).delete();
      _calculations.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = 'Unable to delete calculation: $error';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
