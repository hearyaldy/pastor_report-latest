import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage profile picture locally (not synced to Firebase)
class ProfilePictureService {
  static const String _profilePictureKey = 'profile_picture_path';
  static ProfilePictureService? _instance;

  static ProfilePictureService get instance {
    _instance ??= ProfilePictureService._();
    return _instance!;
  }

  ProfilePictureService._();

  final ImagePicker _picker = ImagePicker();

  /// Get the saved profile picture path
  Future<String?> getProfilePicturePath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_profilePictureKey);

      // Verify the file still exists
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          return path;
        } else {
          // File was deleted, remove from preferences
          await clearProfilePicture();
          return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting profile picture path: $e');
      return null;
    }
  }

  /// Pick an image from gallery using Android Photo Picker
  /// This uses the system photo picker and doesn't require READ_MEDIA_IMAGES permission
  Future<String?> pickProfilePicture() async {
    try {
      // Use the photo picker (Android 11+ / iOS 14+)
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) {
        debugPrint('No image selected');
        return null;
      }

      // Save to app's local directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_picture_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = '${appDir.path}/$fileName';

      // Copy the file
      final File imageFile = File(image.path);
      await imageFile.copy(savedPath);

      // Delete old profile picture if exists
      await _deleteOldProfilePicture();

      // Save the path to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profilePictureKey, savedPath);

      debugPrint('Profile picture saved to: $savedPath');
      return savedPath;
    } catch (e) {
      debugPrint('Error picking profile picture: $e');
      return null;
    }
  }

  /// Take a photo using camera
  Future<String?> takeProfilePicture() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) {
        debugPrint('No photo taken');
        return null;
      }

      // Save to app's local directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_picture_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = '${appDir.path}/$fileName';

      // Copy the file
      final File imageFile = File(image.path);
      await imageFile.copy(savedPath);

      // Delete old profile picture if exists
      await _deleteOldProfilePicture();

      // Save the path to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profilePictureKey, savedPath);

      debugPrint('Profile picture saved to: $savedPath');
      return savedPath;
    } catch (e) {
      debugPrint('Error taking profile picture: $e');
      return null;
    }
  }

  /// Clear the profile picture
  Future<void> clearProfilePicture() async {
    try {
      await _deleteOldProfilePicture();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profilePictureKey);
      debugPrint('Profile picture cleared');
    } catch (e) {
      debugPrint('Error clearing profile picture: $e');
    }
  }

  /// Delete old profile picture file
  Future<void> _deleteOldProfilePicture() async {
    try {
      final oldPath = await getProfilePicturePath();
      if (oldPath != null) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
          debugPrint('Deleted old profile picture: $oldPath');
        }
      }
    } catch (e) {
      debugPrint('Error deleting old profile picture: $e');
    }
  }
}
