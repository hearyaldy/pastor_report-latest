import 'package:cloud_firestore/cloud_firestore.dart';

class Staff {
  final String id;
  final String name;
  final String role;
  final String email;
  final String phone;
  final String mission;
  final String? department;
  final String? district;
  final String? region;
  final String? photoUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy; // User ID who added this staff

  Staff({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.mission,
    this.department,
    this.district,
    this.region,
    this.photoUrl,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'email': email,
      'phone': phone,
      'mission': mission,
      'department': department,
      'district': district,
      'region': region,
      'photoUrl': photoUrl,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
    };
  }

  // Create from Firestore document
  factory Staff.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Staff(
      id: doc.id,
      name: data['name'] as String? ?? '',
      role: data['role'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      mission: data['mission'] as String? ?? '',
      department: data['department'] as String?,
      district: data['district'] as String?,
      region: data['region'] as String?,
      photoUrl: data['photoUrl'] as String?,
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  // Create from JSON (for CSV import)
  factory Staff.fromJson(Map<String, dynamic> json, String createdBy) {
    return Staff(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      mission: json['mission'] as String? ?? '',
      department: json['department'] as String?,
      district: json['district'] as String?,
      region: json['region'] as String?,
      photoUrl: json['photoUrl'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      createdBy: createdBy,
    );
  }

  // Copy with method for updates
  Staff copyWith({
    String? id,
    String? name,
    String? role,
    String? email,
    String? phone,
    String? mission,
    String? department,
    String? district,
    String? region,
    String? photoUrl,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Staff(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      mission: mission ?? this.mission,
      department: department ?? this.department,
      district: district ?? this.district,
      region: region ?? this.region,
      photoUrl: photoUrl ?? this.photoUrl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
