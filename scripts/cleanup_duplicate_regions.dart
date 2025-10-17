import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Script to identify and remove duplicate regions
///
/// This script will:
/// 1. Find all regions for North Sabah Mission
/// 2. Identify duplicates (same name, same mission)
/// 3. Keep only the most recent region and remove older duplicates
/// 4. Show a summary of what was removed

Future<void> main() async {
  print('=== Region Cleanup Script ===\n');

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    print('✓ Firebase initialized\n');
  } catch (e) {
    print('Error initializing Firebase: $e');
    return;
  }

  final firestore = FirebaseFirestore.instance;

  // North Sabah Mission ID
  const northSabahMissionId = 'M89PoDdB5sNCoDl8qTNS';

  try {
    // Get all regions for North Sabah Mission
    print('Fetching all regions for North Sabah Mission...');
    final querySnapshot = await firestore
        .collection('regions')
        .where('missionId', isEqualTo: northSabahMissionId)
        .get();

    print('Found ${querySnapshot.docs.length} regions\n');

    // Group regions by name
    final regionsByName = <String, List<QueryDocumentSnapshot>>{};

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final name = data['name'] as String;
      regionsByName.putIfAbsent(name, () => []).add(doc);
    }

    // Display all regions
    print('=== All Regions ===');
    regionsByName.forEach((name, docs) {
      print(
          '\n$name (${docs.length} ${docs.length == 1 ? "entry" : "entries"}):');
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        print('  • ID: ${doc.id}');
        print('    Created: ${createdAt ?? "Unknown"}');
        print('    Code: ${data['code'] ?? "N/A"}');
      }
    });

    // Find duplicates
    final duplicates = <String, List<QueryDocumentSnapshot>>{};
    regionsByName.forEach((name, docs) {
      if (docs.length > 1) {
        duplicates[name] = docs;
      }
    });

    if (duplicates.isEmpty) {
      print('\n✓ No duplicates found!');
      return;
    }

    print('\n\n=== Duplicates Found ===');
    print('Found ${duplicates.length} region names with duplicates:\n');

    // For each duplicate, identify which to keep and which to remove
    final toRemove = <QueryDocumentSnapshot>[];

    duplicates.forEach((name, docs) {
      print('$name has ${docs.length} duplicates:');

      // Sort by creation date (most recent first)
      docs.sort((a, b) {
        final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bData = b.data();
        final bTime =
            (bData != null ? (bData['createdAt'] as Timestamp?) : null)
                    ?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime); // Descending (newest first)
      });

      // Keep the first (most recent), remove the rest
      final toKeep = docs.first;
      final toDelete = docs.sublist(1);

      final keepData = toKeep.data() as Map<String, dynamic>;
      final keepCreatedAt = (keepData['createdAt'] as Timestamp?)?.toDate();

      print(
          '  ✓ KEEP:   ${toKeep.id} (Created: ${keepCreatedAt ?? "Unknown"})');

      for (var doc in toDelete) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        print('  ✗ REMOVE: ${doc.id} (Created: ${createdAt ?? "Unknown"})');
        toRemove.add(doc);
      }
      print('');
    });

    // Summary
    print('=== Summary ===');
    print('Total regions: ${querySnapshot.docs.length}');
    print('Unique region names: ${regionsByName.length}');
    print('Regions to remove: ${toRemove.length}');
    print(
        'Regions after cleanup: ${querySnapshot.docs.length - toRemove.length}');

    // Ask for confirmation
    print(
        '\n⚠️  WARNING: This will delete ${toRemove.length} region(s) from the database!');
    print('Do you want to proceed? (yes/no): ');

    // Note: This is a script, so we'll just show what would be deleted
    // You need to manually confirm by uncommenting the delete code below

    print('\n❌ Deletion not executed (safety feature)');
    print(
        'To actually delete the duplicates, uncomment the deletion code in the script.');

    // UNCOMMENT THE CODE BELOW TO ACTUALLY DELETE THE DUPLICATES
    /*
    print('\nDeleting duplicates...');
    for (var doc in toRemove) {
      await firestore.collection('regions').doc(doc.id).delete();
      print('  ✓ Deleted: ${doc.id}');
    }
    print('\n✅ Cleanup completed successfully!');
    */
  } catch (e) {
    print('Error during cleanup: $e');
  }
}
