class Church {
  final String id;
  final String userId; // Pastor's user ID
  final String churchName;
  final String elderName;
  final ChurchStatus status;
  final String elderEmail;
  final String elderPhone;
  final String? address;
  final int? memberCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Organizational hierarchy fields
  final String? districtId;
  final String? regionId;
  final String? missionId;
  final String? treasurerId; // Church treasurer's user ID

  Church({
    required this.id,
    required this.userId,
    required this.churchName,
    required this.elderName,
    required this.status,
    required this.elderEmail,
    required this.elderPhone,
    this.address,
    this.memberCount,
    required this.createdAt,
    this.updatedAt,
    this.districtId,
    this.regionId,
    this.missionId,
    this.treasurerId,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'churchName': churchName,
      'elderName': elderName,
      'status': status.name,
      'elderEmail': elderEmail,
      'elderPhone': elderPhone,
      'address': address,
      'memberCount': memberCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'districtId': districtId,
      'regionId': regionId,
      'missionId': missionId,
      'treasurerId': treasurerId,
    };
  }

  // Create from JSON
  factory Church.fromJson(Map<String, dynamic> json) {
    // Helper function to parse DateTime from either String or Timestamp
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.parse(value);
      if (value is DateTime) return value;
      // Handle Firestore Timestamp
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (e) {
        return null;
      }
    }

    return Church(
      id: json['id'] as String,
      userId: json['userId'] as String,
      churchName: json['churchName'] as String,
      elderName: json['elderName'] as String,
      status: ChurchStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ChurchStatus.church,
      ),
      elderEmail: json['elderEmail'] as String,
      elderPhone: json['elderPhone'] as String,
      address: json['address'] as String?,
      memberCount: json['memberCount'] as int?,
      createdAt: parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseDateTime(json['updatedAt']),
      districtId: json['districtId'] as String?,
      regionId: json['regionId'] as String?,
      missionId: json['missionId'] as String?,
      treasurerId: json['treasurerId'] as String?,
    );
  }

  // Copy with method for updates
  Church copyWith({
    String? id,
    String? userId,
    String? churchName,
    String? elderName,
    ChurchStatus? status,
    String? elderEmail,
    String? elderPhone,
    String? address,
    int? memberCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? districtId,
    String? regionId,
    String? missionId,
    String? treasurerId,
  }) {
    return Church(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      churchName: churchName ?? this.churchName,
      elderName: elderName ?? this.elderName,
      status: status ?? this.status,
      elderEmail: elderEmail ?? this.elderEmail,
      elderPhone: elderPhone ?? this.elderPhone,
      address: address ?? this.address,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      districtId: districtId ?? this.districtId,
      regionId: regionId ?? this.regionId,
      missionId: missionId ?? this.missionId,
      treasurerId: treasurerId ?? this.treasurerId,
    );
  }
}

enum ChurchStatus {
  church,
  company,
  branch;

  String get displayName {
    switch (this) {
      case ChurchStatus.church:
        return 'Church';
      case ChurchStatus.company:
        return 'Company';
      case ChurchStatus.branch:
        return 'Branch';
    }
  }
}
