import 'package:cloud_firestore/cloud_firestore.dart';

/// Category for resource files
enum ResourceCategory {
  document,
  presentation,
  spreadsheet,
  image,
  video,
  audio,
  other,
}

extension ResourceCategoryExtension on ResourceCategory {
  String get displayName {
    switch (this) {
      case ResourceCategory.document:
        return 'Document';
      case ResourceCategory.presentation:
        return 'Presentation';
      case ResourceCategory.spreadsheet:
        return 'Spreadsheet';
      case ResourceCategory.image:
        return 'Image';
      case ResourceCategory.video:
        return 'Video';
      case ResourceCategory.audio:
        return 'Audio';
      case ResourceCategory.other:
        return 'Other';
    }
  }

  static ResourceCategory fromString(String value) {
    switch (value.toLowerCase()) {
      case 'document':
        return ResourceCategory.document;
      case 'presentation':
        return ResourceCategory.presentation;
      case 'spreadsheet':
        return ResourceCategory.spreadsheet;
      case 'image':
        return ResourceCategory.image;
      case 'video':
        return ResourceCategory.video;
      case 'audio':
        return ResourceCategory.audio;
      default:
        return ResourceCategory.other;
    }
  }
}

/// Model for resource files that mission admins upload
class Resource {
  final String id;
  final String name;
  final String description;
  final String fileUrl;
  final String fileName;
  final int fileSize; // in bytes
  final ResourceCategory category;
  final String missionId;
  final String uploadedBy; // User ID
  final String uploaderName; // User name for display
  final DateTime uploadedAt;
  final DateTime? updatedAt;
  final List<String> tags; // For searchability

  Resource({
    required this.id,
    required this.name,
    required this.description,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.category,
    required this.missionId,
    required this.uploadedBy,
    required this.uploaderName,
    required this.uploadedAt,
    this.updatedAt,
    this.tags = const [],
  });

  /// Convert file size to human-readable format
  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Get file extension
  String get fileExtension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'FILE';
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'category': category.name,
      'missionId': missionId,
      'uploadedBy': uploadedBy,
      'uploaderName': uploaderName,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'tags': tags,
    };
  }

  /// Create from Firestore document
  factory Resource.fromMap(Map<String, dynamic> map) {
    return Resource(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      fileName: map['fileName'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      category: ResourceCategoryExtension.fromString(map['category'] ?? 'other'),
      missionId: map['missionId'] ?? '',
      uploadedBy: map['uploadedBy'] ?? '',
      uploaderName: map['uploaderName'] ?? 'Unknown',
      uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      tags: List<String>.from(map['tags'] ?? []),
    );
  }

  /// Create from Firestore DocumentSnapshot
  factory Resource.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Resource.fromMap(data);
  }

  /// Copy with method for updates
  Resource copyWith({
    String? id,
    String? name,
    String? description,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    ResourceCategory? category,
    String? missionId,
    String? uploadedBy,
    String? uploaderName,
    DateTime? uploadedAt,
    DateTime? updatedAt,
    List<String>? tags,
  }) {
    return Resource(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      category: category ?? this.category,
      missionId: missionId ?? this.missionId,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploaderName: uploaderName ?? this.uploaderName,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
    );
  }

  @override
  String toString() {
    return 'Resource(id: $id, name: $name, category: ${category.displayName})';
  }
}
