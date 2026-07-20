import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'healthvault.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE,
            password TEXT,
            first_name TEXT,
            last_name TEXT,
            phone_number TEXT,
            aadhaar_number TEXT,
            role TEXT,
            state TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE states(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT
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
            relationship_to_head TEXT
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
    // Match against full name (first_name + ' ' + last_name) OR just first_name
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      "SELECT * FROM users WHERE (first_name || ' ' || last_name = ? OR first_name = ?) AND phone_number = ? AND role = 'asha'",
      [name, name, phoneNumber],
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
    // Fetch assigned areas
    final areaMaps = await db.rawQuery('''
      SELECT a.village_or_ward 
      FROM areas a 
      JOIN user_areas ua ON a.id = ua.area_id 
      WHERE ua.user_id = ?
    ''', [user['id']]);
    final areaNames = areaMaps.map((e) => e['village_or_ward'] as String).toList();

    // Fetch state name
    String stateName = 'N/A';
    if (user['state'] != null && user['state'].toString().isNotEmpty) {
      final stateMaps = await db.query('states', where: 'id = ?', whereArgs: [user['state']]);
      if (stateMaps.isNotEmpty) {
        stateName = stateMaps.first['name'] as String;
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
        'role': user['role'],
        'state_name': stateName,
        'area_names': areaNames,
      }
    };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ASHA Worker Logic
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getFamilies(String token) async {
    final db = await database;
    // For now, return all families. In a real scenario, filter by the worker's assigned areas.
    final List<Map<String, dynamic>> maps = await db.query('families');
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
    final List<Map<String, dynamic>> members = await db.query('members');
    
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

  static Future<bool> addMember(String token, String familyId, String fullName, int age, String gender, String relationship) async {
    final db = await database;
    await db.insert('members', {
      'family_id': int.parse(familyId),
      'full_name': fullName,
      'age': age,
      'gender': gender,
      'relationship_to_head': relationship,
    });
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
    return await db.query('states');
  }

  static Future<List<dynamic>> getDistricts(String token) async {
    final db = await database;
    return await db.query('districts');
  }

  static Future<List<dynamic>> getAreas(String token) async {
    final db = await database;
    return await db.query('areas');
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

  static Future<List<dynamic>> getASHAWorkers(String token) async {
    final db = await database;
    final workers = await db.query('users', where: 'role = ?', whereArgs: ['asha']);
    
    List<Map<String, dynamic>> result = [];
    for (var w in workers) {
      final areaMaps = await db.rawQuery('''
        SELECT a.id, a.village_or_ward 
        FROM areas a 
        JOIN user_areas ua ON a.id = ua.area_id 
        WHERE ua.user_id = ?
      ''', [w['id']]);
      final areaNames = areaMaps.map((e) => e['village_or_ward'] as String).toList();
      final areaIds = areaMaps.map((e) => e['id'] as int).toList();

      String stateName = 'N/A';
      if (w['state'] != null && w['state'].toString().isNotEmpty) {
        final stateMaps = await db.query('states', where: 'id = ?', whereArgs: [w['state']]);
        if (stateMaps.isNotEmpty) {
          stateName = stateMaps.first['name'] as String;
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
