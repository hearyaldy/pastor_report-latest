// lib/models/user_model.dart
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final bool isAdmin;
  final bool isEditor;
  final String? mission;
  final String? district;
  final String? region;
  final String? role;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.isAdmin,
    this.isEditor = false,
    this.mission,
    this.district,
    this.region,
    this.role,
  });

  // Create UserModel from Firebase User and Firestore data
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      isAdmin: map['isAdmin'] ?? false,
      isEditor: map['isEditor'] ?? false,
      mission: map['mission'],
      district: map['district'],
      region: map['region'],
      role: map['role'],
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'isAdmin': isAdmin,
      'isEditor': isEditor,
      'mission': mission,
      'district': district,
      'region': region,
      'role': role,
    };
  }

  // Get user role as string
  String get roleString {
    if (isAdmin) return 'Admin';
    if (isEditor) return 'Editor';
    return 'User';
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    bool? isAdmin,
    bool? isEditor,
    String? mission,
    String? district,
    String? region,
    String? role,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isAdmin: isAdmin ?? this.isAdmin,
      isEditor: isEditor ?? this.isEditor,
      mission: mission ?? this.mission,
      district: district ?? this.district,
      region: region ?? this.region,
      role: role ?? this.role,
    );
  }
}
