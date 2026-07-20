import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiService {
  // Dynamically selects 10.0.2.2 for Android Emulator, 127.0.0.1 for Windows/Web
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000/api';
  }

    // Edit ASHA Worker (Admin)
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
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'aadhaar_number': aadhaarNumber,
        'state': stateId,
        'assigned_areas': areaIds,
        'role': 'asha', // preserve role
      }),
    ).timeout(const Duration(seconds: 10));
    
    return response.statusCode == 200;
  }

  // Delete ASHA Worker (Admin)
  static Future<bool> deleteASHAWorker(String token, String userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$userId/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));
    return response.statusCode == 204;
  }


  // 1. ASHA Worker Login (Name + Phone Number)
  static Future<Map<String, dynamic>> loginASHA(String name, String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phone_number': phoneNumber,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['non_field_errors']?[0] ?? err['error'] ?? 'Invalid Name or Phone Number');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // 1b. Admin Login (Username + Password)
  static Future<Map<String, dynamic>> loginAdmin(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin-login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['error'] ?? 'Invalid Admin Username or Password');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // 2. Fetch Families for ASHA Worker
  static Future<List<dynamic>> getFamilies(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/families/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load families');
    }
  }

  // 3. Add New Family
  static Future<bool> addFamily(String token, String headName, String houseNo, String contactNo, String areaId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/families/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'family_head_name': headName,
        'house_number': houseNo,
        'contact_number': contactNo,
        'area': areaId,
      }),
    ).timeout(const Duration(seconds: 10));

    return response.statusCode == 201;
  }

  // Fetch Members
  static Future<List<dynamic>> getMembers(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/members/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load members');
    }
  }

  // Add Member
  static Future<bool> addMember(String token, String familyId, String fullName, int age, String gender, String relationship) async {
    final response = await http.post(
      Uri.parse('$baseUrl/members/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'family': familyId,
        'full_name': fullName,
        'age': age,
        'gender': gender,
        'relationship_to_head': relationship,
      }),
    ).timeout(const Duration(seconds: 10));

    return response.statusCode == 201;
  }

  // 4. Fetch All Areas for Admin
  static Future<List<dynamic>> getAreas(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/areas/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (_) {
      return [];
    }
  }

  // 5. Fetch All States for Admin
  static Future<List<dynamic>> getStates(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/states/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (_) {
      return [];
    }
  }

  // 5.5 Fetch All Districts for Admin
  static Future<List<dynamic>> getDistricts(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/districts/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (_) {
      return [];
    }
  }

  // 6. Fetch All ASHA Workers for Admin
  static Future<List<dynamic>> getASHAWorkers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (_) {
      return [];
    }
  }

  // 7. Add State (Admin)
  static Future<bool> addState(String token, String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/states/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': name}),
    ).timeout(const Duration(seconds: 10));
    return response.statusCode == 201;
  }

  // 7.5 Add District (Admin)
  static Future<bool> addDistrict(String token, String stateId, String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/districts/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'state': stateId,
        'name': name,
      }),
    ).timeout(const Duration(seconds: 10));
    return response.statusCode == 201;
  }

  // 8. Add Area (Admin)
  static Future<bool> addArea(String token, String districtId, String block, String villageOrWard) async {
    final response = await http.post(
      Uri.parse('$baseUrl/areas/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'district': districtId,
        'block': block,
        'village_or_ward': villageOrWard,
      }),
    ).timeout(const Duration(seconds: 10));
    return response.statusCode == 201;
  }

    // Edit State (Admin)
  static Future<bool> editState(String token, String stateId, String name) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/states/$stateId/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': name}),
    ).timeout(const Duration(seconds: 10));
    return response.statusCode == 200;
  }

  // Edit District (Admin)
  static Future<bool> editDistrict(String token, String districtId, String stateId, String name) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/districts/$districtId/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'state': stateId,
        'name': name
      }),
    ).timeout(const Duration(seconds: 10));
    return response.statusCode == 200;
  }

  // Edit Area (Admin)
  static Future<bool> editArea(
      String token, String areaId, String districtId, String block, String villageOrWard) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/areas/$areaId/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'district': districtId,
        'block': block,
        'village_or_ward': villageOrWard,
      }),
    ).timeout(const Duration(seconds: 10));
    return response.statusCode == 200;
  }

  // Delete State (Admin)
  static Future<bool> deleteState(String token, String stateId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/states/$stateId/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));
    return response.statusCode == 204;
  }

  // Delete District (Admin)
  static Future<bool> deleteDistrict(String token, String districtId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/districts/$districtId/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));
    return response.statusCode == 204;
  }

  // Delete Area (Admin)
  static Future<bool> deleteArea(String token, String areaId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/areas/$areaId/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));
    return response.statusCode == 204;
  }



  // 9. Add ASHA Worker (Admin)
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
    final response = await http.post(
      Uri.parse('$baseUrl/users/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'aadhaar_number': aadhaarNumber,
        'state': stateId,
        'assigned_areas': areaIds,
        'role': 'asha',
      }),
    ).timeout(const Duration(seconds: 10));
    return response.statusCode == 201;
  }
}