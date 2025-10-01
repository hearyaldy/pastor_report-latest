// lib/models/user_model.dart
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final bool isAdmin;
  final bool isEditor;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.isAdmin,
    this.isEditor = false,
  });

  // Create UserModel from Firebase User and Firestore data
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      isAdmin: map['isAdmin'] ?? false,
      isEditor: map['isEditor'] ?? false,
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'isAdmin': isAdmin,
      'isEditor': isEditor,
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
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isAdmin: isAdmin ?? this.isAdmin,
      isEditor: isEditor ?? this.isEditor,
    );
  }
}
