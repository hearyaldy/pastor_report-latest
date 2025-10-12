// lib/services/platform_file_service_web.dart
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'platform_file_service.dart';

/// Web implementation of PlatformFileService
class PlatformFileServiceImpl extends PlatformFileService {
  @override
  Future<void> saveAndShareFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    // Create a blob from the bytes
    final blob = html.Blob([bytes], mimeType);

    // Create a download link
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';

    // Add to document, click, and remove
    html.document.body?.children.add(anchor);
    anchor.click();

    // Clean up
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);

    // On web, we just trigger download, no "sharing" available
    debugPrint('File downloaded: $fileName');
  }
}

/// Factory function to create platform-specific implementation
PlatformFileService getPlatformFileService() {
  return PlatformFileServiceImpl();
}
