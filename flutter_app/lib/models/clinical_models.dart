/// Domain models for clinical risk stratification & vital signs
enum ClinicalRiskLevel {
  low,
  moderate,
  high,
  critical;

  String get displayName {
    switch (this) {
      case ClinicalRiskLevel.low:
        return 'Low Risk';
      case ClinicalRiskLevel.moderate:
        return 'Moderate Risk';
      case ClinicalRiskLevel.high:
        return 'High Risk';
      case ClinicalRiskLevel.critical:
        return 'Critical Risk';
    }
  }
}

/// Strongly-typed NEWS2 Score Result
class NEWS2ScoreResult {
  final int score;
  final String riskLevel;
  final String action;
  final Map<String, dynamic> parameterScores;

  const NEWS2ScoreResult({
    required this.score,
    required this.riskLevel,
    required this.action,
    this.parameterScores = const {},
  });

  factory NEWS2ScoreResult.fromMap(Map<String, dynamic> map) {
    return NEWS2ScoreResult(
      score: map['score'] as int? ?? 0,
      riskLevel: map['risk_level'] as String? ?? 'Normal / Low Risk',
      action: map['action'] as String? ?? 'Monitor vitals per standard schedule.',
      parameterScores: map['parameter_scores'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'risk_level': riskLevel,
      'action': action,
      'parameter_scores': parameterScores,
    };
  }
}

/// Strongly-typed Sepsis Risk Result
class SepsisRiskResult {
  final String riskPercent;
  final String riskLevel;
  final String primaryContributingFactor;
  final bool isHighRisk;

  const SepsisRiskResult({
    required this.riskPercent,
    required this.riskLevel,
    this.primaryContributingFactor = 'Normal Range Vitals',
    this.isHighRisk = false,
  });

  factory SepsisRiskResult.fromMap(Map<String, dynamic> map) {
    final level = map['risk_level'] as String? ?? 'Normal / Low Risk';
    final isHigh = level.contains('High') || level.contains('Critical');
    return SepsisRiskResult(
      riskPercent: map['risk_percent'] as String? ?? '0%',
      riskLevel: level,
      primaryContributingFactor: map['contributing_factor'] as String? ?? 'Normal Range Vitals',
      isHighRisk: isHigh,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'risk_percent': riskPercent,
      'risk_level': riskLevel,
      'contributing_factor': primaryContributingFactor,
      'is_high_risk': isHighRisk,
    };
  }
}

/// Strongly-typed Vital Record snapshot
class VitalRecordModel {
  final int? id;
  final int memberId;
  final double? systolicBp;
  final double? diastolicBp;
  final double? heartRate;
  final double? spo2;
  final double? temperature;
  final double? bloodGlucose;
  final double? respiratoryRate;
  final int? news2Score;
  final String? sepsisRiskLevel;
  final DateTime recordedAt;

  const VitalRecordModel({
    this.id,
    required this.memberId,
    this.systolicBp,
    this.diastolicBp,
    this.heartRate,
    this.spo2,
    this.temperature,
    this.bloodGlucose,
    this.respiratoryRate,
    this.news2Score,
    this.sepsisRiskLevel,
    required this.recordedAt,
  });

  factory VitalRecordModel.fromMap(Map<String, dynamic> map) {
    return VitalRecordModel(
      id: map['id'] as int?,
      memberId: map['member_id'] as int? ?? 0,
      systolicBp: (map['systolic_bp'] as num?)?.toDouble(),
      diastolicBp: (map['diastolic_bp'] as num?)?.toDouble(),
      heartRate: (map['heart_rate'] as num?)?.toDouble(),
      spo2: (map['spo2'] as num?)?.toDouble(),
      temperature: (map['temperature'] as num?)?.toDouble(),
      bloodGlucose: (map['blood_glucose'] as num?)?.toDouble(),
      respiratoryRate: (map['respiratory_rate'] as num?)?.toDouble(),
      news2Score: map['news2_score'] as int?,
      sepsisRiskLevel: map['sepsis_risk_level'] as String?,
      recordedAt: map['recorded_at'] != null
          ? DateTime.tryParse(map['recorded_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'member_id': memberId,
      'systolic_bp': systolicBp,
      'diastolic_bp': diastolicBp,
      'heart_rate': heartRate,
      'spo2': spo2,
      'temperature': temperature,
      'blood_glucose': bloodGlucose,
      'respiratory_rate': respiratoryRate,
      'news2_score': news2Score,
      'sepsis_risk_level': sepsisRiskLevel,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }
}
