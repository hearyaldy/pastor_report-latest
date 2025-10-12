// lib/services/platform_file_service.dart
import 'package:flutter/foundation.dart';

// Conditional imports based on platform
import 'platform_file_service_mobile.dart'
    if (dart.library.html) 'platform_file_service_web.dart';

/// Platform-agnostic file service that handles file operations
/// for both web and mobile platforms
abstract class PlatformFileService {
  /// Save and share a file with the given bytes
  /// On mobile: saves to documents directory and shares
  /// On web: triggers download
  Future<void> saveAndShareFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });

  /// Get a singleton instance
  static PlatformFileService getInstance() {
    return getPlatformFileService();
  }
}
