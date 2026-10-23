import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/activity_log_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Keys for custom admin credentials
  static const String _keyUsername = 'auth_username';
  static const String _keyPassword = 'auth_password';

  // Keys for active login session persistence
  static const String _keySessionLoggedIn = 'auth_session_is_logged_in';
  static const String _keySessionUserId = 'auth_session_user_id';
  static const String _keySessionUsername = 'auth_session_username';
  static const String _keySessionPassword = 'auth_session_password';
  static const String _keySessionName = 'auth_session_name';
  static const String _keySessionRole = 'auth_session_role';

  // Default fixed admin
  static const String _defaultUsername = 'admin';
  static const String _defaultPassword = 'ItCom@mlp09okn';

  String _username = _defaultUsername;
  String _password = _defaultPassword;

  /// Used for opening sensitive screens (Change credentials, etc.)
  String masterPassword = 'ItCom@mlp09okn';

  AppUser? _user;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _errorMessage;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;

  String get currentUsername => _user?.username ?? _username;
  String get currentPassword => _password;
  String get currentUserId => _user?.id ?? 'admin';
  String get currentUserName => _user?.name ?? 'Administrator';

  /// Call once at app start to restore session and credentials
  Future<void> loadCredentials() async {
    _isInitializing = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _username = prefs.getString(_keyUsername) ?? _defaultUsername;
      _password = prefs.getString(_keyPassword) ?? _defaultPassword;

      final bool isSessionSaved = prefs.getBool(_keySessionLoggedIn) ?? false;
      if (isSessionSaved) {
        final savedId = prefs.getString(_keySessionUserId) ?? 'admin';
        final savedUsername = prefs.getString(_keySessionUsername) ?? _username;
        final savedPassword = prefs.getString(_keySessionPassword) ?? _password;
        final savedName = prefs.getString(_keySessionName) ?? 'Administrator';
        final savedRole = prefs.getString(_keySessionRole) ?? 'admin';

        _user = AppUser(
          id: savedId,
          username: savedUsername,
          password: savedPassword,
          name: savedName,
          role: savedRole,
        );
        ActivityLogService.setActor(userId: _user!.id, userName: _user!.name);
      }
    } catch (_) {
      // Ignore reading errors on startup
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> _saveSessionToPrefs(AppUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySessionLoggedIn, true);
      await prefs.setString(_keySessionUserId, user.id);
      await prefs.setString(_keySessionUsername, user.username);
      await prefs.setString(_keySessionPassword, user.password);
      await prefs.setString(_keySessionName, user.name);
      await prefs.setString(_keySessionRole, user.role);
    } catch (_) {}
  }

  Future<void> _clearSessionFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySessionLoggedIn);
      await prefs.remove(_keySessionUserId);
      await prefs.remove(_keySessionUsername);
      await prefs.remove(_keySessionPassword);
      await prefs.remove(_keySessionName);
      await prefs.remove(_keySessionRole);
    } catch (_) {}
  }

  Future<bool> login({
    required String username,
    required String password,
    bool rememberMe = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    final inputUser = username.trim();
    final inputPass = password;

    // ── 1) Local fixed / edited admin ─────────────────────────────────────
    if (inputUser == _username && inputPass == _password) {
      final adminUser = AppUser(
        id: 'admin',
        username: _username,
        password: _password,
        name: 'Administrator',
        role: 'admin',
      );
      _user = adminUser;
      if (rememberMe) {
        await _saveSessionToPrefs(adminUser);
      } else {
        await _clearSessionFromPrefs();
      }

      _isLoading = false;
      ActivityLogService.setActor(userId: adminUser.id, userName: adminUser.name);
      await ActivityLogService.log(
        action: 'login',
        entity: 'authentication',
        userId: adminUser.id,
        userName: adminUser.name,
        details: {'username': inputUser, 'method': 'local'},
      );
      notifyListeners();
      return true;
    }

    // ── 2) Firebase users collection ──────────────────────────────────────
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: inputUser)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final appUser = AppUser.fromMap(doc.data(), doc.id);

        if (appUser.password == inputPass) {
          _user = appUser;
          if (rememberMe) {
            await _saveSessionToPrefs(appUser);
          } else {
            await _clearSessionFromPrefs();
          }

          _isLoading = false;
          ActivityLogService.setActor(userId: appUser.id, userName: appUser.name);
          await ActivityLogService.log(
            action: 'login',
            entity: 'authentication',
            userId: appUser.id,
            userName: appUser.name,
            details: {'username': inputUser, 'method': 'firebase'},
          );
          notifyListeners();
          return true;
        }
      }

      _errorMessage = 'Invalid username or password';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Login failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update local admin username & password (SharedPreferences)
  Future<bool> updateCredentials({
    required String currentPassword,
    required String newUsername,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));

    if (currentPassword != _password) {
      _errorMessage = 'Current password is incorrect';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (newUsername.trim().isEmpty) {
      _errorMessage = 'Username cannot be empty';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (newPassword.length < 4) {
      _errorMessage = 'Password must be at least 4 characters';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, newUsername.trim());
    await prefs.setString(_keyPassword, newPassword);

    _username = newUsername.trim();
    _password = newPassword;

    if (_user != null && _user!.id == 'admin') {
      _user = AppUser(
        id: 'admin',
        username: _username,
        password: _password,
        name: 'Administrator',
        role: 'admin',
      );
      await _saveSessionToPrefs(_user!);
    }

    _isLoading = false;
    await ActivityLogService.log(
      action: 'edit',
      entity: 'credentials',
      entityId: 'admin',
      details: {'username': _username},
    );
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    ActivityLogService.log(
      action: 'logout',
      entity: 'authentication',
      userId: currentUserId,
      userName: currentUserName,
    );
    _user = null;
    await _clearSessionFromPrefs();
    ActivityLogService.clearActor();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}