class TeamMember {
  final String id;
  final String userId; // Pastor's user ID
  final String name;
  final String role;
  final String email;
  final String phone;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TeamMember({
    required this.id,
    required this.userId,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'role': role,
      'email': email,
      'phone': phone,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Create from JSON
  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  // Copy with method for updates
  TeamMember copyWith({
    String? id,
    String? userId,
    String? name,
    String? role,
    String? email,
    String? phone,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeamMember(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
