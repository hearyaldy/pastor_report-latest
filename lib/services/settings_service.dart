// lib/services/settings_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user settings
class SettingsService {
  static SettingsService? _instance;
  static SettingsService get instance {
    _instance ??= SettingsService._();
    return _instance!;
  }

  SettingsService._();

  static const String _kmCostKey = 'km_cost_rate';
  static const double _defaultKmCost = 0.50; // Default: $0.50 per km

  SharedPreferences? _prefs;

  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get the current km cost rate
  Future<double> getKmCost() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      return _prefs!.getDouble(_kmCostKey) ?? _defaultKmCost;
    } catch (e) {
      debugPrint('Error loading km cost: $e');
      return _defaultKmCost;
    }
  }

  /// Set the km cost rate
  Future<bool> setKmCost(double cost) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final success = await _prefs!.setDouble(_kmCostKey, cost);
      if (success) {
        debugPrint('✅ KM cost updated to: \$$cost');
      }
      return success;
    } catch (e) {
      debugPrint('❌ Error setting km cost: $e');
      return false;
    }
  }

  /// Reset km cost to default
  Future<bool> resetKmCost() async {
    return setKmCost(_defaultKmCost);
  }

  /// Get default km cost
  double get defaultKmCost => _defaultKmCost;
}
