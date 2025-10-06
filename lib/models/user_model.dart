// lib/models/user_model.dart

enum UserRole {
  user,
  churchTreasurer,
  ministerialSecretary,
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
      case UserRole.ministerialSecretary:
        return 'Ministerial Secretary';
      case UserRole.editor:
        return 'Editor';
      case UserRole.churchTreasurer:
        return 'Church Treasurer';
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
      case UserRole.ministerialSecretary:
        return 3; // Same level as mission admin for accessing mission reports
      case UserRole.editor:
        return 2;
      case UserRole.churchTreasurer:
        return 1; // Same level as regular user in hierarchy
      case UserRole.user:
        return 1;
    }
  }

  bool canManageRole(UserRole targetRole) {
    // SuperAdmin can assign any role
    if (this == UserRole.superAdmin) {
      return true;
    }

    // Admin can only assign missionAdmin, editor, churchTreasurer or user
    if (this == UserRole.admin) {
      return targetRole != UserRole.admin && targetRole != UserRole.superAdmin;
    }

    // MissionAdmin can only assign ministerialSecretary, editor, churchTreasurer or user
    if (this == UserRole.missionAdmin) {
      return targetRole == UserRole.ministerialSecretary ||
          targetRole == UserRole.editor ||
          targetRole == UserRole.churchTreasurer ||
          targetRole == UserRole.user;
    }

    // Other roles cannot assign roles
    return false;
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
  final String?
      roleTitle; // Stores the specific role title (e.g. District Pastor, Mission Officer)
  final String? churchId; // For church treasurers - assigned church ID
  final bool isPremium;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.userRole,
    this.mission,
    this.district,
    this.region,
    this.roleTitle,
    this.churchId,
    this.isPremium = false,
  });

  // Backward compatibility getters
  bool get isAdmin =>
      userRole == UserRole.admin || userRole == UserRole.superAdmin;
  bool get isSuperAdmin => userRole == UserRole.superAdmin;
  bool get isMissionAdmin => userRole == UserRole.missionAdmin;
  bool get isMinisterialSecretary => userRole == UserRole.ministerialSecretary;
  bool get isEditor => userRole == UserRole.editor;
  bool get isChurchTreasurer => userRole == UserRole.churchTreasurer;
  bool get canAccessFinancialReports =>
      userRole == UserRole.churchTreasurer || isAdmin || isSuperAdmin;
  // Only Ministerial Secretary and Super Admin can view all Borang B reports
  bool get canAccessBorangBReports =>
      isMinisterialSecretary || isSuperAdmin;
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
      } else if (map['isChurchTreasurer'] == true) {
        role = UserRole.churchTreasurer;
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
      roleTitle: map['roleTitle'],
      churchId: map['churchId'],
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
      'roleTitle': roleTitle,
      'churchId': churchId,
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
    if (userRole.level >= UserRole.admin.level) {
      return true; // Admin can manage all
    }
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
    String? roleTitle,
    String? churchId,
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
      roleTitle: roleTitle ?? this.roleTitle,
      churchId: churchId ?? this.churchId,
      isPremium: isPremium ?? this.isPremium,
    );
  }
}
