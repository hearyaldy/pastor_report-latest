// lib/services/role_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/user_model.dart';

class RoleService {
  static final RoleService instance = RoleService._internal();
  factory RoleService() => instance;
  RoleService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';

  /// Update user role with permission checks
  Future<bool> updateUserRole({
    required String targetUserId,
    required UserRole newRole,
    required UserModel currentUser,
  }) async {
    try {
      // Permission check: can current user assign this role?
      if (!currentUser.canAssignRole(newRole)) {
        throw Exception('You do not have permission to assign this role');
      }

      // Special check: only SuperAdmin can create SuperAdmin
      if (newRole == UserRole.superAdmin && !currentUser.canCreateSuperAdmin()) {
        throw Exception('Only SuperAdmin can assign SuperAdmin role');
      }

      // Update user role
      await _firestore.collection(_usersCollection).doc(targetUserId).update({
        'userRole': newRole.name,
        // Update backward compatibility flags
        'isAdmin': newRole == UserRole.admin || newRole == UserRole.superAdmin,
        'isMissionAdmin': newRole == UserRole.missionAdmin,
        'isEditor': newRole == UserRole.editor,
        'role': newRole.displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Get available roles that current user can assign
  List<UserRole> getAssignableRoles(UserModel currentUser) {
    if (currentUser.userRole == UserRole.superAdmin) {
      // SuperAdmin can assign all roles
      return UserRole.values;
    } else if (currentUser.userRole == UserRole.admin) {
      // Admin can assign all except SuperAdmin
      return UserRole.values.where((role) => role != UserRole.superAdmin).toList();
    } else if (currentUser.userRole == UserRole.missionAdmin) {
      // Mission Admin can only assign Editor and User within their mission
      return [UserRole.editor, UserRole.user];
    } else {
      // Others cannot assign roles
      return [];
    }
  }

  /// Check if user can manage another user
  bool canManageUser({
    required UserModel currentUser,
    required UserModel targetUser,
  }) {
    // SuperAdmin can manage everyone
    if (currentUser.userRole == UserRole.superAdmin) return true;

    // Admin can manage everyone except SuperAdmin
    if (currentUser.userRole == UserRole.admin) {
      return targetUser.userRole != UserRole.superAdmin;
    }

    // Mission Admin can only manage users in their mission (Editor and User roles)
    if (currentUser.userRole == UserRole.missionAdmin) {
      return currentUser.mission == targetUser.mission &&
          (targetUser.userRole == UserRole.editor || targetUser.userRole == UserRole.user);
    }

    return false;
  }

  /// Update user mission assignment
  Future<bool> updateUserMission({
    required String targetUserId,
    required String? mission,
    required UserModel currentUser,
  }) async {
    try {
      // Check permission
      if (!currentUser.canManageMissions()) {
        throw Exception('You do not have permission to assign missions');
      }

      await _firestore.collection(_usersCollection).doc(targetUserId).update({
        'mission': mission,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Initialize SuperAdmin (heary@hopetv.asia)
  Future<void> initializeSuperAdmin() async {
    try {
      // Find user with email heary@hopetv.asia
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: 'heary@hopetv.asia')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        await _firestore.collection(_usersCollection).doc(doc.id).update({
          'userRole': UserRole.superAdmin.name,
          'isAdmin': true,
          'isMissionAdmin': false,
          'isEditor': false,
          'role': UserRole.superAdmin.displayName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Silently fail - user might not exist yet
    }
  }

  /// Update user premium status
  Future<bool> updatePremiumStatus({
    required String targetUserId,
    required bool isPremium,
    required UserModel currentUser,
  }) async {
    try {
      // Only SuperAdmin and Admin can manage premium status
      if (!currentUser.canManageUsers()) {
        throw Exception('You do not have permission to manage premium status');
      }

      await _firestore.collection(_usersCollection).doc(targetUserId).update({
        'isPremium': isPremium,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Get filtered users stream based on current user role
  Stream<QuerySnapshot> getUsersStream(UserModel currentUser) {
    Query query = _firestore.collection(_usersCollection);

    // Mission Admin sees only their mission users
    if (currentUser.userRole == UserRole.missionAdmin) {
      query = query.where('mission', isEqualTo: currentUser.mission);
    }

    return query.snapshots();
  }

  /// Check if user can edit department URLs
  bool canEditDepartmentUrls(UserModel user) {
    return user.canEditDepartmentUrls();
  }

  /// Check if user can manage departments
  bool canManageDepartments(UserModel user) {
    return user.canManageDepartments();
  }

  /// Check if user can manage missions
  bool canManageMissions(UserModel user) {
    return user.canManageMissions();
  }

  /// Check if user can manage specific mission
  bool canManageMission(UserModel user, String? missionName) {
    return user.canManageMission(missionName);
  }
}
