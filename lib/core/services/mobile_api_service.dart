// lib/core/services/mobile_api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_api_service.dart';
import 'session_menu_service.dart';

/// Centralized API service for all 8 Staff Mobile App screens.
/// Automatically applies headers:
///   - menu-id: dynamic from SessionMenuService or `menuId`
///   - module-id: dynamic from SessionMenuService or `moduleId`
///   - action-code: dynamic based on action (`VIEW`, `PRINT`, `CHIEF_COMPLAINTS`, etc.)
///   - Session cookies
class MobileApiService {
  static final MobileApiService _instance = MobileApiService._internal();
  factory MobileApiService() => _instance;
  MobileApiService._internal();

  static const String baseUrl = 'https://apihis.hmissupport.in/api/v1';

  /// Construct headers dynamically with menu-id, module-id, action-code, and cookies.
  Map<String, String> buildHeaders({
    int? menuId,
    int? moduleId,
    String? routePath,
    String? actionCode = 'VIEW',
    Map<String, String>? extra,
  }) {
    final headers = AuthApiService().buildHeaders();
    int? resolvedMenuId = menuId;
    int? resolvedModuleId = moduleId;

    if (routePath != null) {
      final dynamicMenu = SessionMenuService().getMenuForRoute(routePath);
      if (dynamicMenu != null) {
        resolvedMenuId = dynamicMenu.menuId;
        resolvedModuleId = dynamicMenu.moduleId;
      }
    }

    if (resolvedMenuId != null && resolvedMenuId > 0) {
      headers['menu-id'] = resolvedMenuId.toString();
    }
    if (resolvedModuleId != null && resolvedModuleId > 0) {
      headers['module-id'] = resolvedModuleId.toString();
    }
    if (actionCode != null && actionCode.trim().isNotEmpty) {
      headers['action-code'] = actionCode.trim().toUpperCase();
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  /// HTTP GET helper with logging & cookie extraction
  Future<http.Response> _get(
    Uri uri, {
    int? menuId,
    int? moduleId,
    String? routePath,
    String? actionCode = 'VIEW',
    Map<String, String>? extra,
  }) async {
    final headers = buildHeaders(
      menuId: menuId,
      moduleId: moduleId,
      routePath: routePath,
      actionCode: actionCode,
      extra: extra,
    );
    AuthApiService().logRequest('GET', uri, headers);
    final res = await http.get(uri, headers: headers);
    AuthApiService().extractCookies(res);
    AuthApiService().logResponse('GET', uri, res);
    return res;
  }

  /// HTTP POST helper with logging & cookie extraction
  Future<http.Response> _post(
    Uri uri, {
    int? menuId,
    int? moduleId,
    String? routePath,
    String? actionCode = 'VIEW',
    Object? body,
    Map<String, String>? extra,
  }) async {
    final headers = buildHeaders(
      menuId: menuId,
      moduleId: moduleId,
      routePath: routePath,
      actionCode: actionCode,
      extra: extra,
    );
    final bodyStr = body is String ? body : (body != null ? jsonEncode(body) : null);
    AuthApiService().logRequest('POST', uri, headers, bodyStr);
    final res = await http.post(uri, headers: headers, body: bodyStr);
    AuthApiService().extractCookies(res);
    AuthApiService().logResponse('POST', uri, res);
    return res;
  }

  /// HTTP PUT helper with logging & cookie extraction
  Future<http.Response> _put(
    Uri uri, {
    int? menuId,
    int? moduleId,
    String? routePath,
    String? actionCode = 'VIEW',
    Object? body,
    Map<String, String>? extra,
  }) async {
    final headers = buildHeaders(
      menuId: menuId,
      moduleId: moduleId,
      routePath: routePath,
      actionCode: actionCode,
      extra: extra,
    );
    final bodyStr = body is String ? body : (body != null ? jsonEncode(body) : null);
    AuthApiService().logRequest('PUT', uri, headers, bodyStr);
    final res = await http.put(uri, headers: headers, body: bodyStr);
    AuthApiService().extractCookies(res);
    AuthApiService().logResponse('PUT', uri, res);
    return res;
  }

  /// HTTP PATCH helper with logging & cookie extraction
  Future<http.Response> _patch(
    Uri uri, {
    int? menuId,
    int? moduleId,
    String? routePath,
    String? actionCode = 'VIEW',
    Object? body,
    Map<String, String>? extra,
  }) async {
    final headers = buildHeaders(
      menuId: menuId,
      moduleId: moduleId,
      routePath: routePath,
      actionCode: actionCode,
      extra: extra,
    );
    final bodyStr = body is String ? body : (body != null ? jsonEncode(body) : null);
    AuthApiService().logRequest('PATCH', uri, headers, bodyStr);
    final res = await http.patch(uri, headers: headers, body: bodyStr);
    AuthApiService().extractCookies(res);
    AuthApiService().logResponse('PATCH', uri, res);
    return res;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────────
  // 1. CAMPS API (/portal/camps, menu_id: 214, module_id: 24, action: VIEW)
  // Exact endpoint: https://apihis.hmissupport.in/api/v1/camps?page=1&limit=100&moduleId=24
  // ─────────────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchCamps({
    int menuId = 214,
    int moduleId = 24,
    String actionCode = 'VIEW',
    int page = 1,
    int limit = 100,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'moduleId': moduleId.toString(),
      };
      if (status != null && status.isNotEmpty && status != 'All') {
        queryParams['status_code'] = status;
      }

      final uri = Uri.parse('$baseUrl/camps').replace(queryParameters: queryParams);
      debugPrint('[MobileApiService] Fetching camps from: $uri');

      final res = await _get(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/camps',
        actionCode: actionCode,
      );

      debugPrint('[MobileApiService] fetchCamps status: ${res.statusCode}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        List? rawList;
        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map) {
          if (decoded['items'] is List) {
            rawList = decoded['items'];
          } else if (decoded['data'] is List) {
            rawList = decoded['data'];
          } else if (decoded['camps'] is List) {
            rawList = decoded['camps'];
          } else if (decoded['data'] is Map) {
            final inner = decoded['data'] as Map;
            if (inner['items'] is List) {
              rawList = inner['items'];
            } else if (inner['data'] is List) {
              rawList = inner['data'];
            } else if (inner['camps'] is List) {
              rawList = inner['camps'];
            }
          }
        }
        if (rawList != null && rawList.isNotEmpty) {
          return List<Map<String, dynamic>>.from(rawList.whereType<Map>());
        }
      }
      return [];
    } catch (e) {
      debugPrint('[MobileApiService] fetchCamps error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchCampDetails(
    int campCode, {
    int menuId = 214,
    int moduleId = 24,
    String actionCode = 'VIEW',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/camps/$campCode');
      final res = await _get(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/camps',
        actionCode: actionCode,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        return decoded is Map ? Map<String, dynamic>.from(decoded['data'] ?? decoded) : null;
      }
      return null;
    } catch (e) {
      debugPrint('fetchCampDetails error: $e');
      return null;
    }
  }

  Future<bool> startCamp(
    int campCode, {
    String? startTime,
    int menuId = 214,
    int moduleId = 24,
    String actionCode = 'START',
  }) async {
    try {
      final now = DateTime.now();
      final timeStr = startTime ??
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      final uri = Uri.parse('$baseUrl/camps/$campCode/start');
      final res = await _patch(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/camps',
        actionCode: actionCode,
        body: {'start_time': timeStr},
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('startCamp error: $e');
      return false;
    }
  }

  Future<bool> completeCamp(
    int campCode, {
    String? endTime,
    String? notes,
    int menuId = 214,
    int moduleId = 24,
    String actionCode = 'COMPLETE',
  }) async {
    try {
      final now = DateTime.now();
      final timeStr = endTime ??
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      final uri = Uri.parse('$baseUrl/camps/$campCode/complete');
      final body = <String, dynamic>{'end_time': timeStr};
      if (notes != null && notes.trim().isNotEmpty) {
        body['notes'] = notes.trim();
      }
      final res = await _patch(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/camps',
        actionCode: actionCode,
        body: body,
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('completeCamp error: $e');
      return false;
    }
  }

  Future<bool> cancelCamp(
    int campCode, {
    required String notes,
    int menuId = 214,
    int moduleId = 24,
    String actionCode = 'CANCEL',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/camps/$campCode/cancel');
      final res = await _patch(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/camps',
        actionCode: actionCode,
        body: {'notes': notes.trim()},
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('cancelCamp error: $e');
      return false;
    }
  }

  Future<bool> updatePatientLimit(
    int campCode,
    int limit, {
    int menuId = 214,
    int moduleId = 24,
    String actionCode = 'LIMIT',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/camps/$campCode/patient-limit');
      final res = await _patch(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/camps',
        actionCode: actionCode,
        body: {'patient_limit_count': limit},
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('updatePatientLimit error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> createCamp(
    Map<String, dynamic> payload, {
    int menuId = 214,
    int moduleId = 24,
    String actionCode = 'ADD',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/camps');
      final res = await _post(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/camps',
        actionCode: actionCode,
        body: payload,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        return decoded is Map ? Map<String, dynamic>.from(decoded['data'] ?? decoded) : null;
      }
      return null;
    } catch (e) {
      debugPrint('createCamp error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchFacilityQr({
    int menuId = 214,
    int moduleId = 24,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/abha/scan-share/facility-qr');
      final res = await _get(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/camps',
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          if (decoded['data'] is Map) {
            final m = Map<String, dynamic>.from(decoded['data'] as Map);
            if (decoded['message'] != null) m['message'] = decoded['message'];
            return m;
          }
          return Map<String, dynamic>.from(decoded);
        }
        return {'qrCode': res.body};
      }
      return null;
    } catch (e) {
      debugPrint('fetchFacilityQr error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchDistricts() async {
    try {
      final uri = Uri.parse('$baseUrl/masters/districts');
      final res = await _get(uri);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded is Map ? (decoded['data'] ?? decoded['districts'] ?? []) : []);
        if (list is List) {
          return List<Map<String, dynamic>>.from(list.whereType<Map>());
        }
      }
      return [];
    } catch (e) {
      debugPrint('fetchDistricts error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMandals(dynamic distCode) async {
    try {
      final uri = Uri.parse('$baseUrl/masters/mandals?distCode=$distCode');
      final res = await _get(uri);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded is Map ? (decoded['data'] ?? []) : []);
        if (list is List) {
          return List<Map<String, dynamic>>.from(list.whereType<Map>());
        }
      }
      return [];
    } catch (e) {
      debugPrint('fetchMandals error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. REGISTER PATIENT TO CAMP (/portal/register-camp, menu_id: 169, module_id: 27)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchCampsDropdown({
    int menuId = 169,
    int moduleId = 27,
    String actionCode = 'VIEW',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/camps/dropdown');
      final res = await _get(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/register-camp',
        actionCode: actionCode,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded is Map ? (decoded['data'] ?? decoded['items'] ?? []) : []);
        if (list is List) {
          return List<Map<String, dynamic>>.from(list.whereType<Map>());
        }
      }
      return [];
    } catch (e) {
      debugPrint('fetchCampsDropdown error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. PATIENT SEARCH API (by name, mobile, abha, email, mrn, or auto)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> searchPatients(
    String query, {
    String? searchType, // 'auto', 'name', 'mobile', 'abha', 'email', 'mrn'
    int menuId = 169,
    int moduleId = 27,
    String actionCode = 'VIEW',
  }) async {
    try {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return [];

      String queryString;
      final type = searchType?.toLowerCase();
      if (type == 'name') {
        queryString = 'name=${Uri.encodeComponent(trimmed)}';
      } else if (type == 'mobile') {
        queryString = 'mobile=${Uri.encodeComponent(trimmed)}';
      } else if (type == 'abha') {
        queryString = 'abha=${Uri.encodeComponent(trimmed)}';
      } else if (type == 'email') {
        queryString = 'email=${Uri.encodeComponent(trimmed)}';
      } else if (type == 'mrn') {
        queryString = 'mrn=${Uri.encodeComponent(trimmed)}';
      } else {
        // Auto-detect matching Portal register-camp-page.tsx resolveQueryParams
        if (trimmed.contains('@')) {
          queryString = 'email=${Uri.encodeComponent(trimmed)}';
        } else if (RegExp(r'^\d{2}-\d{4}-\d{4}-\d{4}$').hasMatch(trimmed) ||
            (trimmed.length == 14 && RegExp(r'^\d+$').hasMatch(trimmed))) {
          queryString = 'abha=${Uri.encodeComponent(trimmed)}';
        } else if (RegExp(r'^\d+$').hasMatch(trimmed)) {
          if (trimmed.length == 10) {
            queryString = 'mobile=$trimmed';
          } else if (trimmed.length == 12) {
            queryString = 'aadhaar=$trimmed';
          } else {
            queryString = 'mrn=$trimmed';
          }
        } else {
          queryString = 'name=${Uri.encodeComponent(trimmed)}';
        }
      }

      final uri = Uri.parse('$baseUrl/patients/search?$queryString');
      debugPrint('[MobileApiService] searchPatients: $uri');

      final res = await _get(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/register-camp',
        actionCode: actionCode,
      );

      debugPrint('[MobileApiService] searchPatients status: ${res.statusCode}');
      debugPrint('[MobileApiService] searchPatients body: ${res.body}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        List? patientsList;
        if (decoded is Map) {
          final data = decoded['data'];
          if (data is Map && data['patients'] is List) {
            patientsList = data['patients'];
          } else if (data is List) {
            patientsList = data;
          } else if (decoded['patients'] is List) {
            patientsList = decoded['patients'];
          } else if (data is Map && data.containsKey('name')) {
            return [Map<String, dynamic>.from(data)];
          }
        } else if (decoded is List) {
          patientsList = decoded;
        }

        if (patientsList != null && patientsList.isNotEmpty) {
          return List<Map<String, dynamic>>.from(patientsList.whereType<Map>());
        }
      }
      return [];
    } catch (e) {
      debugPrint('[MobileApiService] searchPatients error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> searchPatient(
    String query, {
    String? searchType,
    int menuId = 169,
    int moduleId = 27,
    String actionCode = 'VIEW',
  }) async {
    final list = await searchPatients(
      query,
      searchType: searchType,
      menuId: menuId,
      moduleId: moduleId,
      actionCode: actionCode,
    );
    return list.isNotEmpty ? list.first : null;
  }

  Future<Map<String, dynamic>> registerPatientToCamp({
    required int mrn,
    String? campCode,
    int menuId = 169,
    int moduleId = 27,
    String actionCode = 'VIEW',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/camps/register');
      final payload = {
        'mrn': mrn,
        'camp_code': campCode,
        'consent_given': true,
      };

      final res = await _post(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/register-camp',
        actionCode: actionCode,
        body: payload,
      );

      final decoded = jsonDecode(res.body);
      final isSuccess = res.statusCode == 200 || res.statusCode == 201;

      String message;
      if (decoded is Map) {
        if (decoded['message'] is List) {
          message = (decoded['message'] as List).join(', ');
        } else if (decoded['message'] != null) {
          message = decoded['message'].toString();
        } else if (decoded['error'] != null) {
          message = decoded['error'].toString();
        } else {
          message = isSuccess ? 'Patient enrolled successfully' : 'Registration failed';
        }
      } else {
        message = isSuccess ? 'Patient enrolled successfully' : 'Registration failed';
      }

      return {
        'success': isSuccess,
        'statusCode': res.statusCode,
        'message': message,
        'data': decoded is Map ? decoded['data'] : null,
      };
    } catch (e) {
      debugPrint('registerPatientToCamp error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. LIVE CAMP DASHBOARD (/portal/live-camp, menu_id: 255, module_id: 43)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchLiveCampDashboard({
    int menuId = 255,
    int moduleId = 43,
    String actionCode = 'VIEW',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/reports/dashboard/screening-team');
      final res = await _get(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/live-camp',
        actionCode: actionCode,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        final data = decoded is Map ? (decoded['data'] ?? decoded) : null;
        if (data is Map) {
          final campRaw = data['live-camp'] ?? data['liveCamp'];
          final queueRaw = data['live-queue'] ?? data['liveQueue'];
          return {
            'success': true,
            'camp': campRaw is List && campRaw.isNotEmpty ? campRaw[0] : campRaw,
            'queue': queueRaw is List ? queueRaw : [],
          };
        }
      }
      return {'success': false, 'camp': null, 'queue': []};
    } catch (e) {
      debugPrint('fetchLiveCampDashboard error: $e');
      return {'success': false, 'camp': null, 'queue': []};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. PATIENT HISTORY (/portal/patient-history, menu_id: 231, module_id: 36)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchPatientEmrHistory(
    int mrn, {
    int menuId = 231,
    int moduleId = 36,
    String actionCode = 'VIEW',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/emr/patient/$mrn');
      final res = await _get(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/patient-history',
        actionCode: actionCode,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        final data = decoded is Map ? (decoded['data'] ?? decoded) : decoded;
        if (data is List) {
          return List<Map<String, dynamic>>.from(data.whereType<Map>());
        }
      }
      return [];
    } catch (e) {
      debugPrint('fetchPatientEmrHistory error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchPrescriptionPrint(
    int emrId, {
    int menuId = 231,
    int moduleId = 36,
    String actionCode = 'PRINT',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/emr/$emrId/prescription-print');
      final res = await _get(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/patient-history',
        actionCode: actionCode,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        return decoded is Map ? Map<String, dynamic>.from(decoded['data'] ?? decoded) : null;
      }
      return null;
    } catch (e) {
      debugPrint('fetchPrescriptionPrint error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. REGISTER PATIENT (/portal/register-patient, menu_id: 180, module_id: 29)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> registerPatient(
    Map<String, dynamic> payload, {
    int menuId = 180,
    int moduleId = 29,
    String actionCode = 'VIEW',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/patients/register');
      final res = await _post(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/register-patient',
        actionCode: actionCode,
        body: payload,
      );

      final decoded = jsonDecode(res.body);
      final isSuccess = res.statusCode == 200 || res.statusCode == 201;
      return {
        'success': isSuccess,
        'message': decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : (isSuccess ? 'Patient registered successfully' : 'Registration failed'),
        'data': decoded is Map ? decoded['data'] : null,
      };
    } catch (e) {
      debugPrint('registerPatient error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> fetchPincodeDetails(String pincode) async {
    try {
      final uri = Uri.parse('$baseUrl/patients/pincode/${pincode.trim()}');
      final res = await _get(uri);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        return decoded is Map ? Map<String, dynamic>.from(decoded['data'] ?? decoded) : null;
      }
      return null;
    } catch (e) {
      debugPrint('fetchPincodeDetails error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. TODAY'S PATIENTS & EMR CLINICAL (/portal/patients, menu_id: 184, module_id: 29)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchTodayRegisteredPatients({
    int page = 1,
    int limit = 20,
    int menuId = 184,
    int moduleId = 29,
    String actionCode = 'VIEW',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/camps/registered-patients?page=$page&limit=$limit');
      final res = await _get(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/patients',
        actionCode: actionCode,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        final data = decoded is Map ? (decoded['data'] ?? decoded) : null;
        if (data is Map) {
          final patientsRaw = data['patients'] ?? data['items'] ?? [];
          return {
            'success': true,
            'patients': patientsRaw is List ? patientsRaw : [],
            'counts': data['counts'] ?? {},
            'total': data['total'] ?? 0,
            'campName': data['campName'] ?? data['camp_name'],
          };
        }
      }
      return {'success': false, 'patients': []};
    } catch (e) {
      debugPrint('fetchTodayRegisteredPatients error: $e');
      return {'success': false, 'patients': []};
    }
  }

  Future<Map<String, dynamic>?> createOrGetEmr(
    int visitId, {
    int menuId = 184,
    int moduleId = 29,
    String actionCode = 'VIEW',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/emr');
      final res = await _post(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/patients',
        actionCode: actionCode,
        body: {'visitId': visitId},
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        return decoded is Map ? Map<String, dynamic>.from(decoded['data'] ?? decoded) : null;
      }
      return null;
    } catch (e) {
      debugPrint('createOrGetEmr error: $e');
      return null;
    }
  }

  Future<bool> saveChiefComplaints(
    int emrId,
    List<dynamic> complaints, {
    int menuId = 184,
    int moduleId = 29,
    String actionCode = 'CHIEF_COMPLAINTS',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/emr/$emrId/complaints');
      final res = await _put(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/patients',
        actionCode: actionCode,
        body: {'complaints': complaints},
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('saveChiefComplaints error: $e');
      return false;
    }
  }

  Future<bool> saveDiagnoses(
    int emrId,
    List<dynamic> diagnoses, {
    int menuId = 184,
    int moduleId = 29,
    String actionCode = 'DIAGNOSIS',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/emr/$emrId/diagnoses');
      final res = await _put(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/patients',
        actionCode: actionCode,
        body: {'diagnoses': diagnoses},
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('saveDiagnoses error: $e');
      return false;
    }
  }

  Future<bool> prescribeMedication(
    int emrId,
    Map<String, dynamic> medication, {
    int menuId = 184,
    int moduleId = 29,
    String actionCode = 'RX',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/emr/$emrId/medications');
      final res = await _post(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/patients',
        actionCode: actionCode,
        body: medication,
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('prescribeMedication error: $e');
      return false;
    }
  }

  Future<bool> saveDoctorNotes(
    int emrId,
    String notes, {
    int menuId = 184,
    int moduleId = 29,
    String actionCode = 'DOCTOR_NOTES',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/emr/$emrId/doctor-notes');
      final res = await _put(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/patients',
        actionCode: actionCode,
        body: {'notes': notes},
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('saveDoctorNotes error: $e');
      return false;
    }
  }

  Future<bool> revertEmr(
    int emrId,
    String reason, {
    int menuId = 184,
    int moduleId = 29,
    String actionCode = 'REVERT_EMR',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/emr/$emrId/revert');
      final res = await _post(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/patients',
        actionCode: actionCode,
        body: {'revertReason': reason},
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('revertEmr error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 7. TEAMS API (/portal/teams, menu_id: 210, module_id: 33, action: VIEW)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchScreeningTeams({
    int menuId = 210,
    int moduleId = 33,
    String actionCode = 'VIEW',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/camps/screening-team');
      final res = await _get(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/teams',
        actionCode: actionCode,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded is Map ? (decoded['data'] ?? decoded['items'] ?? []) : []);
        if (list is List) {
          return List<Map<String, dynamic>>.from(list.whereType<Map>());
        }
      }
      return [];
    } catch (e) {
      debugPrint('fetchScreeningTeams error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 8. TELECONSULTATION API (/portal/teleconsult, menu_id: 269, module_id: 45)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchTeleconsultSessions({
    int menuId = 269,
    int moduleId = 45,
    String actionCode = 'VIEW',
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty && status != 'All') {
        queryParams['status'] = status.toUpperCase();
      }
      final uri = Uri.parse('$baseUrl/teleconsult/sessions').replace(queryParameters: queryParams);

      final res = await _get(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/teleconsult',
        actionCode: actionCode,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded is Map ? (decoded['data'] ?? decoded['sessions'] ?? []) : []);
        if (list is List) {
          return List<Map<String, dynamic>>.from(list.whereType<Map>());
        }
      }
      return [];
    } catch (e) {
      debugPrint('fetchTeleconsultSessions error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> joinTeleconsultSession(
    String sessionId, {
    int menuId = 269,
    int moduleId = 45,
    String actionCode = 'START',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/teleconsult/sessions/$sessionId/join');
      final res = await _get(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/teleconsult',
        actionCode: actionCode,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        return decoded is Map ? Map<String, dynamic>.from(decoded['data'] ?? decoded) : null;
      }
      return null;
    } catch (e) {
      debugPrint('joinTeleconsultSession error: $e');
      return null;
    }
  }

  Future<bool> completeTeleconsultSession(
    String sessionId, {
    String notes = '',
    int menuId = 269,
    int moduleId = 45,
    String actionCode = 'COMPLETE',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/teleconsult/sessions/$sessionId/complete');
      final res = await _post(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/teleconsult',
        actionCode: actionCode,
        body: {'notes': notes},
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('completeTeleconsultSession error: $e');
      return false;
    }
  }

  Future<bool> cancelTeleconsultSession(
    String sessionId, {
    String reason = '',
    int menuId = 269,
    int moduleId = 45,
    String actionCode = 'CANCEL',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/teleconsult/sessions/$sessionId/cancel');
      final res = await _post(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/teleconsult',
        actionCode: actionCode,
        body: {'reason': reason},
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('cancelTeleconsultSession error: $e');
      return false;
    }
  }

  Future<bool> scheduleTeleconsultSession(
    Map<String, dynamic> payload, {
    int menuId = 269,
    int moduleId = 45,
    String actionCode = 'ADD',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/teleconsult/sessions');
      final res = await _post(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/teleconsult',
        actionCode: actionCode,
        body: payload,
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('scheduleTeleconsultSession error: $e');
      return false;
    }
  }

  Future<bool> toggleTeamStatus(
    int teamCode,
    int isActive,
    String remarks, {
    int menuId = 210,
    int moduleId = 33,
    String actionCode = 'TOGGLE',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/camps/screening-team/$teamCode/status');
      final res = await _patch(
        uri,
        menuId: menuId,
        moduleId: moduleId,
        routePath: '/portal/teams',
        actionCode: actionCode,
        body: {'is_active': isActive, 'remarks': remarks},
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('toggleTeamStatus error: $e');
      return false;
    }
  }
}
