import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../data/india_data.dart';

class LocalDbService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'asha_records.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE,
            password TEXT,
            first_name TEXT,
            last_name TEXT,
            role TEXT,
            phone_number TEXT,
            aadhaar_number TEXT,
            state TEXT,
            district TEXT,
            profile_image TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE states(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE
          )
        ''');

        await db.execute('''
          CREATE TABLE districts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            state_id INTEGER,
            name TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE areas(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            district_id INTEGER,
            block TEXT,
            village_or_ward TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE user_areas(
            user_id INTEGER,
            area_id INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE families(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            family_head_name TEXT,
            house_number TEXT,
            contact_number TEXT,
            area_id INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE members(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            family_id INTEGER,
            full_name TEXT,
            age INTEGER,
            gender TEXT,
            relationship_to_head TEXT,
            abha_id TEXT,
            mobile_number TEXT,
            is_pregnant INTEGER DEFAULT 0,
            lmp_date TEXT,
            edd_date TEXT,
            is_high_risk_pregnancy INTEGER DEFAULT 0,
            is_lactating INTEGER DEFAULT 0,
            td1_vaccine INTEGER DEFAULT 0,
            td2_vaccine INTEGER DEFAULT 0,
            td_booster INTEGER DEFAULT 0,
            ifa_tablets_given INTEGER DEFAULT 0,
            calcium_tablets_given INTEGER DEFAULT 0,
            birth_weight REAL,
            delivery_type TEXT,
            muac_cm REAL,
            has_chronic_condition INTEGER DEFAULT 0,
            chronic_notes TEXT,
            profile_image TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE medical_records(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            member_id INTEGER,
            recorded_by INTEGER,
            blood_sugar_fasting REAL,
            blood_sugar_postprandial REAL,
            blood_pressure_systolic INTEGER,
            blood_pressure_diastolic INTEGER,
            temperature REAL,
            pulse_rate INTEGER,
            spo2 INTEGER,
            respiratory_rate INTEGER,
            notes TEXT,
            entry_source TEXT,
            device_id TEXT,
            recorded_at TEXT
          )
        ''');

        // Insert Default Master Admin
        await db.insert('users', {
          'username': 'admin',
          'password': 'admin',
          'role': 'superuser',
          'first_name': 'Admin',
          'last_name': 'System',
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE users ADD COLUMN profile_image TEXT');
          } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE members ADD COLUMN profile_image TEXT');
          } catch (_) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute('ALTER TABLE medical_records ADD COLUMN spo2 INTEGER');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE medical_records ADD COLUMN respiratory_rate INTEGER');
          } catch (_) {}
        }
        if (oldVersion < 5) {
          final newCols = [
            'ALTER TABLE members ADD COLUMN abha_id TEXT',
            'ALTER TABLE members ADD COLUMN mobile_number TEXT',
            'ALTER TABLE members ADD COLUMN is_pregnant INTEGER DEFAULT 0',
            'ALTER TABLE members ADD COLUMN lmp_date TEXT',
            'ALTER TABLE members ADD COLUMN edd_date TEXT',
            'ALTER TABLE members ADD COLUMN is_high_risk_pregnancy INTEGER DEFAULT 0',
            'ALTER TABLE members ADD COLUMN is_lactating INTEGER DEFAULT 0',
            'ALTER TABLE members ADD COLUMN td1_vaccine INTEGER DEFAULT 0',
            'ALTER TABLE members ADD COLUMN td2_vaccine INTEGER DEFAULT 0',
            'ALTER TABLE members ADD COLUMN td_booster INTEGER DEFAULT 0',
            'ALTER TABLE members ADD COLUMN ifa_tablets_given INTEGER DEFAULT 0',
            'ALTER TABLE members ADD COLUMN calcium_tablets_given INTEGER DEFAULT 0',
            'ALTER TABLE members ADD COLUMN birth_weight REAL',
            'ALTER TABLE members ADD COLUMN delivery_type TEXT',
            'ALTER TABLE members ADD COLUMN muac_cm REAL',
            'ALTER TABLE members ADD COLUMN has_chronic_condition INTEGER DEFAULT 0',
            'ALTER TABLE members ADD COLUMN chronic_notes TEXT',
          ];
          for (var q in newCols) {
            try {
              await db.execute(q);
            } catch (_) {}
          }
        }
        // Repair/sanitize any legacy oversized base64 images that caused CursorWindow errors
        try {
          await db.execute('UPDATE users SET profile_image = NULL WHERE length(profile_image) > 150000');
        } catch (_) {}
      },
    );
  }

  // Generate fake local token based on user ID
  static String _generateToken(int userId) {
    return 'local_token_$userId';
  }

  static int _getUserIdFromToken(String token) {
    if (token.startsWith('local_token_')) {
      return int.tryParse(token.split('_').last) ?? 0;
    }
    return 0;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Authentication
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> loginASHA(String name, String phoneNumber) async {
    final db = await database;
    // Match by: full name (first + last), first name only, OR username (login name)
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT * FROM users WHERE (first_name || ' ' || last_name = ? OR first_name = ? OR username = ?) AND phone_number = ? AND role = 'asha'",
      [name, name, name, phoneNumber],
    );
    if (maps.isNotEmpty) {
      final user = maps.first;
      return await _buildUserPayload(user);
    }
    throw Exception('Invalid Name or Phone Number');
  }

  static Future<Map<String, dynamic>> loginAdmin(String username, String password) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    if (maps.isNotEmpty) {
      final user = maps.first;
      return await _buildUserPayload(user);
    }
    throw Exception('Invalid Admin Username or Password');
  }

  static Future<Map<String, dynamic>> _buildUserPayload(Map<String, dynamic> user) async {
    final db = await database;
    // Fetch assigned areas with their details and district name
    final areaMaps = await db.rawQuery('''
      SELECT a.id, a.block, a.village_or_ward, d.name as district_name
      FROM areas a 
      JOIN user_areas ua ON a.id = ua.area_id 
      LEFT JOIN districts d ON a.district_id = d.id
      WHERE ua.user_id = ?
      ORDER BY a.village_or_ward ASC
    ''', [user['id']]);
    
    final assignedAreas = areaMaps.map((e) => {
      'id': e['id'],
      'block': e['block'],
      'village_or_ward': e['village_or_ward'],
      'district_name': e['district_name'],
    }).toList();

    final districtNames = areaMaps.map((e) => e['district_name']?.toString() ?? 'N/A').toSet().toList();
    final areaNames = areaMaps.map((e) => e['village_or_ward']?.toString() ?? 'Unnamed Area').toList();

    // Fetch state name
    String stateName = 'N/A';
    if (user['state'] != null && user['state'].toString().isNotEmpty) {
      final stateVal = user['state'].toString();
      final stateId = int.tryParse(stateVal);
      if (stateId != null) {
        final stateMaps = await db.query('states', where: 'id = ?', whereArgs: [stateId]);
        if (stateMaps.isNotEmpty) {
          stateName = stateMaps.first['name']?.toString() ?? stateVal;
        } else {
          stateName = stateVal;
        }
      } else {
        stateName = stateVal;
      }
    }

    return {
      'token': _generateToken(user['id'] as int),
      'user': {
        'id': user['id'],
        'username': user['username'],
        'first_name': user['first_name'],
        'last_name': user['last_name'],
        'phone_number': user['phone_number'],
        'aadhaar_number': user['aadhaar_number'],
        'profile_image': user['profile_image'],
        'role': user['role'],
        'state_name': stateName,
        'district_names': districtNames,
        'area_names': areaNames,
        'assigned_areas': assignedAreas,
      }
    };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ASHA Worker Logic
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getFamilies(String token) async {
    final db = await database;
    final userId = _getUserIdFromToken(token);
    
    // Check if the user is a superuser (admin). If so, return all families.
    final userMaps = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (userMaps.isNotEmpty && userMaps.first['role'] == 'superuser') {
      final List<Map<String, dynamic>> maps = await db.query('families', orderBy: 'family_head_name ASC');
      return maps.toList();
    }

    // Otherwise, filter by the worker's assigned areas.
    final areaMaps = await db.query('user_areas', columns: ['area_id'], where: 'user_id = ?', whereArgs: [userId]);
    final areaIds = areaMaps.map((e) => e['area_id'] as int).toList();
    
    if (areaIds.isEmpty) {
      return [];
    }

    final placeholders = List.filled(areaIds.length, '?').join(', ');
    final List<Map<String, dynamic>> maps = await db.query(
      'families',
      where: 'area_id IN ($placeholders)',
      whereArgs: areaIds,
      orderBy: 'family_head_name ASC',
    );
    return maps.toList();
  }

  static Future<bool> addFamily(String token, String headName, String houseNo, String contactNo, String areaId) async {
    final db = await database;
    await db.insert('families', {
      'family_head_name': headName,
      'house_number': houseNo,
      'contact_number': contactNo,
      'area_id': int.parse(areaId),
    });
    return true;
  }

  static Future<List<dynamic>> getMembers(String token) async {
    final db = await database;
    final List<Map<String, dynamic>> members = await db.query('members', orderBy: 'full_name ASC');
    
    // We need to append the latest flag and last_recorded_at
    List<Map<String, dynamic>> result = [];
    for (var m in members) {
      final mCopy = Map<String, dynamic>.from(m);
      mCopy['family'] = m['family_id'];
      
      final records = await db.query(
        'medical_records',
        where: 'member_id = ?',
        whereArgs: [m['id']],
        orderBy: 'recorded_at DESC',
        limit: 1,
      );

      if (records.isNotEmpty) {
        final r = records.first;
        mCopy['last_recorded_at'] = r['recorded_at'];
        mCopy['current_flag'] = _calculateFlag(r);
      } else {
        mCopy['last_recorded_at'] = null;
        mCopy['current_flag'] = null;
      }
      result.add(mCopy);
    }
    return result;
  }

  static Future<bool> addMember(
    String token,
    String familyId,
    String fullName,
    int age,
    String gender,
    String relationship, {
    String? profileImage,
    String? abhaId,
    String? mobileNumber,
    bool isPregnant = false,
    String? lmpDate,
    String? eddDate,
    bool isHighRiskPregnancy = false,
    bool isLactating = false,
    bool td1Vaccine = false,
    bool td2Vaccine = false,
    bool tdBooster = false,
    int ifaTabletsGiven = 0,
    int calciumTabletsGiven = 0,
    double? birthWeight,
    String? deliveryType,
    double? muacCm,
    bool hasChronicCondition = false,
    String? chronicNotes,
  }) async {
    final db = await database;
    await db.insert('members', {
      'family_id': int.parse(familyId),
      'full_name': fullName,
      'age': age,
      'gender': gender,
      'relationship_to_head': relationship,
      'profile_image': profileImage,
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
    });
    return true;
  }

  static Future<bool> updateMember({
    required String token,
    required String memberId,
    required String fullName,
    required int age,
    required String gender,
    required String relationship,
    String? profileImage,
    String? abhaId,
    String? mobileNumber,
    bool? isPregnant,
    String? lmpDate,
    String? eddDate,
    bool? isHighRiskPregnancy,
    bool? isLactating,
    bool? td1Vaccine,
    bool? td2Vaccine,
    bool? tdBooster,
    int? ifaTabletsGiven,
    int? calciumTabletsGiven,
    double? birthWeight,
    String? deliveryType,
    double? muacCm,
    bool? hasChronicCondition,
    String? chronicNotes,
  }) async {
    final db = await database;
    final Map<String, dynamic> values = {
      'full_name': fullName,
      'age': age,
      'gender': gender,
      'relationship_to_head': relationship,
    };
    if (profileImage != null) values['profile_image'] = profileImage;
    if (abhaId != null) values['abha_id'] = abhaId;
    if (mobileNumber != null) values['mobile_number'] = mobileNumber;
    if (isPregnant != null) values['is_pregnant'] = isPregnant ? 1 : 0;
    if (lmpDate != null) values['lmp_date'] = lmpDate;
    if (eddDate != null) values['edd_date'] = eddDate;
    if (isHighRiskPregnancy != null) values['is_high_risk_pregnancy'] = isHighRiskPregnancy ? 1 : 0;
    if (isLactating != null) values['is_lactating'] = isLactating ? 1 : 0;
    if (td1Vaccine != null) values['td1_vaccine'] = td1Vaccine ? 1 : 0;
    if (td2Vaccine != null) values['td2_vaccine'] = td2Vaccine ? 1 : 0;
    if (tdBooster != null) values['td_booster'] = tdBooster ? 1 : 0;
    if (ifaTabletsGiven != null) values['ifa_tablets_given'] = ifaTabletsGiven;
    if (calciumTabletsGiven != null) values['calcium_tablets_given'] = calciumTabletsGiven;
    if (birthWeight != null) values['birth_weight'] = birthWeight;
    if (deliveryType != null) values['delivery_type'] = deliveryType;
    if (muacCm != null) values['muac_cm'] = muacCm;
    if (hasChronicCondition != null) values['has_chronic_condition'] = hasChronicCondition ? 1 : 0;
    if (chronicNotes != null) values['chronic_notes'] = chronicNotes;

    await db.update('members', values, where: 'id = ?', whereArgs: [int.parse(memberId)]);
    return true;
  }

  static Future<List<dynamic>> getMemberHistory(String token, String memberId) async {
    final db = await database;
    final records = await db.query(
      'medical_records',
      where: 'member_id = ?',
      whereArgs: [int.parse(memberId)],
      orderBy: 'recorded_at DESC',
    );

    List<Map<String, dynamic>> result = [];
    for (var r in records) {
      final rCopy = Map<String, dynamic>.from(r);
      rCopy['flag'] = _calculateFlag(r);
      
      // Get recorded by name
      final users = await db.query('users', where: 'id = ?', whereArgs: [r['recorded_by']]);
      if (users.isNotEmpty) {
        final u = users.first;
        rCopy['recorded_by_name'] = '${u['first_name']} ${u['last_name']}';
        rCopy['recorded_by_role'] = u['role'];
      }
      
      result.add(rCopy);
    }
    return result;
  }

  static Future<Map<String, dynamic>> getMemberAnalytics(String token, String memberId) async {
    final db = await database;
    final records = await db.query(
      'medical_records',
      where: 'member_id = ?',
      whereArgs: [int.parse(memberId)],
      orderBy: 'recorded_at ASC',
    );

    List<Map<String, dynamic>> sys = [];
    List<Map<String, dynamic>> dia = [];
    List<Map<String, dynamic>> bsf = [];

    for (var r in records) {
      final date = r['recorded_at'] as String;
      if (r['blood_pressure_systolic'] != null) {
        sys.add({'date': date, 'value': r['blood_pressure_systolic']});
      }
      if (r['blood_pressure_diastolic'] != null) {
        dia.add({'date': date, 'value': r['blood_pressure_diastolic']});
      }
      if (r['blood_sugar_fasting'] != null) {
        bsf.add({'date': date, 'value': r['blood_sugar_fasting']});
      }
    }

    return {
      'blood_pressure_systolic': sys,
      'blood_pressure_diastolic': dia,
      'blood_sugar_fasting': bsf,
    };
  }

  static Future<bool> addMedicalRecord({
    required String token,
    required String memberId,
    double? bloodSugarFasting,
    double? bloodSugarPostprandial,
    int? bloodPressureSystolic,
    int? bloodPressureDiastolic,
    double? temperature,
    int? pulseRate,
    int? spo2,
    int? respiratoryRate,
    String? notes,
    String entrySource = 'manual',
    String? deviceId,
  }) async {
    final db = await database;
    final userId = _getUserIdFromToken(token);
    await db.insert('medical_records', {
      'member_id': int.parse(memberId),
      'recorded_by': userId,
      'blood_sugar_fasting': bloodSugarFasting,
      'blood_sugar_postprandial': bloodSugarPostprandial,
      'blood_pressure_systolic': bloodPressureSystolic,
      'blood_pressure_diastolic': bloodPressureDiastolic,
      'temperature': temperature,
      'pulse_rate': pulseRate,
      'spo2': spo2,
      'respiratory_rate': respiratoryRate,
      'notes': notes,
      'entry_source': entrySource,
      'device_id': deviceId,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
    });
    return true;
  }

  static String _calculateFlag(Map<String, dynamic> r) {
    bool isCritical = false;
    bool isWarning = false;

    final bps = r['blood_pressure_systolic'] as num?;
    final bpd = r['blood_pressure_diastolic'] as num?;
    if (bps != null || bpd != null) {
      if ((bps != null && bps > 160) || (bpd != null && bpd > 100)) {
        isCritical = true;
      } else if ((bps != null && bps > 140) || (bpd != null && bpd > 90)) {
        isWarning = true;
      }
    }

    final bsf = r['blood_sugar_fasting'] as num?;
    if (bsf != null) {
      if (bsf > 200) {
        isCritical = true;
      } else if (bsf > 126) {
        isWarning = true;
      }
    }

    final temp = r['temperature'] as num?;
    if (temp != null) {
      if (temp > 103) {
        isCritical = true;
      } else if (temp > 100.4) {
        isWarning = true;
      }
    }

    final pulse = r['pulse_rate'] as num?;
    if (pulse != null) {
      if (pulse > 130 || pulse < 40) {
        isCritical = true;
      } else if (pulse > 100 || pulse < 50) {
        isWarning = true;
      }
    }

    final spo2 = r['spo2'] as num?;
    if (spo2 != null) {
      if (spo2 < 92) {
        isCritical = true;
      } else if (spo2 < 95) {
        isWarning = true;
      }
    }

    final rr = r['respiratory_rate'] as num?;
    if (rr != null) {
      if (rr > 24 || rr < 8) {
        isCritical = true;
      } else if (rr > 20 || rr < 12) {
        isWarning = true;
      }
    }

    if (isCritical) return 'critical';
    if (isWarning) return 'warning';
    return 'normal';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Admin Dashboard Logic
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDashboardSummary(String token) async {
    final db = await database;
    final familyCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM families')) ?? 0;
    final memberCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM members')) ?? 0;
    
    int highRisk = 0;
    final members = await db.query('members');
    for (var m in members) {
      final records = await db.query(
        'medical_records',
        where: 'member_id = ?',
        whereArgs: [m['id']],
        orderBy: 'recorded_at DESC',
        limit: 1,
      );
      if (records.isNotEmpty) {
        final flag = _calculateFlag(records.first);
        if (flag == 'critical') highRisk++;
      }
    }

    return {
      'total_families': familyCount,
      'total_members': memberCount,
      'high_risk_members': highRisk,
      'active_workers': 0, // Placeholder
    };
  }

  static Future<List<dynamic>> getStates(String token) async {
    final db = await database;
    return await db.query('states', orderBy: 'name ASC');
  }

  static Future<List<dynamic>> getDistricts(String token) async {
    final db = await database;
    return await db.query('districts', orderBy: 'name ASC');
  }

  static Future<List<dynamic>> getAreas(String token) async {
    final db = await database;
    return await db.query('areas', orderBy: 'block ASC, village_or_ward ASC');
  }

  static Future<bool> addState(String token, String name) async {
    final db = await database;
    await db.insert('states', {'name': name});
    return true;
  }

  static Future<bool> addDistrict(String token, String stateId, String name) async {
    final db = await database;
    await db.insert('districts', {'state_id': int.parse(stateId), 'name': name});
    return true;
  }

  static Future<bool> addArea(String token, String districtId, String block, String villageOrWard) async {
    final db = await database;
    await db.insert('areas', {
      'district_id': int.parse(districtId),
      'block': block,
      'village_or_ward': villageOrWard,
    });
    return true;
  }

  static Future<bool> editState(String token, String stateId, String name) async {
    final db = await database;
    await db.update('states', {'name': name}, where: 'id = ?', whereArgs: [int.parse(stateId)]);
    return true;
  }

  static Future<bool> editDistrict(String token, String districtId, String stateId, String name) async {
    final db = await database;
    await db.update('districts', {'state_id': int.parse(stateId), 'name': name}, where: 'id = ?', whereArgs: [int.parse(districtId)]);
    return true;
  }

  static Future<bool> editArea(String token, String areaId, String districtId, String block, String villageOrWard) async {
    final db = await database;
    await db.update('areas', {
      'district_id': int.parse(districtId),
      'block': block,
      'village_or_ward': villageOrWard,
    }, where: 'id = ?', whereArgs: [int.parse(areaId)]);
    return true;
  }

  static Future<bool> deleteState(String token, String stateId) async {
    final db = await database;
    await db.delete('states', where: 'id = ?', whereArgs: [int.parse(stateId)]);
    return true;
  }

  static Future<bool> deleteDistrict(String token, String districtId) async {
    final db = await database;
    await db.delete('districts', where: 'id = ?', whereArgs: [int.parse(districtId)]);
    return true;
  }

  static Future<bool> deleteArea(String token, String areaId) async {
    final db = await database;
    await db.delete('areas', where: 'id = ?', whereArgs: [int.parse(areaId)]);
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Seeding Logic
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<Map<String, int>> seedIndiaData() async {
    final db = await database;
    int statesAdded = 0;
    int districtsAdded = 0;

    await db.transaction((txn) async {
      for (var stateName in IndiaData.statesAndDistricts.keys) {
        // Check if state exists
        final existingState = await txn.query('states', where: 'name = ?', whereArgs: [stateName]);
        int stateId;
        if (existingState.isEmpty) {
          stateId = await txn.insert('states', {'name': stateName});
          statesAdded++;
        } else {
          stateId = existingState.first['id'] as int;
        }

        final districts = IndiaData.statesAndDistricts[stateName]!;
        for (var districtName in districts) {
          // Check if district exists under this state
          final existingDistrict = await txn.query(
            'districts',
            where: 'state_id = ? AND name = ?',
            whereArgs: [stateId, districtName],
          );
          if (existingDistrict.isEmpty) {
            await txn.insert('districts', {'state_id': stateId, 'name': districtName});
            districtsAdded++;
          }
        }
      }
    });

    return {'states': statesAdded, 'districts': districtsAdded};
  }

  static Future<Map<String, int>> getSystemStats() async {
    final db = await database;
    final statesCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM states')) ?? 0;
    final districtsCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM districts')) ?? 0;
    final areasCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM areas')) ?? 0;
    final workersCount = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM users WHERE role = 'asha'")) ?? 0;
    final familiesCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM families')) ?? 0;
    final membersCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM members')) ?? 0;
    final recordsCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM medical_records')) ?? 0;

    return {
      'states': statesCount,
      'districts': districtsCount,
      'areas': areasCount,
      'workers': workersCount,
      'families': familiesCount,
      'members': membersCount,
      'records': recordsCount,
    };
  }

  static Future<void> clearAllJurisdictions() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('user_areas');
      await txn.delete('areas');
      await txn.delete('districts');
      await txn.delete('states');
    });
  }

  static Future<List<dynamic>> getASHAWorkers(String token) async {
    final db = await database;
    final workers = await db.query('users', where: 'role = ?', whereArgs: ['asha'], orderBy: 'first_name ASC, last_name ASC');
    
    List<Map<String, dynamic>> result = [];
    for (var w in workers) {
      final areaMaps = await db.rawQuery('''
        SELECT a.id, a.village_or_ward 
        FROM areas a 
        JOIN user_areas ua ON a.id = ua.area_id 
        WHERE ua.user_id = ?
      ''', [w['id']]);
      final areaNames = areaMaps.map((e) => e['village_or_ward']?.toString() ?? 'Unnamed Area').toList();
      final areaIds = areaMaps.map((e) => e['id'] as int).toList();

      String stateName = 'N/A';
      if (w['state'] != null && w['state'].toString().isNotEmpty) {
        final stateVal = w['state'].toString();
        final stateId = int.tryParse(stateVal);
        if (stateId != null) {
          final stateMaps = await db.query('states', where: 'id = ?', whereArgs: [stateId]);
          if (stateMaps.isNotEmpty) {
            stateName = stateMaps.first['name']?.toString() ?? stateVal;
          } else {
            stateName = stateVal;
          }
        } else {
          stateName = stateVal;
        }
      }

      final wCopy = Map<String, dynamic>.from(w);
      wCopy['state_name'] = stateName;
      wCopy['area_names'] = areaNames;
      wCopy['assigned_areas'] = areaIds;
      result.add(wCopy);
    }
    return result;
  }

  static Future<bool> addASHAWorker({
    required String token,
    required String username,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String aadhaarNumber,
    required String stateId,
    required List<String> areaIds,
    String? profileImage,
  }) async {
    final db = await database;
    final userId = await db.insert('users', {
      'username': username,
      'password': 'password123', // Hardcoded default password for created workers
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'aadhaar_number': aadhaarNumber,
      'state': stateId,
      'role': 'asha',
      'profile_image': profileImage,
    });

    for (var areaId in areaIds) {
      await db.insert('user_areas', {
        'user_id': userId,
        'area_id': int.parse(areaId),
      });
    }
    return true;
  }

  static Future<bool> editASHAWorker({
    required String token,
    required String userId,
    required String username,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String aadhaarNumber,
    required String stateId,
    required List<String> areaIds,
    String? profileImage,
  }) async {
    final db = await database;
    final uId = int.parse(userId);
    await db.update('users', {
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'aadhaar_number': aadhaarNumber,
      'state': stateId,
      'profile_image': profileImage,
    }, where: 'id = ?', whereArgs: [uId]);

    // Update areas
    await db.delete('user_areas', where: 'user_id = ?', whereArgs: [uId]);
    for (var areaId in areaIds) {
      await db.insert('user_areas', {
        'user_id': uId,
        'area_id': int.parse(areaId),
      });
    }
    return true;
  }

  static Future<bool> deleteASHAWorker(String token, String userId) async {
    final db = await database;
    final uId = int.parse(userId);
    await db.delete('users', where: 'id = ?', whereArgs: [uId]);
    await db.delete('user_areas', where: 'user_id = ?', whereArgs: [uId]);
    return true;
  }
}
