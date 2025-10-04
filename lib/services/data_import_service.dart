import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/models/staff_model.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/staff_service.dart';
import 'package:uuid/uuid.dart';

class DataImportService {
  static final DataImportService instance = DataImportService._internal();
  factory DataImportService() => instance;
  DataImportService._internal();

  final RegionService _regionService = RegionService.instance;
  final DistrictService _districtService = DistrictService.instance;
  final StaffService _staffService = StaffService.instance;

  // Region mapping - number to region name
  static const Map<int, String> regionNames = {
    1: 'Region 1',
    2: 'Region 2',
    3: 'Region 3',
    4: 'Region 4',
    5: 'Region 5',
    6: 'Region 6',
    7: 'Region 7',
    8: 'Region 8',
    9: 'Region 9',
    10: 'Region 10',
  };

  // District and their region number
  static const List<Map<String, dynamic>> districtData = [
    {'name': 'PMC TAMPARULI / SMAT CHAPLAIN', 'region': 4},
    {'name': 'BANGKAHAK', 'region': 1},
    {'name': 'TELIPOK', 'region': 5},
    {'name': 'MANTANAU', 'region': 1},
    {'name': 'TAVIU', 'region': 8},
    {'name': 'KINABATANGAN', 'region': 9},
    {'name': 'ROSOK', 'region': 1},
    {'name': 'TAMPARULI', 'region': 4},
    {'name': 'KINARUT', 'region': 5},
    {'name': 'NARINANG', 'region': 1},
    {'name': 'NABALU', 'region': 3},
    {'name': 'INANAM CHINESE', 'region': 5},
    {'name': 'TELUPID', 'region': 8},
    {'name': 'KAYANGAT', 'region': 2},
    {'name': 'TUNGKU', 'region': 10},
    {'name': 'KEPAYAN', 'region': 5},
    {'name': 'ALAMESRA', 'region': 5},
    {'name': 'SUNGAI MANILA', 'region': 9},
    {'name': 'RANAU', 'region': 8},
    {'name': 'MENGGATAL', 'region': 5},
    {'name': 'BELURAN', 'region': 9},
    {'name': 'LEMBAH KIMOULAU KIULU', 'region': 4},
    {'name': 'SOOK', 'region': 7},
    {'name': 'RANGALAU', 'region': 1},
    {'name': 'TENOM', 'region': 7},
    {'name': 'SIPITANG', 'region': 6},
    {'name': 'MANTOB', 'region': 4},
    {'name': 'PODOS', 'region': 1},
    {'name': 'TUNGOU', 'region': 4},
    {'name': 'KOTA KINABALU CITY', 'region': 5},
    {'name': 'KOTA KINABALU, LUYANG', 'region': 5},
    {'name': 'NANGOH', 'region': 9},
    {'name': 'LABUAN', 'region': 6},
    {'name': 'KIULU', 'region': 4},
    {'name': 'LAHAD DATU', 'region': 10},
    {'name': 'TAWAU', 'region': 10},
    {'name': 'TAMBUNAN', 'region': 7},
    {'name': 'MALANGANG BARU', 'region': 4},
    {'name': 'PENAMPANG', 'region': 5},
    {'name': 'KOTA KINABALU, LIKAS', 'region': 5},
    {'name': 'GAUR', 'region': 1},
    {'name': 'SANDAKAN', 'region': 9},
    {'name': 'SEPULUT - NABAWAN', 'region': 7},
    {'name': 'TENGHILAN', 'region': 2},
    {'name': 'NAHABA', 'region': 1},
    {'name': 'GAYARATAU', 'region': 3},
    {'name': 'PAPAR', 'region': 6},
    {'name': 'KUNAK', 'region': 10},
    {'name': 'TUARAN', 'region': 3},
    {'name': 'INANAM', 'region': 5},
    {'name': 'KAPA', 'region': 3},
    {'name': 'KINASARABAN', 'region': 2},
    {'name': 'KENINGAU', 'region': 7},
    {'name': 'SERUDUNG, TAWAU', 'region': 10},
    {'name': 'KELAWAT', 'region': 2},
    {'name': 'SALIKU - SUMATALUN', 'region': 7},
    {'name': 'BEAUFORT', 'region': 6},
    {'name': 'MANSIAT - SINULIHAN, SOOK', 'region': 7},
    {'name': 'SALINATAN - PENSIANGAN', 'region': 7},
  ];

  /// Import all regions and districts for a mission
  /// Returns a map with import statistics
  Future<Map<String, int>> importRegionsAndDistricts(String missionId) async {
    int regionsCreated = 0;
    int districtsCreated = 0;
    int districtsSkipped = 0;

    // Map to store region IDs by region number
    Map<int, String> regionIdMap = {};

    // Step 1: Create all regions
    for (var entry in regionNames.entries) {
      final regionNum = entry.key;
      final regionName = entry.value;
      final regionCode = 'R$regionNum';

      // Check if region already exists
      final exists =
          await _regionService.isRegionCodeExists(regionCode, missionId);
      if (!exists) {
        final region = Region(
          id: const Uuid().v4(),
          name: regionName,
          code: regionCode,
          missionId: missionId,
          createdAt: DateTime.now(),
          createdBy: 'admin',
        );

        await _regionService.createRegion(region);
        regionIdMap[regionNum] = region.id;
        regionsCreated++;
      } else {
        // Get existing region ID
        final regions = await _regionService.getRegionsByMission(missionId);
        final existingRegion = regions.firstWhere(
          (r) => r.code == regionCode,
        );
        regionIdMap[regionNum] = existingRegion.id;
      }
    }

    // Step 2: Create all districts
    // Remove duplicates first
    Map<String, int> uniqueDistricts = {};
    for (var district in districtData) {
      final name = district['name'] as String;
      final region = district['region'] as int;
      if (!uniqueDistricts.containsKey(name)) {
        uniqueDistricts[name] = region;
      }
    }

    for (var entry in uniqueDistricts.entries) {
      final districtName = entry.key;
      final regionNum = entry.value;
      final regionId = regionIdMap[regionNum]!;

      // Generate district code from name (first 2 letters + number)
      String districtCode = _generateDistrictCode(districtName, districtsCreated);

      // Check if district already exists
      final exists = await _districtService.isDistrictCodeExists(
        districtCode,
        regionId,
      );

      if (!exists) {
        final district = District(
          id: const Uuid().v4(),
          name: districtName,
          code: districtCode,
          regionId: regionId,
          missionId: missionId,
          createdAt: DateTime.now(),
          createdBy: 'admin',
        );

        await _districtService.createDistrict(district);
        districtsCreated++;
      } else {
        districtsSkipped++;
      }
    }

    return {
      'regionsCreated': regionsCreated,
      'districtsCreated': districtsCreated,
      'districtsSkipped': districtsSkipped,
      'totalRegions': regionNames.length,
      'totalDistricts': uniqueDistricts.length,
    };
  }

  /// Generate a district code from district name
  String _generateDistrictCode(String name, int index) {
    // Take first 2 letters and add sequential number
    final prefix = name.replaceAll(RegExp(r'[^A-Z]'), '').substring(0, 2);
    return '$prefix${index + 1}';
  }

  /// Get statistics about the data to be imported
  Map<String, dynamic> getImportStats() {
    // Remove duplicates
    Set<String> uniqueDistrictNames = {};
    Map<int, List<String>> districtsByRegion = {};

    for (var district in districtData) {
      final name = district['name'] as String;
      final regionNum = district['region'] as int;

      uniqueDistrictNames.add(name);

      if (!districtsByRegion.containsKey(regionNum)) {
        districtsByRegion[regionNum] = [];
      }
      if (!districtsByRegion[regionNum]!.contains(name)) {
        districtsByRegion[regionNum]!.add(name);
      }
    }

    return {
      'totalRegions': regionNames.length,
      'totalDistricts': uniqueDistrictNames.length,
      'districtsByRegion': districtsByRegion,
    };
  }

  // Staff data with district and region assignments
  static const List<Map<String, dynamic>> staffData = [
    {'name': 'A Hairrie Severinus', 'district': 'PMC TAMPARULI / SMAT CHAPLAIN', 'region': 4},
    {'name': 'A Harnnie Severinus', 'district': 'BANGKAHAK', 'region': 1},
    {'name': 'Adee Lindon Masilon', 'district': 'TELIPOK', 'region': 5},
    {'name': 'Adriel Charles Jr', 'district': 'MANTANAU', 'region': 1},
    {'name': 'Alexander Maxon Horis', 'district': 'PMC TAMPARULI / SMAT CHAPLAIN', 'region': 4},
    {'name': 'Alexner Mansabin', 'district': 'TAVIU', 'region': 8},
    {'name': 'Alfred Joshia Chin', 'district': 'KINABATANGAN', 'region': 9},
    {'name': 'Ariman Paulus', 'district': 'ROSOK', 'region': 1},
    {'name': 'Benedict Sisom', 'district': 'TAMPARULI', 'region': 4},
    {'name': 'Celvin Billy Maurice', 'district': 'KINARUT', 'region': 5},
    {'name': 'Charldi Marckson Lauren', 'district': 'NARINANG', 'region': 1},
    {'name': 'Clario Taipin Gadoit', 'district': 'NABALU', 'region': 3},
    {'name': 'Danny Lim Ket Shing', 'district': 'INANAM CHINESE', 'region': 5},
    {'name': 'Decksond Epol', 'district': 'TELUPID', 'region': 8},
    {'name': 'Duani Pantai', 'district': 'KAYANGAT', 'region': 2},
    {'name': 'Ebin Gopokong', 'district': 'TUNGKU', 'region': 10},
    {'name': 'Elver Doasa', 'district': 'KEPAYAN', 'region': 5},
    {'name': 'Elwin Motibih', 'district': 'ALAMESRA', 'region': 5},
    {'name': 'Erick Roy Paul', 'district': 'SUNGAI MANILA', 'region': 9},
    {'name': 'Evander E Padua', 'district': 'RANAU', 'region': 8},
    {'name': 'Francis Lajanim', 'district': 'MENGGATAL', 'region': 5},
    {'name': 'Fredlee Chin', 'district': 'BELURAN', 'region': 9},
    {'name': 'Frenky Bilu', 'district': 'LEMBAH KIMOULAU KIULU', 'region': 4},
    {'name': 'Giftor Jepth Ginda', 'district': 'SOOK', 'region': 7},
    {'name': 'Imbuhan Patrick', 'district': 'RANGALAU', 'region': 1},
    {'name': 'Jamesrail Jamil', 'district': 'TENOM', 'region': 7},
    {'name': 'Jeffienus Juas', 'district': 'SIPITANG', 'region': 6},
    {'name': 'Jeremiah Sam', 'district': 'MANTOB', 'region': 4},
    {'name': 'Jetlen Jose', 'district': 'PODOS', 'region': 1},
    {'name': 'Jivell Jiviky', 'district': 'TUNGOU', 'region': 4},
    {'name': 'Junniel Mac Daniel Gara', 'district': 'KOTA KINABALU CITY', 'region': 5},
    {'name': 'Justin Wong Chong Yung', 'district': 'KOTA KINABALU, LUYANG', 'region': 5},
    {'name': 'Libit Gutut', 'district': 'NANGOH', 'region': 9},
    {'name': 'Lovell Juil', 'district': 'LABUAN', 'region': 6},
    {'name': 'Madin Sandig', 'district': 'KIULU', 'region': 4},
    {'name': 'Maindra @ Marvin Marakus', 'district': 'LAHAD DATU', 'region': 10},
    {'name': 'Malvin Gakim', 'district': 'TAWAU', 'region': 10},
    {'name': 'Marion Martin', 'district': 'TAMBUNAN', 'region': 7},
    {'name': 'Mark Arnold Simpul', 'district': 'MALANGANG BARU', 'region': 4},
    {'name': 'Mark Gandaib', 'district': 'PENAMPANG', 'region': 5},
    {'name': 'Melrindro Rojiin Lukas', 'district': 'KOTA KINABALU, LIKAS', 'region': 5},
    {'name': 'Melvin Dickson Meliton', 'district': 'GAUR', 'region': 1},
    {'name': 'Micheal Chin Hon Kee', 'district': 'SANDAKAN', 'region': 9},
    {'name': 'Natanael Sawanai', 'district': 'SEPULUT - NABAWAN', 'region': 7},
    {'name': 'Ollan Vikenzey Kuasi', 'district': 'TENGHILAN', 'region': 2},
    {'name': 'Owen Daryl Juin', 'district': 'NAHABA', 'region': 1},
    {'name': 'R. S Ben Bryan Robit', 'district': 'GAYARATAU', 'region': 3},
    {'name': 'Rayner Dino Baninus', 'district': 'PAPAR', 'region': 6},
    {'name': 'Richard Ban Solynsem', 'district': 'KUNAK', 'region': 10},
    {'name': 'Rison Sodundu', 'district': 'TUARAN', 'region': 3},
    {'name': 'Ronald Longgou', 'district': 'MENGGATAL', 'region': 5},
    {'name': 'Ronald Majinau', 'district': 'INANAM', 'region': 5},
    {'name': 'Selamat Buloh', 'district': 'KAPA', 'region': 3},
    {'name': 'Severinus Umpok', 'district': 'KINASARABAN', 'region': 2},
    {'name': 'Soliun Sandayan', 'district': 'KOTA KINABALU, LIKAS', 'region': 5},
    {'name': 'Syeborn Bukah', 'district': 'KENINGAU', 'region': 7},
    {'name': 'Timothy Chin Wei Jun', 'district': 'KOTA KINABALU, LUYANG', 'region': 5},
    {'name': 'Vicky Vale Harold', 'district': 'SERUDUNG, TAWAU', 'region': 10},
    {'name': 'Willborn Gondolos', 'district': 'KELAWAT', 'region': 2},
    {'name': 'Willmer Barlon Duak', 'district': 'SALIKU - SUMATALUN', 'region': 7},
    {'name': 'Willter G Asin', 'district': 'BEAUFORT', 'region': 6},
    {'name': 'YM Alnanih Sangkoh', 'district': 'MANSIAT - SINULIHAN, SOOK', 'region': 7},
    {'name': 'YM Mack Aprioedry Kisi', 'district': 'SALINATAN - PENSIANGAN', 'region': 7},
  ];

  /// Update staff records with district and region assignments
  /// Returns a map with update statistics
  Future<Map<String, int>> updateStaffDistricts(String missionId) async {
    int staffUpdated = 0;
    int staffNotFound = 0;
    int staffSkipped = 0;

    // First, get all districts for this mission to create a lookup map
    final districts = await _districtService.getDistrictsByMission(missionId);
    Map<String, String> districtNameToIdMap = {};
    Map<String, int> districtToRegionMap = {};

    for (var district in districts) {
      districtNameToIdMap[district.name] = district.id;
      // Extract region number from district data
      for (var data in districtData) {
        if (data['name'] == district.name) {
          districtToRegionMap[district.name] = data['region'] as int;
          break;
        }
      }
    }

    // Get all regions to create region name to ID map
    final regions = await _regionService.getRegionsByMission(missionId);
    Map<int, String> regionNumToIdMap = {};
    for (var region in regions) {
      // Extract region number from code (e.g., "R1" -> 1)
      final regionNum = int.tryParse(region.code.replaceAll('R', ''));
      if (regionNum != null) {
        regionNumToIdMap[regionNum] = region.id;
      }
    }

    // Get all staff for this mission
    final allStaff = await _staffService.getStaffByMission(missionId);

    // Update each staff member based on the data
    for (var staffInfo in staffData) {
      final staffName = staffInfo['name'] as String;
      final districtName = staffInfo['district'] as String;
      final regionNum = staffInfo['region'] as int;

      // Find matching staff by name
      final matchingStaff = allStaff.where((s) =>
        s.name.toLowerCase().trim() == staffName.toLowerCase().trim()
      ).toList();

      if (matchingStaff.isEmpty) {
        staffNotFound++;
        continue;
      }

      // Get district ID and region ID
      final districtId = districtNameToIdMap[districtName];
      final regionId = regionNumToIdMap[regionNum];

      if (districtId == null || regionId == null) {
        staffSkipped++;
        continue;
      }

      // Update each matching staff member
      for (var staff in matchingStaff) {
        // Only update if district or region is different
        if (staff.district != districtId || staff.region != regionId) {
          final updatedStaff = staff.copyWith(
            district: districtId,
            region: regionId,
            updatedAt: DateTime.now(),
          );
          await _staffService.updateStaff(updatedStaff);
          staffUpdated++;
        } else {
          staffSkipped++;
        }
      }
    }

    return {
      'staffUpdated': staffUpdated,
      'staffNotFound': staffNotFound,
      'staffSkipped': staffSkipped,
      'totalStaff': staffData.length,
    };
  }
}
