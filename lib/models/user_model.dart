// lib/models/user_model.dart

enum UserRole {
  user,
  editor,
  missionAdmin,
  admin,
  superAdmin,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.missionAdmin:
        return 'Mission Admin';
      case UserRole.editor:
        return 'Editor';
      case UserRole.user:
        return 'User';
    }
  }

  int get level {
    switch (this) {
      case UserRole.superAdmin:
        return 5;
      case UserRole.admin:
        return 4;
      case UserRole.missionAdmin:
        return 3;
      case UserRole.editor:
        return 2;
      case UserRole.user:
        return 1;
    }
  }

  bool canManageRole(UserRole targetRole) {
    return level > targetRole.level;
  }
}

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final UserRole userRole;
  final String? mission;
  final String? district;
  final String? region;
  final bool isPremium;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.userRole,
    this.mission,
    this.district,
    this.region,
    this.isPremium = false,
  });

  // Backward compatibility getters
  bool get isAdmin => userRole == UserRole.admin || userRole == UserRole.superAdmin;
  bool get isSuperAdmin => userRole == UserRole.superAdmin;
  bool get isMissionAdmin => userRole == UserRole.missionAdmin;
  bool get isEditor => userRole == UserRole.editor;
  String? get role => userRole.displayName;

  // Create UserModel from Firebase User and Firestore data
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    // Determine role from map
    UserRole role = UserRole.user;

    // Check new role field first
    if (map['userRole'] != null) {
      try {
        role = UserRole.values.firstWhere(
          (r) => r.name == map['userRole'],
          orElse: () => UserRole.user,
        );
      } catch (e) {
        role = UserRole.user;
      }
    } else {
      // Backward compatibility with old boolean flags
      if (map['email'] == 'heary@hopetv.asia') {
        role = UserRole.superAdmin;
      } else if (map['isAdmin'] == true) {
        role = UserRole.admin;
      } else if (map['isMissionAdmin'] == true) {
        role = UserRole.missionAdmin;
      } else if (map['isEditor'] == true) {
        role = UserRole.editor;
      }
    }

    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      userRole: role,
      mission: map['mission'],
      district: map['district'],
      region: map['region'],
      isPremium: map['isPremium'] ?? false,
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'userRole': userRole.name,
      // Keep backward compatibility
      'isAdmin': isAdmin,
      'isEditor': isEditor,
      'isMissionAdmin': isMissionAdmin,
      'mission': mission,
      'district': district,
      'region': region,
      'role': role,
      'isPremium': isPremium,
    };
  }

  // Get user role as string
  String get roleString => userRole.displayName;

  // Permission checks
  bool canManageUsers() => userRole.level >= UserRole.admin.level;
  bool canManageMissions() => userRole.level >= UserRole.admin.level;
  bool canManageDepartments() => userRole.level >= UserRole.missionAdmin.level;
  bool canEditDepartmentUrls() => userRole.level >= UserRole.editor.level;
  bool canCreateSuperAdmin() => userRole == UserRole.superAdmin;
  bool canAssignRole(UserRole targetRole) => userRole.canManageRole(targetRole);

  // Mission-specific permissions
  bool canManageMission(String? missionName) {
    if (userRole.level >= UserRole.admin.level) return true; // Admin can manage all
    if (userRole == UserRole.missionAdmin) return mission == missionName;
    return false;
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? userRole,
    String? mission,
    String? district,
    String? region,
    bool? isPremium,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      userRole: userRole ?? this.userRole,
      mission: mission ?? this.mission,
      district: district ?? this.district,
      region: region ?? this.region,
      isPremium: isPremium ?? this.isPremium,
    );
  }
}
