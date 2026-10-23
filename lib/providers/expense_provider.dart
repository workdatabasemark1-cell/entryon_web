import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../services/activity_log_service.dart';

class ExpenseProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<ExpenseModel> _expenses = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ── Filters State ─────────────────────────────────────────────────────────
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedPaymentMethod = 'All';
  String? _selectedPeriodSectionId;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String _sortBy = 'date_desc'; // date_desc, date_asc, amount_desc, amount_asc

  // ── Default Categories ───────────────────────────────────────────────────
  static const List<String> defaultCategories = [
    'Rent & Lease',
    'Utilities (Electricity/Water)',
    'Office Supplies & Stationery',
    'Salaries & Wages',
    'Fuel & Transportation',
    'Repairs & Maintenance',
    'IT & Software Subscriptions',
    'Marketing & Advertising',
    'Government & Legal Fees',
    'Hospitality & Refreshments',
    'General & Miscellaneous',
  ];

  static const List<String> paymentMethods = [
    'Cash',
    'Bank Transfer',
    'Card',
    'Cheque',
    'Online Payment',
    'Other',
  ];

  // ── Getters ───────────────────────────────────────────────────────────────
  List<ExpenseModel> get expenses => _expenses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  String get selectedPaymentMethod => _selectedPaymentMethod;
  String? get selectedPeriodSectionId => _selectedPeriodSectionId;
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? get filterEndDate => _filterEndDate;
  String get sortBy => _sortBy;

  /// Dynamic list of categories including default + any custom used in expenses
  List<String> get allCategories {
    final set = <String>{...defaultCategories};
    for (final exp in _expenses) {
      if (exp.category.trim().isNotEmpty) {
        set.add(exp.category.trim());
      }
    }
    return set.toList();
  }

  /// Filtered expenses based on search query, category, payment method, dates, period
  List<ExpenseModel> get filteredExpenses {
    var list = _expenses.where((exp) {
      // Category filter
      if (_selectedCategory != 'All' && exp.category != _selectedCategory) {
        return false;
      }

      // Payment method filter
      if (_selectedPaymentMethod != 'All' &&
          exp.paymentMethod != _selectedPaymentMethod) {
        return false;
      }

      // Period section filter
      if (_selectedPeriodSectionId != null &&
          _selectedPeriodSectionId!.isNotEmpty &&
          exp.periodSectionId != _selectedPeriodSectionId) {
        return false;
      }

      // Date range filter
      if (_filterStartDate != null) {
        final start = DateTime(
          _filterStartDate!.year,
          _filterStartDate!.month,
          _filterStartDate!.day,
        );
        if (exp.date.isBefore(start)) return false;
      }
      if (_filterEndDate != null) {
        final end = DateTime(
          _filterEndDate!.year,
          _filterEndDate!.month,
          _filterEndDate!.day,
          23,
          59,
          59,
        );
        if (exp.date.isAfter(end)) return false;
      }

      // Search Query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchTitle = exp.title.toLowerCase().contains(q);
        final matchCategory = exp.category.toLowerCase().contains(q);
        final matchRef = exp.referenceNo.toLowerCase().contains(q);
        final matchPaidTo = exp.paidTo.toLowerCase().contains(q);
        final matchNotes = exp.notes.toLowerCase().contains(q);
        final matchCustomer =
            (exp.customerName ?? '').toLowerCase().contains(q);
        if (!matchTitle &&
            !matchCategory &&
            !matchRef &&
            !matchPaidTo &&
            !matchNotes &&
            !matchCustomer) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort
    list.sort((a, b) {
      switch (_sortBy) {
        case 'date_asc':
          return a.date.compareTo(b.date);
        case 'date_desc':
          return b.date.compareTo(a.date);
        case 'amount_asc':
          return a.totalAmount.compareTo(b.totalAmount);
        case 'amount_desc':
          return b.totalAmount.compareTo(a.totalAmount);
        case 'title_asc':
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        default:
          return b.date.compareTo(a.date);
      }
    });

    return list;
  }

  // ── Metrics & Aggregates (calculated on filtered list) ─────────────────────
  double get totalFilteredAmount =>
      filteredExpenses.fold(0.0, (acc, exp) => acc + exp.totalAmount);

  double get totalFilteredExVat =>
      filteredExpenses.fold(0.0, (acc, exp) => acc + exp.amountExVat);

  double get totalFilteredVat =>
      filteredExpenses.fold(0.0, (acc, exp) => acc + exp.vatAmount);

  int get totalFilteredCount => filteredExpenses.length;

  // All time / unfiltered totals
  double get totalAllAmount =>
      _expenses.fold(0.0, (acc, exp) => acc + exp.totalAmount);

  double get totalAllExVat =>
      _expenses.fold(0.0, (acc, exp) => acc + exp.amountExVat);

  double get totalAllVat =>
      _expenses.fold(0.0, (acc, exp) => acc + exp.vatAmount);

  Map<String, double> get categoryBreakdown {
    final map = <String, double>{};
    for (final exp in filteredExpenses) {
      map[exp.category] = (map[exp.category] ?? 0.0) + exp.totalAmount;
    }
    return map;
  }

  // ── Filter Controls ───────────────────────────────────────────────────────
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSelectedPaymentMethod(String method) {
    _selectedPaymentMethod = method;
    notifyListeners();
  }

  void setSelectedPeriodSection(String? periodId) {
    _selectedPeriodSectionId = periodId;
    notifyListeners();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _filterStartDate = start;
    _filterEndDate = end;
    notifyListeners();
  }

  void setSortBy(String sort) {
    _sortBy = sort;
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedCategory = 'All';
    _selectedPaymentMethod = 'All';
    _selectedPeriodSectionId = null;
    _filterStartDate = null;
    _filterEndDate = null;
    _sortBy = 'date_desc';
    notifyListeners();
  }

  // ── Helper to format error message ────────────────────────────────────────
  String _formatError(dynamic e) {
    if (e is FirebaseException) {
      return e.message ?? e.code;
    }
    return e.toString();
  }

  // ── Firestore CRUD Operations ─────────────────────────────────────────────

  /// Fetch all expenses
  Future<void> fetchExpenses() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final snapshot = await _firestore
          .collection('expenses')
          .orderBy('date', descending: true)
          .get();

      _expenses.clear();
      for (final doc in snapshot.docs) {
        try {
          _expenses.add(ExpenseModel.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing expense doc ${doc.id}: $e');
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading expenses: ${_formatError(e)}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add new expense
  Future<bool> addExpense(ExpenseModel expense) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final docId = expense.id.isNotEmpty
          ? expense.id
          : DateTime.now().millisecondsSinceEpoch.toString();

      final finalExpense = expense.copyWith(id: docId);

      await _firestore
          .collection('expenses')
          .doc(docId)
          .set(finalExpense.toMap());

      _expenses.insert(0, finalExpense);

      // Log activity
      await ActivityLogService.log(
        action: 'add',
        entity: 'expense',
        entityId: docId,
        details: {
          'title': finalExpense.title,
          'category': finalExpense.category,
          'totalAmount': finalExpense.totalAmount,
          'paymentMethod': finalExpense.paymentMethod,
        },
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add expense: ${_formatError(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update existing expense
  Future<bool> updateExpense(ExpenseModel expense) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final updated = expense.copyWith(updatedAt: DateTime.now());

      await _firestore
          .collection('expenses')
          .doc(updated.id)
          .update(updated.toMap());

      final idx = _expenses.indexWhere((e) => e.id == updated.id);
      if (idx != -1) {
        _expenses[idx] = updated;
      }

      // Log activity
      await ActivityLogService.log(
        action: 'update',
        entity: 'expense',
        entityId: updated.id,
        details: {
          'title': updated.title,
          'category': updated.category,
          'totalAmount': updated.totalAmount,
        },
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update expense: ${_formatError(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete expense
  Future<bool> deleteExpense(String expenseId) async {
    try {
      _errorMessage = null;

      final expenseToDelete =
          _expenses.firstWhere((e) => e.id == expenseId, orElse: () => ExpenseModel(
                id: '',
                title: '',
                category: '',
                amountExVat: 0,
                vatAmount: 0,
                totalAmount: 0,
                date: DateTime.now(),
                createdAt: DateTime.now(),
              ));

      await _firestore.collection('expenses').doc(expenseId).delete();
      _expenses.removeWhere((e) => e.id == expenseId);

      // Log activity
      await ActivityLogService.log(
        action: 'delete',
        entity: 'expense',
        entityId: expenseId,
        details: {
          'title': expenseToDelete.title,
          'totalAmount': expenseToDelete.totalAmount,
        },
      );

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete expense: ${_formatError(e)}';
      notifyListeners();
      return false;
    }
  }
}
