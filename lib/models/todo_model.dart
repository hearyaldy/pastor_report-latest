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
    return {
      'id': id,
      'content': content,
      'audioPath': audioPath,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'priority': priority,
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      content: json['content'] as String,
      audioPath: json['audioPath'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
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
