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

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? email,
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

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updates);
      }
    } catch (e) {
      throw 'Failed to update profile: $e';
    }
  }

  // Toggle admin status (Admin only)
  Future<void> toggleAdminStatus(String uid, bool isAdmin) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isAdmin': isAdmin,
      });
    } catch (e) {
      throw 'Failed to update admin status: $e';
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
