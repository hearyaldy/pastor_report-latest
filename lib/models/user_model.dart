// lib/models/user_model.dart
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final bool isAdmin;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.isAdmin,
  });

  // Create UserModel from Firebase User and Firestore data
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      isAdmin: map['isAdmin'] ?? false,
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'isAdmin': isAdmin,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    bool? isAdmin,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
