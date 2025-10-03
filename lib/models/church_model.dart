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
    };
  }

  // Create from JSON
  factory Church.fromJson(Map<String, dynamic> json) {
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
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
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
