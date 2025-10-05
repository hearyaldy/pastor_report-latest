import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for tracking tithe and offerings at church level
/// This data is synced to Firestore for district and mission-level aggregation
class FinancialReport {
  final String id;
  final String churchId;
  final String? districtId;
  final String? regionId;
  final String? missionId;
  final DateTime month; // First day of the month
  final int year;
  final double tithe;
  final double offerings;
  final double specialOfferings;
  final String? notes;
  final String submittedBy; // User ID who submitted
  final DateTime submittedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String status; // draft, submitted, approved

  FinancialReport({
    required this.id,
    required this.churchId,
    this.districtId,
    this.regionId,
    this.missionId,
    required this.month,
    required this.year,
    this.tithe = 0.0,
    this.offerings = 0.0,
    this.specialOfferings = 0.0,
    this.notes,
    required this.submittedBy,
    required this.submittedAt,
    required this.createdAt,
    this.updatedAt,
    this.status = 'draft',
  });

  /// Calculate total financial
  double get totalFinancial => tithe + offerings + specialOfferings;

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'churchId': churchId,
      'districtId': districtId,
      'regionId': regionId,
      'missionId': missionId,
      'month': Timestamp.fromDate(month),
      'year': year,
      'tithe': tithe,
      'offerings': offerings,
      'specialOfferings': specialOfferings,
      'notes': notes,
      'submittedBy': submittedBy,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'status': status,
    };
  }

  /// Create from Firestore document
  factory FinancialReport.fromMap(Map<String, dynamic> map) {
    return FinancialReport(
      id: map['id'] ?? '',
      churchId: map['churchId'] ?? '',
      districtId: map['districtId'],
      regionId: map['regionId'],
      missionId: map['missionId'],
      month: (map['month'] as Timestamp?)?.toDate() ?? DateTime.now(),
      year: map['year'] ?? DateTime.now().year,
      tithe: (map['tithe'] as num?)?.toDouble() ?? 0.0,
      offerings: (map['offerings'] as num?)?.toDouble() ?? 0.0,
      specialOfferings: (map['specialOfferings'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'],
      submittedBy: map['submittedBy'] ?? '',
      submittedAt: (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      status: map['status'] ?? 'draft',
    );
  }

  /// Create from Firestore DocumentSnapshot
  factory FinancialReport.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FinancialReport.fromMap(data);
  }

  /// Copy with method for updates
  FinancialReport copyWith({
    String? id,
    String? churchId,
    String? districtId,
    String? regionId,
    String? missionId,
    DateTime? month,
    int? year,
    double? tithe,
    double? offerings,
    double? specialOfferings,
    String? notes,
    String? submittedBy,
    DateTime? submittedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return FinancialReport(
      id: id ?? this.id,
      churchId: churchId ?? this.churchId,
      districtId: districtId ?? this.districtId,
      regionId: regionId ?? this.regionId,
      missionId: missionId ?? this.missionId,
      month: month ?? this.month,
      year: year ?? this.year,
      tithe: tithe ?? this.tithe,
      offerings: offerings ?? this.offerings,
      specialOfferings: specialOfferings ?? this.specialOfferings,
      notes: notes ?? this.notes,
      submittedBy: submittedBy ?? this.submittedBy,
      submittedAt: submittedAt ?? this.submittedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'FinancialReport(id: $id, churchId: $churchId, month: $month, tithe: $tithe, offerings: $offerings)';
  }
}
