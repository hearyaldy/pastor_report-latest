// lib/models/borang_b_model.dart

/// Model for Borang B - Monthly Ministerial Report
/// This is separate from activities (Borang A) and contains ministry statistics
enum ReportStatus {
  draft,
  submitted,
}

class BorangBData {
  final String id;
  final DateTime month; // Month and year this report is for
  final String userId; // Pastor's ID
  final String userName; // Pastor's name
  final String? missionId; // Mission ID
  final String? districtId; // District ID (optional)
  final String? churchId; // Church ID (optional)
  final ReportStatus status; // Report status (draft or submitted)
  final DateTime? submittedAt; // When the report was submitted

  // Church Statistics
  final int membersBeginning; // Members at beginning of month
  final int membersReceived; // New members received
  final int membersTransferredIn; // Members transferred in
  final int membersTransferredOut; // Members transferred out
  final int membersDropped; // Members dropped/removed
  final int membersDeceased; // Members deceased
  final int membersEnd; // Members at end of month

  // Baptisms
  final int baptisms; // Number of baptisms
  final int professionOfFaith; // Professions of faith

  // Church Services
  final int sabbathServices; // Number of Sabbath services conducted
  final int prayerMeetings; // Number of prayer meetings
  final int bibleStudies; // Number of Bible studies conducted
  final int evangelisticMeetings; // Evangelistic meetings

  // Visitations
  final int homeVisitations; // Home visitations
  final int hospitalVisitations; // Hospital visitations
  final int prisonVisitations; // Prison visitations

  // Special Events
  final int weddings; // Weddings conducted
  final int funerals; // Funerals conducted
  final int dedications; // Baby dedications

  // Literature Distribution
  final int booksDistributed; // Books distributed
  final int magazinesDistributed; // Magazines distributed
  final int tractsDistributed; // Tracts distributed

  // Offerings & Tithes
  final double tithe; // Tithe collected
  final double offerings; // Offerings collected

  // Other Ministry
  final String otherActivities; // Other activities (free text)
  final String challenges; // Challenges faced (free text)
  final String remarks; // Additional remarks (free text)

  final DateTime createdAt;
  final DateTime? updatedAt;

  BorangBData({
    required this.id,
    required this.month,
    required this.userId,
    required this.userName,
    this.missionId,
    this.districtId,
    this.churchId,
    this.status = ReportStatus.draft,
    this.submittedAt,
    this.membersBeginning = 0,
    this.membersReceived = 0,
    this.membersTransferredIn = 0,
    this.membersTransferredOut = 0,
    this.membersDropped = 0,
    this.membersDeceased = 0,
    this.membersEnd = 0,
    this.baptisms = 0,
    this.professionOfFaith = 0,
    this.sabbathServices = 0,
    this.prayerMeetings = 0,
    this.bibleStudies = 0,
    this.evangelisticMeetings = 0,
    this.homeVisitations = 0,
    this.hospitalVisitations = 0,
    this.prisonVisitations = 0,
    this.weddings = 0,
    this.funerals = 0,
    this.dedications = 0,
    this.booksDistributed = 0,
    this.magazinesDistributed = 0,
    this.tractsDistributed = 0,
    this.tithe = 0.0,
    this.offerings = 0.0,
    this.otherActivities = '',
    this.challenges = '',
    this.remarks = '',
    required this.createdAt,
    this.updatedAt,
  });

  /// Create from JSON
  factory BorangBData.fromJson(Map<String, dynamic> json) {
    return BorangBData(
      id: json['id'] as String,
      month: DateTime.parse(json['month'] as String),
      userId: json['userId'] as String,
      userName: json['userName'] as String? ?? '',
      missionId: json['missionId'] as String?,
      districtId: json['districtId'] as String?,
      churchId: json['churchId'] as String?,
      status: json['status'] != null
          ? ReportStatus.values.firstWhere(
              (e) => e.toString() == 'ReportStatus.${json['status']}',
              orElse: () => ReportStatus.draft)
          : ReportStatus.draft,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : null,
      membersBeginning: json['membersBeginning'] as int? ?? 0,
      membersReceived: json['membersReceived'] as int? ?? 0,
      membersTransferredIn: json['membersTransferredIn'] as int? ?? 0,
      membersTransferredOut: json['membersTransferredOut'] as int? ?? 0,
      membersDropped: json['membersDropped'] as int? ?? 0,
      membersDeceased: json['membersDeceased'] as int? ?? 0,
      membersEnd: json['membersEnd'] as int? ?? 0,
      baptisms: json['baptisms'] as int? ?? 0,
      professionOfFaith: json['professionOfFaith'] as int? ?? 0,
      sabbathServices: json['sabbathServices'] as int? ?? 0,
      prayerMeetings: json['prayerMeetings'] as int? ?? 0,
      bibleStudies: json['bibleStudies'] as int? ?? 0,
      evangelisticMeetings: json['evangelisticMeetings'] as int? ?? 0,
      homeVisitations: json['homeVisitations'] as int? ?? 0,
      hospitalVisitations: json['hospitalVisitations'] as int? ?? 0,
      prisonVisitations: json['prisonVisitations'] as int? ?? 0,
      weddings: json['weddings'] as int? ?? 0,
      funerals: json['funerals'] as int? ?? 0,
      dedications: json['dedications'] as int? ?? 0,
      booksDistributed: json['booksDistributed'] as int? ?? 0,
      magazinesDistributed: json['magazinesDistributed'] as int? ?? 0,
      tractsDistributed: json['tractsDistributed'] as int? ?? 0,
      tithe: (json['tithe'] as num?)?.toDouble() ?? 0.0,
      offerings: (json['offerings'] as num?)?.toDouble() ?? 0.0,
      otherActivities: json['otherActivities'] as String? ?? '',
      challenges: json['challenges'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'month': month.toIso8601String(),
      'userId': userId,
      'userName': userName,
      if (missionId != null) 'missionId': missionId,
      if (districtId != null) 'districtId': districtId,
      if (churchId != null) 'churchId': churchId,
      'status': status.toString().split('.').last,
      if (submittedAt != null) 'submittedAt': submittedAt!.toIso8601String(),
      'membersBeginning': membersBeginning,
      'membersReceived': membersReceived,
      'membersTransferredIn': membersTransferredIn,
      'membersTransferredOut': membersTransferredOut,
      'membersDropped': membersDropped,
      'membersDeceased': membersDeceased,
      'membersEnd': membersEnd,
      'baptisms': baptisms,
      'professionOfFaith': professionOfFaith,
      'sabbathServices': sabbathServices,
      'prayerMeetings': prayerMeetings,
      'bibleStudies': bibleStudies,
      'evangelisticMeetings': evangelisticMeetings,
      'homeVisitations': homeVisitations,
      'hospitalVisitations': hospitalVisitations,
      'prisonVisitations': prisonVisitations,
      'weddings': weddings,
      'funerals': funerals,
      'dedications': dedications,
      'booksDistributed': booksDistributed,
      'magazinesDistributed': magazinesDistributed,
      'tractsDistributed': tractsDistributed,
      'tithe': tithe,
      'offerings': offerings,
      'otherActivities': otherActivities,
      'challenges': challenges,
      'remarks': remarks,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  BorangBData copyWith({
    String? id,
    DateTime? month,
    String? userId,
    String? userName,
    String? missionId,
    String? districtId,
    String? churchId,
    ReportStatus? status,
    DateTime? submittedAt,
    int? membersBeginning,
    int? membersReceived,
    int? membersTransferredIn,
    int? membersTransferredOut,
    int? membersDropped,
    int? membersDeceased,
    int? membersEnd,
    int? baptisms,
    int? professionOfFaith,
    int? sabbathServices,
    int? prayerMeetings,
    int? bibleStudies,
    int? evangelisticMeetings,
    int? homeVisitations,
    int? hospitalVisitations,
    int? prisonVisitations,
    int? weddings,
    int? funerals,
    int? dedications,
    int? booksDistributed,
    int? magazinesDistributed,
    int? tractsDistributed,
    double? tithe,
    double? offerings,
    String? otherActivities,
    String? challenges,
    String? remarks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BorangBData(
      id: id ?? this.id,
      month: month ?? this.month,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      missionId: missionId ?? this.missionId,
      districtId: districtId ?? this.districtId,
      churchId: churchId ?? this.churchId,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      membersBeginning: membersBeginning ?? this.membersBeginning,
      membersReceived: membersReceived ?? this.membersReceived,
      membersTransferredIn: membersTransferredIn ?? this.membersTransferredIn,
      membersTransferredOut:
          membersTransferredOut ?? this.membersTransferredOut,
      membersDropped: membersDropped ?? this.membersDropped,
      membersDeceased: membersDeceased ?? this.membersDeceased,
      membersEnd: membersEnd ?? this.membersEnd,
      baptisms: baptisms ?? this.baptisms,
      professionOfFaith: professionOfFaith ?? this.professionOfFaith,
      sabbathServices: sabbathServices ?? this.sabbathServices,
      prayerMeetings: prayerMeetings ?? this.prayerMeetings,
      bibleStudies: bibleStudies ?? this.bibleStudies,
      evangelisticMeetings: evangelisticMeetings ?? this.evangelisticMeetings,
      homeVisitations: homeVisitations ?? this.homeVisitations,
      hospitalVisitations: hospitalVisitations ?? this.hospitalVisitations,
      prisonVisitations: prisonVisitations ?? this.prisonVisitations,
      weddings: weddings ?? this.weddings,
      funerals: funerals ?? this.funerals,
      dedications: dedications ?? this.dedications,
      booksDistributed: booksDistributed ?? this.booksDistributed,
      magazinesDistributed: magazinesDistributed ?? this.magazinesDistributed,
      tractsDistributed: tractsDistributed ?? this.tractsDistributed,
      tithe: tithe ?? this.tithe,
      offerings: offerings ?? this.offerings,
      otherActivities: otherActivities ?? this.otherActivities,
      challenges: challenges ?? this.challenges,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculate total members movement
  int get totalMembersGained => membersReceived + membersTransferredIn;
  int get totalMembersLost =>
      membersTransferredOut + membersDropped + membersDeceased;
  int get netMembershipChange => totalMembersGained - totalMembersLost;

  /// Calculate total visitations
  int get totalVisitations =>
      homeVisitations + hospitalVisitations + prisonVisitations;

  /// Calculate total literature
  int get totalLiterature =>
      booksDistributed + magazinesDistributed + tractsDistributed;

  /// Calculate total financial
  double get totalFinancial => tithe + offerings;

  @override
  String toString() {
    return 'BorangBData(id: $id, month: $month, userId: $userId, baptisms: $baptisms)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BorangBData && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
