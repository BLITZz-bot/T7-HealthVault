class MemberModel {
  final int? id;
  final int familyId;
  final String fullName;
  final int age;
  final String gender;
  final String relationToHead;
  final String? abhaId;
  final String? mobileNumber;
  final bool isPregnant;
  final String? lmpDate;
  final String? eddDate;
  final bool isHighRiskPregnancy;
  final bool isLactating;
  final bool td1Vaccine;
  final bool td2Vaccine;
  final bool tdBooster;
  final int ifaTabletsGiven;
  final int calciumTabletsGiven;
  final double? birthWeight;
  final String? deliveryType;
  final double? muacCm;
  final bool hasChronicCondition;
  final String? chronicNotes;
  final String? photoBase64;
  final int? latestNews2Score;
  final String? latestSepsisRisk;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MemberModel({
    this.id,
    required this.familyId,
    required this.fullName,
    required this.age,
    required this.gender,
    required this.relationToHead,
    this.abhaId,
    this.mobileNumber,
    this.isPregnant = false,
    this.lmpDate,
    this.eddDate,
    this.isHighRiskPregnancy = false,
    this.isLactating = false,
    this.td1Vaccine = false,
    this.td2Vaccine = false,
    this.tdBooster = false,
    this.ifaTabletsGiven = 0,
    this.calciumTabletsGiven = 0,
    this.birthWeight,
    this.deliveryType,
    this.muacCm,
    this.hasChronicCondition = false,
    this.chronicNotes,
    this.photoBase64,
    this.latestNews2Score,
    this.latestSepsisRisk,
    required this.createdAt,
    this.updatedAt,
  });

  factory MemberModel.fromMap(Map<String, dynamic> map) {
    return MemberModel(
      id: map['id'] as int?,
      familyId: map['family_id'] as int? ?? 0,
      fullName: map['full_name'] as String? ?? map['name'] as String? ?? 'Unknown Patient',
      age: map['age'] is int
          ? map['age'] as int
          : int.tryParse(map['age']?.toString() ?? '0') ?? 0,
      gender: map['gender'] as String? ?? 'Other',
      relationToHead: map['relation_to_head'] as String? ?? map['relationship_to_head'] as String? ?? map['relation'] as String? ?? 'Self',
      abhaId: map['abha_id'] as String?,
      mobileNumber: map['mobile_number'] as String?,
      isPregnant: (map['is_pregnant'] == 1 || map['is_pregnant'] == true),
      lmpDate: map['lmp_date'] as String?,
      eddDate: map['edd_date'] as String?,
      isHighRiskPregnancy: (map['is_high_risk_pregnancy'] == 1 || map['is_high_risk_pregnancy'] == true),
      isLactating: (map['is_lactating'] == 1 || map['is_lactating'] == true),
      td1Vaccine: (map['td1_vaccine'] == 1 || map['td1_vaccine'] == true),
      td2Vaccine: (map['td2_vaccine'] == 1 || map['td2_vaccine'] == true),
      tdBooster: (map['td_booster'] == 1 || map['td_booster'] == true),
      ifaTabletsGiven: map['ifa_tablets_given'] as int? ?? 0,
      calciumTabletsGiven: map['calcium_tablets_given'] as int? ?? 0,
      birthWeight: (map['birth_weight'] as num?)?.toDouble(),
      deliveryType: map['delivery_type'] as String?,
      muacCm: (map['muac_cm'] as num?)?.toDouble(),
      hasChronicCondition: (map['has_chronic_condition'] == 1 || map['has_chronic_condition'] == true),
      chronicNotes: map['chronic_notes'] as String?,
      photoBase64: map['photo_base64'] as String? ?? map['profile_image'] as String?,
      latestNews2Score: map['latest_news2_score'] as int?,
      latestSepsisRisk: map['latest_sepsis_risk'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'family_id': familyId,
      'full_name': fullName,
      'age': age,
      'gender': gender,
      'relation_to_head': relationToHead,
      'abha_id': abhaId,
      'mobile_number': mobileNumber,
      'is_pregnant': isPregnant ? 1 : 0,
      'lmp_date': lmpDate,
      'edd_date': eddDate,
      'is_high_risk_pregnancy': isHighRiskPregnancy ? 1 : 0,
      'is_lactating': isLactating ? 1 : 0,
      'td1_vaccine': td1Vaccine ? 1 : 0,
      'td2_vaccine': td2Vaccine ? 1 : 0,
      'td_booster': tdBooster ? 1 : 0,
      'ifa_tablets_given': ifaTabletsGiven,
      'calcium_tablets_given': calciumTabletsGiven,
      'birth_weight': birthWeight,
      'delivery_type': deliveryType,
      'muac_cm': muacCm,
      'has_chronic_condition': hasChronicCondition ? 1 : 0,
      'chronic_notes': chronicNotes,
      'photo_base64': photoBase64,
      'profile_image': photoBase64,
      'latest_news2_score': latestNews2Score,
      'latest_sepsis_risk': latestSepsisRisk,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }


  MemberModel copyWith({
    int? id,
    int? familyId,
    String? fullName,
    int? age,
    String? gender,
    String? relationToHead,
    String? abhaId,
    String? mobileNumber,
    bool? isPregnant,
    bool? hasChronicCondition,
    String? photoBase64,
    int? latestNews2Score,
    String? latestSepsisRisk,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemberModel(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      relationToHead: relationToHead ?? this.relationToHead,
      abhaId: abhaId ?? this.abhaId,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      isPregnant: isPregnant ?? this.isPregnant,
      hasChronicCondition: hasChronicCondition ?? this.hasChronicCondition,
      photoBase64: photoBase64 ?? this.photoBase64,
      latestNews2Score: latestNews2Score ?? this.latestNews2Score,
      latestSepsisRisk: latestSepsisRisk ?? this.latestSepsisRisk,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
