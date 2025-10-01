// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pastor_report/utils/constants.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _rememberMe = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get rememberMe => _rememberMe;

  AuthProvider() {
    _initializeAuth();
  }

  // Initialize authentication state
  Future<void> _initializeAuth() async {
    _setLoading(true);

    // Listen to auth state changes
    _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        await _loadUserData(firebaseUser.uid);
      } else {
        _user = null;
        notifyListeners();
      }
    });

    // Check for saved credentials
    await _loadRememberMePreference();
    _setLoading(false);
  }

  // Load user data from Firestore
  Future<void> _loadUserData(String uid) async {
    try {
      _user = await _authService.getUserData(uid);
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load user data');
    }
  }

  // Sign in
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      _user = await _authService.signInWithEmailPassword(email, password);

      if (_rememberMe) {
        await _saveRememberMePreference(email);
      } else {
        await _clearRememberMePreference();
      }

      _setLoading(false);
      return _user != null;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Register
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    bool isAdmin = false,
    String? mission,
    String? district,
    String? region,
    String? role,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _user = await _authService.registerWithEmailPassword(
        email: email,
        password: password,
        displayName: displayName,
        isAdmin: isAdmin,
        mission: mission,
        district: district,
        region: region,
        role: role,
      );

      _setLoading(false);
      return _user != null;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.signOut();
      _user = null;
      await _clearRememberMePreference();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.resetPassword(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Refresh user data
  Future<void> refreshUser() async {
    if (_user != null) {
      await _loadUserData(_user!.uid);
    }
  }

  // Update remember me preference
  void setRememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  // Save remember me preference
  Future<void> _saveRememberMePreference(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyRememberMe, true);
    await prefs.setString(AppConstants.keyUserEmail, email);
  }

  // Load remember me preference
  Future<void> _loadRememberMePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _rememberMe = prefs.getBool(AppConstants.keyRememberMe) ?? false;
    notifyListeners();
  }

  // Clear remember me preference
  Future<void> _clearRememberMePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyRememberMe);
    await prefs.remove(AppConstants.keyUserEmail);
  }

  // Get saved email
  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyUserEmail);
  }

  // Helper methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Clear error message
  void clearError() {
    _clearError();
    notifyListeners();
  }
}
