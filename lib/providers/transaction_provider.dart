import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/activity_log_service.dart';

class TransactionProvider with ChangeNotifier {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  final List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> addTransaction(TransactionModel txn) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection('transactions').doc(txn.id).set(txn.toMap());
      _transactions.insert(0, txn);
      await ActivityLogService.log(
        action: 'add',
        entity: 'transaction',
        entityId: txn.id,
        details: {'customerName': txn.customerName, 'amount': txn.amount},
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error saving transaction: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchTransactions() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final snapshot = await _firestore.collection('transactions').orderBy('createdAt', descending: true).get();
      _transactions.clear();
      _transactions.addAll(snapshot.docs.map((d) => TransactionModel.fromMap(d.data(), d.id)).toList());

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error fetching transactions: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTransaction(String transactionId) async {
    try {
      _errorMessage = null;
      await _firestore.collection('transactions').doc(transactionId).delete();
      _transactions.removeWhere((transaction) => transaction.id == transactionId);
      await ActivityLogService.log(
        action: 'delete',
        entity: 'transaction',
        entityId: transactionId,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error deleting transaction: $e';
      notifyListeners();
      return false;
    }
  }

  /// Marks a transaction as payment-received by the currently logged-in store user.
  Future<bool> confirmPaymentReceived({
    required String transactionId,
    required String receivedByName,
    required String receivedById,
  }) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('transactions').doc(transactionId).update({
        'receivedByName': receivedByName,
        'receivedById': receivedById,
        'receivedAt': now.toIso8601String(),
      });

      // Update local list immediately so UI rebuilds without a full refetch.
      final index = _transactions.indexWhere((t) => t.id == transactionId);
      if (index != -1) {
        final old = _transactions[index];
        _transactions[index] = TransactionModel(
          id: old.id,
          serviceId: old.serviceId,
          customerId: old.customerId,
          customerName: old.customerName,
          amount: old.amount,
          balanceAmount: old.balanceAmount,
          purchaseAmount: old.purchaseAmount,
          pendingAmount: old.pendingAmount,
          paymentType: old.paymentType,
          paymentDetails: old.paymentDetails,
          createdAt: old.createdAt,
          addedById: old.addedById,
          addedByName: old.addedByName,
          receivedByName: receivedByName,
          receivedById: receivedById,
          receivedAt: now,
        );
      }

      await ActivityLogService.log(
        action: 'confirm_payment_received',
        entity: 'transaction',
        entityId: transactionId,
        details: {'receivedByName': receivedByName},
      );

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error confirming payment: $e';
      notifyListeners();
      return false;
    }
  }
}
