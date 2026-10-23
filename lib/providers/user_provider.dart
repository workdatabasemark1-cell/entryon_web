import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/activity_log_service.dart';

class UserProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<AppUser> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AppUser> get users => _users;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchUsers() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final snapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      _users
        ..clear()
        ..addAll(
          snapshot.docs.map((d) => AppUser.fromMap(d.data(), d.id)).toList(),
        );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error fetching users: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createUser({
    required String username,
    required String password,
    required String name,
    String role = 'staff',
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Check duplicate username
      final existing = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.trim())
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        _errorMessage = 'Username already exists';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Block reserved admin username
      if (username.trim().toLowerCase() == 'admin') {
        _errorMessage = 'Username "admin" is reserved';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final user = AppUser(
        id: id,
        username: username.trim(),
        password: password,
        name: name.trim(),
        role: role,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(id).set(user.toMap());
      await ActivityLogService.log(
        action: 'add',
        entity: 'user',
        entityId: id,
        details: {'username': user.username, 'name': user.name},
      );

      _users.insert(0, user);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error creating user: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

Future<bool> updateUser({
  required String id,
  required String username,
  required String name,
  required String role,
  String? password, // null or empty = keep existing password
}) async {
  try {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final trimmedUsername = username.trim();

    if (trimmedUsername.toLowerCase() == 'admin') {
      _errorMessage = 'Username "admin" is reserved';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Duplicate username check (exclude current user)
    final existing = await _firestore
        .collection('users')
        .where('username', isEqualTo: trimmedUsername)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty && existing.docs.first.id != id) {
      _errorMessage = 'Username already exists';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final index = _users.indexWhere((u) => u.id == id);
    final current = index >= 0 ? _users[index] : null;

    final updatedPassword =
        (password != null && password.isNotEmpty) ? password : (current?.password ?? '');

    final data = <String, dynamic>{
      'username': trimmedUsername,
      'name': name.trim(),
      'role': role,
      'password': updatedPassword,
      'updatedAt': Timestamp.now(),
    };

    await _firestore.collection('users').doc(id).update(data);
    await ActivityLogService.log(
      action: 'edit',
      entity: 'user',
      entityId: id,
      details: {'username': trimmedUsername, 'name': name.trim()},
    );

    if (index >= 0) {
      _users[index] = AppUser(
        id: id,
        username: trimmedUsername,
        password: updatedPassword,
        name: name.trim(),
        role: role,
        createdAt: current?.createdAt,
      );
    }

    _isLoading = false;
    notifyListeners();
    return true;
  } catch (e) {
    _errorMessage = 'Error updating user: $e';
    _isLoading = false;
    notifyListeners();
    return false;
  }
}

  Future<bool> deleteUser(String id) async {
    try {
      await _firestore.collection('users').doc(id).delete();
      await ActivityLogService.log(
        action: 'delete',
        entity: 'user',
        entityId: id,
      );
      _users.removeWhere((u) => u.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error deleting user: $e';
      notifyListeners();
      return false;
    }
  }
}