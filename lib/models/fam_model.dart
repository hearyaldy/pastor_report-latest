class FinancialActivityManagement {
  final String id;
  final String reportId;
  final double? buildingFund;
  final double? welfareFund;
  final double? missionFund;
  final double? educationFund;
  final double? youthFund;
  final double? childrenFund;
  final double? womenMinistryFund;
  final double? menMinistryFund;
  final double? seniorMinistryFund;
  final double? musicMinistryFund;
  final double? maintenanceFund;
  final double? utilitiesFund;
  final double? insuranceFund;
  final double? otherIncome;
  final double? salaries;
  final double? rent;
  final double? supplies;
  final double? transportation;
  final double? communication;
  final double? printing;
  final double? equipment;
  final double? otherExpenses;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FinancialActivityManagement({
    required this.id,
    required this.reportId,
    this.buildingFund,
    this.welfareFund,
    this.missionFund,
    this.educationFund,
    this.youthFund,
    this.childrenFund,
    this.womenMinistryFund,
    this.menMinistryFund,
    this.seniorMinistryFund,
    this.musicMinistryFund,
    this.maintenanceFund,
    this.utilitiesFund,
    this.insuranceFund,
    this.otherIncome,
    this.salaries,
    this.rent,
    this.supplies,
    this.transportation,
    this.communication,
    this.printing,
    this.equipment,
    this.otherExpenses,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  // Calculate total income from FAM activities
  double get totalIncome {
    return (buildingFund ?? 0) +
        (welfareFund ?? 0) +
        (missionFund ?? 0) +
        (educationFund ?? 0) +
        (youthFund ?? 0) +
        (childrenFund ?? 0) +
        (womenMinistryFund ?? 0) +
        (menMinistryFund ?? 0) +
        (seniorMinistryFund ?? 0) +
        (musicMinistryFund ?? 0) +
        (otherIncome ?? 0);
  }

  // Calculate total expenses from FAM activities
  double get totalExpenses {
    return (maintenanceFund ?? 0) +
        (utilitiesFund ?? 0) +
        (insuranceFund ?? 0) +
        (salaries ?? 0) +
        (rent ?? 0) +
        (supplies ?? 0) +
        (transportation ?? 0) +
        (communication ?? 0) +
        (printing ?? 0) +
        (equipment ?? 0) +
        (otherExpenses ?? 0);
  }

  // Calculate net from FAM activities
  double get netAmount => totalIncome - totalExpenses;

  factory FinancialActivityManagement.fromMap(Map<String, dynamic> map) {
    return FinancialActivityManagement(
      id: map['id'] ?? '',
      reportId: map['reportId'] ?? '',
      buildingFund: map['buildingFund']?.toDouble(),
      welfareFund: map['welfareFund']?.toDouble(),
      missionFund: map['missionFund']?.toDouble(),
      educationFund: map['educationFund']?.toDouble(),
      youthFund: map['youthFund']?.toDouble(),
      childrenFund: map['childrenFund']?.toDouble(),
      womenMinistryFund: map['womenMinistryFund']?.toDouble(),
      menMinistryFund: map['menMinistryFund']?.toDouble(),
      seniorMinistryFund: map['seniorMinistryFund']?.toDouble(),
      musicMinistryFund: map['musicMinistryFund']?.toDouble(),
      maintenanceFund: map['maintenanceFund']?.toDouble(),
      utilitiesFund: map['utilitiesFund']?.toDouble(),
      insuranceFund: map['insuranceFund']?.toDouble(),
      otherIncome: map['otherIncome']?.toDouble(),
      salaries: map['salaries']?.toDouble(),
      rent: map['rent']?.toDouble(),
      supplies: map['supplies']?.toDouble(),
      transportation: map['transportation']?.toDouble(),
      communication: map['communication']?.toDouble(),
      printing: map['printing']?.toDouble(),
      equipment: map['equipment']?.toDouble(),
      otherExpenses: map['otherExpenses']?.toDouble(),
      notes: map['notes'],
      createdAt:
          map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt:
          map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reportId': reportId,
      'buildingFund': buildingFund,
      'welfareFund': welfareFund,
      'missionFund': missionFund,
      'educationFund': educationFund,
      'youthFund': youthFund,
      'childrenFund': childrenFund,
      'womenMinistryFund': womenMinistryFund,
      'menMinistryFund': menMinistryFund,
      'seniorMinistryFund': seniorMinistryFund,
      'musicMinistryFund': musicMinistryFund,
      'maintenanceFund': maintenanceFund,
      'utilitiesFund': utilitiesFund,
      'insuranceFund': insuranceFund,
      'otherIncome': otherIncome,
      'salaries': salaries,
      'rent': rent,
      'supplies': supplies,
      'transportation': transportation,
      'communication': communication,
      'printing': printing,
      'equipment': equipment,
      'otherExpenses': otherExpenses,
      'notes': notes,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  FinancialActivityManagement copyWith({
    String? id,
    String? reportId,
    double? buildingFund,
    double? welfareFund,
    double? missionFund,
    double? educationFund,
    double? youthFund,
    double? childrenFund,
    double? womenMinistryFund,
    double? menMinistryFund,
    double? seniorMinistryFund,
    double? musicMinistryFund,
    double? maintenanceFund,
    double? utilitiesFund,
    double? insuranceFund,
    double? otherIncome,
    double? salaries,
    double? rent,
    double? supplies,
    double? transportation,
    double? communication,
    double? printing,
    double? equipment,
    double? otherExpenses,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinancialActivityManagement(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      buildingFund: buildingFund ?? this.buildingFund,
      welfareFund: welfareFund ?? this.welfareFund,
      missionFund: missionFund ?? this.missionFund,
      educationFund: educationFund ?? this.educationFund,
      youthFund: youthFund ?? this.youthFund,
      childrenFund: childrenFund ?? this.childrenFund,
      womenMinistryFund: womenMinistryFund ?? this.womenMinistryFund,
      menMinistryFund: menMinistryFund ?? this.menMinistryFund,
      seniorMinistryFund: seniorMinistryFund ?? this.seniorMinistryFund,
      musicMinistryFund: musicMinistryFund ?? this.musicMinistryFund,
      maintenanceFund: maintenanceFund ?? this.maintenanceFund,
      utilitiesFund: utilitiesFund ?? this.utilitiesFund,
      insuranceFund: insuranceFund ?? this.insuranceFund,
      otherIncome: otherIncome ?? this.otherIncome,
      salaries: salaries ?? this.salaries,
      rent: rent ?? this.rent,
      supplies: supplies ?? this.supplies,
      transportation: transportation ?? this.transportation,
      communication: communication ?? this.communication,
      printing: printing ?? this.printing,
      equipment: equipment ?? this.equipment,
      otherExpenses: otherExpenses ?? this.otherExpenses,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
