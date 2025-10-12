// lib/services/platform_file_service_mobile.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'platform_file_service.dart';

/// Mobile implementation of PlatformFileService
class PlatformFileServiceImpl extends PlatformFileService {
  @override
  Future<void> saveAndShareFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    // Save file to temporary directory
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    // Share the file
    await Share.shareXFiles(
      [XFile(filePath, mimeType: mimeType)],
      subject: fileName,
    );
  }
}

/// Factory function to create platform-specific implementation
PlatformFileService getPlatformFileService() {
  return PlatformFileServiceImpl();
}
