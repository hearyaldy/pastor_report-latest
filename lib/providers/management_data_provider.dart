import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/models/financial_report_model.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/financial_report_service.dart';

/// Centralized data provider with caching for management screens
/// Reduces database reads by caching data and using streams
class ManagementDataProvider with ChangeNotifier {
  static final ManagementDataProvider instance = ManagementDataProvider._();
  ManagementDataProvider._();

  final ChurchService _churchService = ChurchService();
  final DistrictService _districtService = DistrictService();
  final RegionService _regionService = RegionService();
  final FinancialReportService _reportService = FinancialReportService();

  // Cached data
  List<Church>? _churches;
  List<District>? _districts;
  List<Region>? _regions;
  final Map<String, List<FinancialReport>> _reportsByMonth = {};
  final Map<String, int> _churchCountsByDistrict = {};

  // Cache timestamps
  DateTime? _churchesLastFetch;
  DateTime? _districtsLastFetch;
  DateTime? _regionsLastFetch;

  // Cache duration
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Loading states
  bool _isLoadingChurches = false;
  bool _isLoadingDistricts = false;
  bool _isLoadingRegions = false;

  // Getters
  List<Church> get churches => _churches ?? [];
  List<District> get districts => _districts ?? [];
  List<Region> get regions => _regions ?? [];
  bool get isLoadingChurches => _isLoadingChurches;
  bool get isLoadingDistricts => _isLoadingDistricts;
  bool get isLoadingRegions => _isLoadingRegions;

  /// Get churches with caching
  Future<List<Church>> getChurches({bool forceRefresh = false}) async {
    if (!forceRefresh && _churches != null && _churchesLastFetch != null) {
      final cacheAge = DateTime.now().difference(_churchesLastFetch!);
      if (cacheAge < _cacheDuration) {
        return _churches!;
      }
    }

    _isLoadingChurches = true;
    notifyListeners();

    try {
      _churches = await _churchService.getAllChurches();
      _churchesLastFetch = DateTime.now();
      debugPrint(
          '📊 ManagementDataProvider: Loaded ${_churches!.length} churches from database');
    } catch (e) {
      debugPrint('❌ Error loading churches: $e');
      _churches ??= [];
    } finally {
      _isLoadingChurches = false;
      notifyListeners();
    }

    return _churches!;
  }

  /// Get districts with caching
  Future<List<District>> getDistricts({bool forceRefresh = false}) async {
    if (!forceRefresh && _districts != null && _districtsLastFetch != null) {
      final cacheAge = DateTime.now().difference(_districtsLastFetch!);
      if (cacheAge < _cacheDuration) {
        return _districts!;
      }
    }

    _isLoadingDistricts = true;
    notifyListeners();

    try {
      _districts = await _districtService.getAllDistricts();
      _districtsLastFetch = DateTime.now();
      debugPrint(
          '📊 ManagementDataProvider: Loaded ${_districts!.length} districts from database');
    } catch (e) {
      debugPrint('❌ Error loading districts: $e');
      _districts ??= [];
    } finally {
      _isLoadingDistricts = false;
      notifyListeners();
    }

    return _districts!;
  }

  /// Get regions with caching
  Future<List<Region>> getRegions({bool forceRefresh = false}) async {
    if (!forceRefresh && _regions != null && _regionsLastFetch != null) {
      final cacheAge = DateTime.now().difference(_regionsLastFetch!);
      if (cacheAge < _cacheDuration) {
        return _regions!;
      }
    }

    _isLoadingRegions = true;
    notifyListeners();

    try {
      _regions = await _regionService.getAllRegions();
      _regionsLastFetch = DateTime.now();
      debugPrint(
          '📊 ManagementDataProvider: Loaded ${_regions!.length} regions from database');
    } catch (e) {
      debugPrint('❌ Error loading regions: $e');
      _regions ??= [];
    } finally {
      _isLoadingRegions = false;
      notifyListeners();
    }

    return _regions!;
  }

  /// Get churches by district with caching
  Future<List<Church>> getChurchesByDistrict(String districtId) async {
    await getChurches();
    return _churches?.where((c) => c.districtId == districtId).toList() ?? [];
  }

  /// Get districts by region with caching
  Future<List<District>> getDistrictsByRegion(String regionId) async {
    await getDistricts();
    return _districts?.where((d) => d.regionId == regionId).toList() ?? [];
  }

  /// Get church count by district with caching
  Future<int> getChurchCountByDistrict(String districtId) async {
    if (_churchCountsByDistrict.containsKey(districtId)) {
      return _churchCountsByDistrict[districtId]!;
    }

    final churches = await getChurchesByDistrict(districtId);
    _churchCountsByDistrict[districtId] = churches.length;
    return churches.length;
  }

  /// Get all church counts by district
  Future<Map<String, int>> getAllChurchCounts() async {
    await getChurches();
    await getDistricts();

    _churchCountsByDistrict.clear();
    for (var district in _districts!) {
      final count =
          _churches?.where((c) => c.districtId == district.id).length ?? 0;
      _churchCountsByDistrict[district.id] = count;
    }

    return _churchCountsByDistrict;
  }

  /// Get financial reports for a month with caching
  Future<List<FinancialReport>> getReportsForMonth(DateTime month,
      {bool forceRefresh = false}) async {
    final monthKey = '${month.year}-${month.month}';

    if (!forceRefresh && _reportsByMonth.containsKey(monthKey)) {
      return _reportsByMonth[monthKey]!;
    }

    try {
      final churches = await getChurches();
      final reports = <FinancialReport>[];

      for (var church in churches) {
        final report =
            await _reportService.getReportByChurchAndMonth(church.id, month);
        if (report != null) {
          reports.add(report);
        }
      }

      _reportsByMonth[monthKey] = reports;
      debugPrint(
          '📊 ManagementDataProvider: Loaded ${reports.length} reports for $monthKey');
      return reports;
    } catch (e) {
      debugPrint('❌ Error loading reports: $e');
      return [];
    }
  }

  /// Get district name by ID
  String getDistrictName(String? districtId) {
    if (districtId == null || _districts == null) return 'N/A';
    final district = _districts!.firstWhere(
      (d) => d.id == districtId,
      orElse: () => District(
        id: '',
        name: 'Unknown',
        code: '',
        regionId: '',
        missionId: '',
        createdBy: '',
        createdAt: DateTime.now(),
      ),
    );
    return district.name;
  }

  /// Get region name by ID
  String getRegionName(String? regionId) {
    if (regionId == null || _regions == null) return 'N/A';
    final region = _regions!.firstWhere(
      (r) => r.id == regionId,
      orElse: () => Region(
        id: '',
        name: 'Unknown',
        code: '',
        missionId: '',
        createdBy: '',
        createdAt: DateTime.now(),
      ),
    );
    return region.name;
  }

  /// Get church name by ID
  String getChurchName(String? churchId) {
    if (churchId == null || _churches == null) return 'Unknown';
    final church = _churches!.firstWhere(
      (c) => c.id == churchId,
      orElse: () => Church(
        id: '',
        userId: '',
        churchName: 'Unknown',
        elderName: '',
        status: ChurchStatus.church,
        elderEmail: '',
        elderPhone: '',
        createdAt: DateTime.now(),
      ),
    );
    return church.churchName;
  }

  /// Invalidate church cache (call after create/update/delete)
  void invalidateChurchCache() {
    _churches = null;
    _churchesLastFetch = null;
    _churchCountsByDistrict.clear();
    debugPrint('🔄 Church cache invalidated');
    notifyListeners();
  }

  /// Invalidate district cache (call after create/update/delete)
  void invalidateDistrictCache() {
    _districts = null;
    _districtsLastFetch = null;
    _churchCountsByDistrict.clear();
    debugPrint('🔄 District cache invalidated');
    notifyListeners();
  }

  /// Invalidate region cache (call after create/update/delete)
  void invalidateRegionCache() {
    _regions = null;
    _regionsLastFetch = null;
    debugPrint('🔄 Region cache invalidated');
    notifyListeners();
  }

  /// Invalidate reports cache for a specific month
  void invalidateReportsCache(DateTime month) {
    final monthKey = '${month.year}-${month.month}';
    _reportsByMonth.remove(monthKey);
    debugPrint('🔄 Reports cache invalidated for $monthKey');
    notifyListeners();
  }

  /// Clear all caches
  void clearAllCaches() {
    _churches = null;
    _districts = null;
    _regions = null;
    _reportsByMonth.clear();
    _churchCountsByDistrict.clear();
    _churchesLastFetch = null;
    _districtsLastFetch = null;
    _regionsLastFetch = null;
    debugPrint('🔄 All caches cleared');
    notifyListeners();
  }

  /// Pre-load all data (useful for initial app load)
  Future<void> preloadAllData() async {
    debugPrint('⏳ Pre-loading all management data...');
    await Future.wait([
      getRegions(),
      getDistricts(),
      getChurches(),
    ]);
    await getAllChurchCounts();
    debugPrint('✅ All management data pre-loaded');
  }
}
