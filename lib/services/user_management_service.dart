// lib/services/user_management_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pastor_report/models/user_model.dart';

class UserManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all users (Stream)
  Stream<List<UserModel>> getUsersStream() {
    return _firestore
        .collection('users')
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Get all users (one-time fetch)
  Future<List<UserModel>> getUsers() async {
    try {
      final snapshot =
          await _firestore.collection('users').orderBy('displayName').get();

      return snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw 'Failed to fetch users: $e';
    }
  }

  // Get single user
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw 'Failed to fetch user: $e';
    }
  }

  // Get current logged in user
  Future<UserModel?> getCurrentUser() async {
    try {
      final User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        return null;
      }

      return await getUser(firebaseUser.uid);
    } catch (e) {
      throw 'Failed to fetch current user: $e';
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? email,
    String? mission,
    String? district,
    String? region,
    String? role,
  }) async {
    try {
      final Map<String, dynamic> updates = {};

      if (displayName != null) {
        updates['displayName'] = displayName;
        // Also update Firebase Auth display name
        await _auth.currentUser?.updateDisplayName(displayName);
      }

      if (email != null) {
        updates['email'] = email;
      }

      if (mission != null) {
        updates['mission'] = mission;
      }

      if (district != null) {
        updates['district'] = district;
      }

      if (region != null) {
        updates['region'] = region;
      }

      if (role != null) {
        updates['roleTitle'] = role;

        // Also update userRole if the role is Church Treasurer
        if (role == 'Church Treasurer') {
          updates['userRole'] = UserRole.churchTreasurer.name;
          updates['isAdmin'] = false;
          updates['isMissionAdmin'] = false;
          updates['isEditor'] = false;
        }
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updates);
      }
    } catch (e) {
      throw 'Failed to update profile: $e';
    }
  }

  // Toggle admin status (legacy method - for backward compatibility)
  Future<void> toggleAdminStatus(String uid, bool isAdmin) async {
    try {
      if (isAdmin) {
        await updateUserRole(uid: uid, newRole: UserRole.admin);
      } else {
        await updateUserRole(uid: uid, newRole: UserRole.user);
      }
    } catch (e) {
      throw 'Failed to update admin status: $e';
    }
  }

  // Update user role using new role system
  Future<void> updateUserRole({
    required String uid,
    required UserRole newRole,
  }) async {
    try {
      // Update with the new role system
      await _firestore.collection('users').doc(uid).update({
        'userRole': newRole.name,
      });

      // Also update legacy fields for backward compatibility
      final Map<String, dynamic> legacyUpdates = {
        'isAdmin': newRole == UserRole.admin || newRole == UserRole.superAdmin,
        'isMissionAdmin': newRole == UserRole.missionAdmin,
        'isEditor': newRole == UserRole.editor,
        'isChurchTreasurer': newRole == UserRole.churchTreasurer,
      };

      await _firestore.collection('users').doc(uid).update(legacyUpdates);
    } catch (e) {
      throw 'Failed to update user role: $e';
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw 'Failed to send password reset email: $e';
    }
  }

  // Delete user (Admin only - deletes from Firestore, not Firebase Auth)
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      throw 'Failed to delete user: $e';
    }
  }

  // Update user password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
    } catch (e) {
      if (e.toString().contains('requires-recent-login')) {
        throw 'Please sign in again to update your password';
      }
      throw 'Failed to update password: $e';
    }
  }

  // Create new user (by admin)
  Future<String?> createUser({
    required String email,
    required String password,
    required String displayName,
    bool isAdmin = false,
  }) async {
    try {
      // Note: This creates a new user but doesn't sign them in
      // You might need to use Firebase Admin SDK or Cloud Functions for this in production

      // For now, we'll just create the Firestore document
      // The actual Firebase Auth user should be created via Firebase Console
      // or a Cloud Function

      final docRef = _firestore.collection('users').doc();
      await docRef.set({
        'email': email,
        'displayName': displayName,
        'isAdmin': isAdmin,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      throw 'Failed to create user: $e';
    }
  }

  // Search users by name or email
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThan: '$query\uf8ff')
          .get();

      return snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw 'Failed to search users: $e';
    }
  }
}
