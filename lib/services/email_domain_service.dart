import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/utils/constants.dart';

class EmailDomainService {
  EmailDomainService._();
  static final EmailDomainService instance = EmailDomainService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'settings';
  static const String _document = 'emailDomains';
  static const String _field = 'domains';

  // Returns domains from Firestore; falls back to hardcoded constants.
  Future<List<String>> getDomains() async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(_document)
          .get();
      final data = doc.data();
      if (doc.exists && data != null && data[_field] is List) {
        return List<String>.from(data[_field] as List);
      }
    } catch (_) {}
    return List<String>.from(AppConstants.allowedRegistrationEmailDomains);
  }

  // Real-time stream for the admin UI.
  Stream<List<String>> streamDomains() {
    return _firestore
        .collection(_collection)
        .doc(_document)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      if (doc.exists && data != null && data[_field] is List) {
        return List<String>.from(data[_field] as List);
      }
      return List<String>.from(AppConstants.allowedRegistrationEmailDomains);
    });
  }

  Future<void> addDomain(String domain) async {
    final cleaned = domain.trim().toLowerCase();
    if (cleaned.isEmpty) throw 'Domain cannot be empty';
    if (!RegExp(r'^[a-z0-9.-]+\.[a-z]{2,}$').hasMatch(cleaned)) {
      throw 'Invalid domain format (e.g. example.org)';
    }

    final current = await getDomains();
    if (current.contains(cleaned)) throw 'Domain already in the list';

    // Write the full list so hardcoded fallback domains are persisted on first save.
    final updated = List<String>.from(current)..add(cleaned);
    await _firestore.collection(_collection).doc(_document).set(
      {_field: updated},
      SetOptions(merge: true),
    );
  }

  Future<void> removeDomain(String domain) async {
    await _firestore.collection(_collection).doc(_document).update(
      {_field: FieldValue.arrayRemove([domain])},
    );
  }

  // Merges the hardcoded defaults into Firestore without removing any existing domains.
  Future<void> restoreDefaults() async {
    final current = await getDomains();
    final merged = {
      ...current,
      ...AppConstants.allowedRegistrationEmailDomains,
    }.toList();
    await _firestore.collection(_collection).doc(_document).set(
      {_field: merged},
      SetOptions(merge: true),
    );
  }
}
