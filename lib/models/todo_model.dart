import 'package:cloud_firestore/cloud_firestore.dart';

class Todo {
  final String id;
  final String content;
  final String? audioPath; // Path to audio file if recorded
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int priority; // 0: Low, 1: Medium, 2: High

  Todo({
    required this.id,
    required this.content,
    this.audioPath,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
    this.priority = 0,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'content': content,
      'audioPath': audioPath,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'priority': priority,
    };
    // Only include id if it's not empty
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    // Helper function to convert Timestamp or String to DateTime
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    return Todo(
      id: json['id'] as String? ?? '',
      content: json['content'] as String,
      audioPath: json['audioPath'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: parseDateTime(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? parseDateTime(json['completedAt'])
          : null,
      priority: json['priority'] as int? ?? 0,
    );
  }

  Todo copyWith({
    String? id,
    String? content,
    String? audioPath,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
    int? priority,
  }) {
    return Todo(
      id: id ?? this.id,
      content: content ?? this.content,
      audioPath: audioPath ?? this.audioPath,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      priority: priority ?? this.priority,
    );
  }

  String get priorityText {
    switch (priority) {
      case 2:
        return 'High';
      case 1:
        return 'Medium';
      default:
        return 'Low';
    }
  }
}
