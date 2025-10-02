class Event {
  final String id;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final String? location;
  final bool isGlobal; // true: from online/Firestore, false: local storage
  final String? imageUrl;
  final String? organizer;
  final DateTime createdAt;

  Event({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    this.endDate,
    this.location,
    this.isGlobal = false,
    this.imageUrl,
    this.organizer,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'location': location,
      'isGlobal': isGlobal,
      'imageUrl': imageUrl,
      'organizer': organizer,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      location: json['location'] as String?,
      isGlobal: json['isGlobal'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String?,
      organizer: json['organizer'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    bool? isGlobal,
    String? imageUrl,
    String? organizer,
    DateTime? createdAt,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      isGlobal: isGlobal ?? this.isGlobal,
      imageUrl: imageUrl ?? this.imageUrl,
      organizer: organizer ?? this.organizer,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isPast => (endDate ?? startDate).isBefore(DateTime.now());
  bool get isOngoing {
    final now = DateTime.now();
    return startDate.isBefore(now) && (endDate?.isAfter(now) ?? false);
  }
  bool get isUpcoming => startDate.isAfter(DateTime.now());
}
