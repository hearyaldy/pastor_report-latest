// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/services/email_domain_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserModel?> signInWithEmailPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        // Reload to get the latest emailVerified flag from Firebase
        await user.reload();
        final refreshed = _auth.currentUser;
        if (refreshed == null || !refreshed.emailVerified) {
          await _auth.signOut();
          throw 'email-not-verified';
        }
        return await getUserData(user.uid);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      // Re-throw our own string errors unchanged
      rethrow;
    }
  }

  // Resend verification email — signs in, sends email, then signs back out
  Future<void> resendVerificationEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  // Register with email and password
  Future<UserModel?> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
    UserRole userRole = UserRole.user,
    String? mission,
    String? district,
    String? region,
    String? role,
    String? churchId,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final allowedDomains = await EmailDomainService.instance.getDomains();
      final isAllowedDomain = allowedDomains.any(
        (domain) => normalizedEmail.endsWith('@${domain.toLowerCase()}'),
      );

      if (!isAllowedDomain) {
        throw 'Please use an organization email address';
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        // Determine user role based on selected role
        if (role == 'Church Treasurer') {
          userRole = UserRole.churchTreasurer;
        }

        // Create user document in Firestore
        UserModel userModel = UserModel(
          uid: user.uid,
          email: normalizedEmail,
          displayName: displayName,
          userRole: userRole,
          mission: mission,
          district: district,
          region: region,
          roleTitle: role,
          churchId: churchId,
        );

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toMap());

        // Update display name in Firebase Auth
        await user.updateDisplayName(displayName);

        // Send email verification — user must verify before logging in
        await user.sendEmailVerification();

        // Sign out immediately so the app stays on the login screen
        await _auth.signOut();

        return userModel;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      }
      return null;
    } catch (e) {
      throw 'Failed to fetch user data';
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'Failed to sign out';
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to send password reset email';
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    bool? isAdmin,
    String? region,
    String? district,
    String? churchId,
    UserRole? userRole,
    String? roleTitle,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (displayName != null) updates['displayName'] = displayName;
      if (isAdmin != null) updates['isAdmin'] = isAdmin;
      if (region != null) updates['region'] = region;
      if (district != null) updates['district'] = district;
      if (churchId != null) updates['churchId'] = churchId;
      if (userRole != null) {
        updates['userRole'] = userRole.toString().split('.').last;
      }
      if (roleTitle != null) updates['roleTitle'] = roleTitle;

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updates);

        if (displayName != null && currentUser != null) {
          await currentUser!.updateDisplayName(displayName);
        }
      }
    } catch (e) {
      throw 'Failed to update profile';
    }
  }

  // Complete onboarding profile
  Future<void> completeOnboarding({
    required String uid,
    required String missionId,
    String? region,
    String? district,
    String? churchId,
    List<String>? churchIds,
    UserRole? userRole,
    String? roleTitle,
  }) async {
    try {
      Map<String, dynamic> updates = {
        'mission': missionId,
        'onboardingCompleted': true,
      };

      // Only add region and district if they are provided
      if (region != null) {
        updates['region'] = region;
      }
      if (district != null) {
        updates['district'] = district;
      }

      // Support both single churchId (backward compatibility) and multiple churchIds
      if (churchIds != null && churchIds.isNotEmpty) {
        updates['churchIds'] = churchIds;
        // For backward compatibility, also set churchId to the first one
        updates['churchId'] = churchIds.first;
      } else if (churchId != null) {
        updates['churchId'] = churchId;
        updates['churchIds'] = [churchId];
      }

      if (userRole != null) {
        updates['userRole'] = userRole.toString().split('.').last;
      }
      if (roleTitle != null) updates['roleTitle'] = roleTitle;

      await _firestore.collection('users').doc(uid).update(updates);
    } catch (e) {
      throw 'Failed to complete onboarding: $e';
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
}
