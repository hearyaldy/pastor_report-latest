import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

// Region mapping - number to region name
const Map<int, String> regionNames = {
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
const List<Map<String, dynamic>> districtData = [
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

void main() async {
  print('Starting to add districts and regions...');

  // TODO: Replace with your actual Firebase config
  // You need to initialize Firebase before running this
  print('ERROR: This script needs to be run from your Flutter app');
  print('Please use the Firebase console or create a proper Flutter script with Firebase initialization');
  print('\nData to add:');
  print('Regions: ${regionNames.length}');
  print('Districts: ${districtData.length}');

  // Group districts by region
  Map<int, List<String>> districtsByRegion = {};
  for (var district in districtData) {
    int regionNum = district['region'];
    if (!districtsByRegion.containsKey(regionNum)) {
      districtsByRegion[regionNum] = [];
    }
    if (!districtsByRegion[regionNum]!.contains(district['name'])) {
      districtsByRegion[regionNum]!.add(district['name']);
    }
  }

  print('\nDistricts per region:');
  districtsByRegion.forEach((regionNum, districts) {
    print('${regionNames[regionNum]}: ${districts.length} districts');
    districts.sort();
    for (var dist in districts) {
      print('  - $dist');
    }
  });
}
