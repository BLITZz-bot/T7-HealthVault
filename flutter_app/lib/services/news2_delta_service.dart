/// NEWS2 (National Early Warning Score 2) & DELTA Variation Service
/// Standard: UK Royal College of Physicians (RCP)
/// Standardized for Community Health & Primary Care Clinical Decision Support.
class NEWS2DeltaService {
  /// Compute NEWS2 score for a single medical record
  /// Vitals used:
  /// - Respiratory Rate (breaths/min)
  /// - SpO2 (%) (Scale 1 standard)
  /// - Systolic Blood Pressure (mmHg)
  /// - Pulse Rate / Heart Rate (bpm)
  /// - Temperature (°F converted to °C)
  static Map<String, dynamic> evaluateNEWS2(Map<String, dynamic> record) {
    final breakdown = <String, int>{};

    // 1. Respiratory Rate
    final rr = (record['respiratory_rate'] as num?)?.toInt();
    int rrScore = 0;
    if (rr != null) {
      if (rr <= 8) {
        rrScore = 3;
      } else if (rr >= 9 && rr <= 11) {
        rrScore = 1;
      } else if (rr >= 12 && rr <= 20) {
        rrScore = 0;
      } else if (rr >= 21 && rr <= 24) {
        rrScore = 2;
      } else if (rr >= 25) {
        rrScore = 3;
      }
    }
    breakdown['Respiratory Rate'] = rrScore;

    // 2. Oxygen Saturation (SpO2 Scale 1)
    final spo2 = (record['spo2'] as num?)?.toInt();
    int spo2Score = 0;
    if (spo2 != null) {
      if (spo2 <= 91) {
        spo2Score = 3;
      } else if (spo2 == 92 || spo2 == 93) {
        spo2Score = 2;
      } else if (spo2 == 94 || spo2 == 95) {
        spo2Score = 1;
      } else if (spo2 >= 96) {
        spo2Score = 0;
      }
    }
    breakdown['SpO2'] = spo2Score;

    // 3. Systolic Blood Pressure
    final sbp = (record['blood_pressure_systolic'] as num?)?.toInt();
    int sbpScore = 0;
    if (sbp != null) {
      if (sbp <= 90) {
        sbpScore = 3;
      } else if (sbp >= 91 && sbp <= 100) {
        sbpScore = 2;
      } else if (sbp >= 101 && sbp <= 110) {
        sbpScore = 1;
      } else if (sbp >= 111 && sbp <= 219) {
        sbpScore = 0;
      } else if (sbp >= 220) {
        sbpScore = 3;
      }
    }
    breakdown['Blood Pressure'] = sbpScore;

    // 4. Pulse / Heart Rate
    final hr = (record['pulse_rate'] as num?)?.toInt();
    int hrScore = 0;
    if (hr != null) {
      if (hr <= 40) {
        hrScore = 3;
      } else if (hr >= 41 && hr <= 50) {
        hrScore = 1;
      } else if (hr >= 51 && hr <= 90) {
        hrScore = 0;
      } else if (hr >= 91 && hr <= 110) {
        hrScore = 1;
      } else if (hr >= 111 && hr <= 130) {
        hrScore = 2;
      } else if (hr >= 131) {
        hrScore = 3;
      }
    }
    breakdown['Heart Rate'] = hrScore;

    // 5. Temperature (°F to °C if > 45, else assume °C)
    final tempRaw = (record['temperature'] as num?)?.toDouble();
    int tempScore = 0;
    if (tempRaw != null) {
      final tempC = tempRaw > 45 ? ((tempRaw - 32) * 5 / 9) : tempRaw;
      if (tempC <= 35.0) {
        tempScore = 3;
      } else if (tempC >= 35.1 && tempC <= 36.0) {
        tempScore = 1;
      } else if (tempC >= 36.1 && tempC <= 38.0) {
        tempScore = 0;
      } else if (tempC >= 38.1 && tempC <= 39.0) {
        tempScore = 1;
      } else if (tempC >= 39.1) {
        tempScore = 2;
      }
    }
    breakdown['Temperature'] = tempScore;

    final totalScore = rrScore + spo2Score + sbpScore + hrScore + tempScore;

    String riskLevel = 'Low Risk';
    String riskColor = '#4CAF50'; // Green
    String actionRecommendation = 'Routine monitoring per schedule';

    // Individual extreme trigger (any vital scoring 3 triggers medium/high escalation)
    final hasIndividual3 = breakdown.values.any((v) => v >= 3);

    if (totalScore >= 7) {
      riskLevel = 'High Risk';
      riskColor = '#E53935'; // Red
      actionRecommendation = 'URGENT: Immediate clinical assessment & PHC/Hospital escalation';
    } else if (totalScore >= 5 || hasIndividual3) {
      riskLevel = 'Medium Risk';
      riskColor = '#FB8C00'; // Amber/Orange
      actionRecommendation = 'ALERT: Urgent review by Medical Officer or Senior Nurse';
    } else if (totalScore >= 1) {
      riskLevel = 'Low-Medium Risk';
      riskColor = '#FDD835'; // Yellow
      actionRecommendation = 'Inform Medical Officer; repeat vitals assessment within 4-6 hours';
    }

    return {
      'score': totalScore,
      'risk_level': riskLevel,
      'risk_color': riskColor,
      'action': actionRecommendation,
      'breakdown': breakdown,
      'has_extreme_vital': hasIndividual3,
    };
  }

  /// Compute DELTA variation between current and previous medical records
  static Map<String, Map<String, dynamic>> computeDelta(
    Map<String, dynamic> current,
    Map<String, dynamic>? previous,
  ) {
    final result = <String, Map<String, dynamic>>{};

    void addVitalDelta(String name, String key, String unit, {bool isFloat = false}) {
      final currVal = isFloat
          ? (current[key] as num?)?.toDouble()
          : (current[key] as num?)?.toInt().toDouble();

      final prevVal = previous != null
          ? (isFloat
              ? (previous[key] as num?)?.toDouble()
              : (previous[key] as num?)?.toInt().toDouble())
          : null;

      if (currVal == null) return;

      if (prevVal == null) {
        result[name] = {
          'current': currVal,
          'previous': null,
          'diff': null,
          'percent_change': null,
          'unit': unit,
          'direction': 'neutral',
        };
        return;
      }

      final diff = currVal - prevVal;
      final pct = prevVal != 0 ? ((diff / prevVal) * 100) : 0.0;
      final direction = diff > 0 ? 'up' : (diff < 0 ? 'down' : 'neutral');

      result[name] = {
        'current': currVal,
        'previous': prevVal,
        'diff': diff,
        'percent_change': pct,
        'unit': unit,
        'direction': direction,
      };
    }

    addVitalDelta('Systolic BP', 'blood_pressure_systolic', 'mmHg');
    addVitalDelta('Diastolic BP', 'blood_pressure_diastolic', 'mmHg');
    addVitalDelta('Heart Rate', 'pulse_rate', 'bpm');
    addVitalDelta('SpO2', 'spo2', '%');
    addVitalDelta('Respiratory Rate', 'respiratory_rate', 'breaths/min');
    addVitalDelta('Temperature', 'temperature', '°F', isFloat: true);
    addVitalDelta('Fasting Sugar', 'blood_sugar_fasting', 'mg/dL', isFloat: true);
    addVitalDelta('Postprandial Sugar', 'blood_sugar_postprandial', 'mg/dL', isFloat: true);

    return result;
  }
}
