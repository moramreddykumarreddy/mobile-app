// lib/core/services/auth_api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/mobile_menu.dart';

class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final int statusCode;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    required this.statusCode,
  });

  @override
  String toString() =>
      'ApiResponse(success: $success, statusCode: $statusCode, message: $message, data: $data)';
}

class AuthApiService {
  static final AuthApiService _instance = AuthApiService._internal();
  factory AuthApiService() => _instance;
  AuthApiService._internal();

  static const String baseUrl = 'https://apihis.hmissupport.in/api/v1';

  // In-memory cookie jar to persist session cookies across authentication steps
  final Map<String, String> _cookies = {};

  void clearCookies() {
    _cookies.clear();
  }

  Map<String, String> buildHeaders([Map<String, String>? extra]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_cookies.isNotEmpty) {
      headers['Cookie'] =
          _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  Map<String, String> _buildHeaders() => buildHeaders();

  void extractCookies(http.Response response) => _extractCookies(response);

  void _extractCookies(http.Response response) {
    final rawSetCookie = response.headers['set-cookie'];
    if (rawSetCookie == null || rawSetCookie.trim().isEmpty) return;

    // Cookie strings in set-cookie might be separated by commas, but expires date also contains comma.
    // We split by standard Set-Cookie patterns or comma followed by space and cookie-name.
    final cookieParts = rawSetCookie.split(RegExp(r',\s*(?=[a-zA-Z0-9_\-]+=)'));
    for (final cookieStr in cookieParts) {
      final keyVal = cookieStr.split(';').first.trim();
      final equalIdx = keyVal.indexOf('=');
      if (equalIdx > 0) {
        final key = keyVal.substring(0, equalIdx).trim();
        final val = keyVal.substring(equalIdx + 1).trim();
        _cookies[key] = val;
      }
    }
    debugPrint('AuthApiService Cookies: ${_cookies.keys.toList()}');
  }

  void logRequest(String method, Uri uri, Map<String, String> headers, [dynamic body]) {
    debugPrint('\n🚀 ════════════════════ [HTTP REQUEST] ════════════════════');
    debugPrint('➡️ METHOD & URL : $method $uri');
    debugPrint('➡️ HEADERS:');
    headers.forEach((k, v) => debugPrint('   • $k: $v'));
    if (body != null) {
      debugPrint('➡️ BODY: $body');
    }
    debugPrint('═══════════════════════════════════════════════════════════');
  }

  void logResponse(String method, Uri uri, http.Response res) {
    debugPrint('\n📥 ════════════════════ [HTTP RESPONSE] ════════════════════');
    debugPrint('⬅️ FOR         : $method $uri');
    debugPrint('⬅️ STATUS CODE : ${res.statusCode}');
    debugPrint('⬅️ HEADERS:');
    res.headers.forEach((k, v) => debugPrint('   • $k: $v'));
    debugPrint('⬅️ BODY:');
    try {
      final decoded = jsonDecode(res.body);
      const encoder = JsonEncoder.withIndent('  ');
      final pretty = encoder.convert(decoded);
      if (pretty.length > 3000) {
        debugPrint('${pretty.substring(0, 3000)}\n... [truncated]');
      } else {
        debugPrint(pretty);
      }
    } catch (_) {
      debugPrint(res.body.length > 1500 ? '${res.body.substring(0, 1500)}... [truncated]' : res.body);
    }
    debugPrint('═══════════════════════════════════════════════════════════\n');
  }

  String _extractErrorMessage(dynamic decoded, int statusCode) {
    if (decoded is Map) {
      if (decoded['message'] != null) {
        final msg = decoded['message'];
        if (msg is List) {
          final joined = msg.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join('. ');
          if (joined.isNotEmpty) return joined;
        } else if (msg is String && msg.trim().isNotEmpty) {
          return msg.trim();
        }
      }

      if (decoded['data'] is Map && decoded['data']['message'] != null) {
        final dMsg = decoded['data']['message'];
        if (dMsg is List) {
          final joined = dMsg.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join('. ');
          if (joined.isNotEmpty) return joined;
        } else if (dMsg is String && dMsg.trim().isNotEmpty) {
          return dMsg.trim();
        }
      }

      if (decoded['error'] != null) {
        final err = decoded['error'];
        if (err is List) {
          final joined = err.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join('. ');
          if (joined.isNotEmpty) return joined;
        } else if (err is String && err.trim().isNotEmpty) {
          return err.trim();
        }
      }

      if (decoded['errors'] != null) {
        final errs = decoded['errors'];
        if (errs is List) {
          final joined = errs.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join('. ');
          if (joined.isNotEmpty) return joined;
        } else if (errs is Map) {
          final joined = errs.values.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join('. ');
          if (joined.isNotEmpty) return joined;
        }
      }
    }

    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Invalid credentials or OTP. Please try again.';
      case 403:
        return 'Too many attempts. Please try again after some time.';
      case 404:
        return 'Resource not found. Please verify details.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return 'An unexpected error occurred ($statusCode).';
    }
  }

  /// Step 1: Sign in with username and password
  /// POST https://apihis.hmissupport.in/api/v1/auth/login
  /// Payload: {"username":"nodaloffice@gmail.com","password":"Test@123"}
  Future<ApiResponse> login({
    required String username,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/login');
      final payload = {
        'username': username.trim(),
        'password': password,
      };

      final headers = _buildHeaders();
      final bodyStr = jsonEncode(payload);
      logRequest('POST', uri, headers, bodyStr);
      final response = await http.post(
        uri,
        headers: headers,
        body: bodyStr,
      );

      _extractCookies(response);
      logResponse('POST', uri, response);

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      final isSuccess = response.statusCode == 200 || response.statusCode == 201;
      if (isSuccess) {
        String msg = 'OTP sent successfully';
        if (decoded is Map && decoded['message'] != null) {
          msg = decoded['message'].toString();
        }
        return ApiResponse(
          success: true,
          message: msg,
          data: decoded is Map<String, dynamic> ? decoded : null,
          statusCode: response.statusCode,
        );
      } else {
        final errorMsg = _extractErrorMessage(decoded, response.statusCode);
        return ApiResponse(
          success: false,
          message: errorMsg,
          data: decoded is Map<String, dynamic> ? decoded : null,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Login Step 1 exception: $e');
      return ApiResponse(
        success: false,
        message: 'Network error: Please check your internet connection.',
        statusCode: 0,
      );
    }
  }

  /// Step 2: Verify OTP for Login
  /// POST https://apihis.hmissupport.in/api/v1/auth/login
  /// Payload: {"username":"nodaloffice@gmail.com","password":"Test@123","otp":"123456"}
  Future<ApiResponse> verifyLoginOtp({
    required String username,
    required String password,
    required String otp,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/login');
      final payload = {
        'username': username.trim(),
        'password': password,
        'otp': otp.trim(),
      };

      final headers = _buildHeaders();
      final bodyStr = jsonEncode(payload);
      logRequest('POST', uri, headers, bodyStr);
      final response = await http.post(
        uri,
        headers: headers,
        body: bodyStr,
      );

      _extractCookies(response);
      logResponse('POST', uri, response);

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      final isSuccess = response.statusCode == 200 || response.statusCode == 201;
      if (isSuccess) {
        String msg = 'Signed in successfully';
        if (decoded is Map && decoded['message'] != null) {
          msg = decoded['message'].toString();
        }
        return ApiResponse(
          success: true,
          message: msg,
          data: decoded is Map<String, dynamic> ? decoded : null,
          statusCode: response.statusCode,
        );
      } else {
        final errorMsg = _extractErrorMessage(decoded, response.statusCode);
        return ApiResponse(
          success: false,
          message: errorMsg,
          data: decoded is Map<String, dynamic> ? decoded : null,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Verify Login OTP exception: $e');
      return ApiResponse(
        success: false,
        message: 'Network error: Please check your internet connection.',
        statusCode: 0,
      );
    }
  }

  /// Resend OTP during Login Flow
  Future<ApiResponse> resendLoginOtp({
    required String username,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/resend-otp');
      final payload = {
        'username': username.trim(),
        'password': password,
      };

      final headers = _buildHeaders();
      final bodyStr = jsonEncode(payload);
      logRequest('POST', uri, headers, bodyStr);
      final response = await http.post(
        uri,
        headers: headers,
        body: bodyStr,
      );

      _extractCookies(response);
      logResponse('POST', uri, response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(
          success: true,
          message: 'OTP resent successfully.',
          statusCode: response.statusCode,
        );
      }

      // If resend-otp route returns 404 or non-200, fallback to calling login() again
      return await login(username: username, password: password);
    } catch (_) {
      return await login(username: username, password: password);
    }
  }

  /// Forgot Password - Step 1: Send OTP to Email
  /// POST https://apihis.hmissupport.in/api/v1/auth/forget-password
  /// Payload: {"emailId":"screen@gmail.com"}
  Future<ApiResponse> forgotPasswordSendOtp({
    required String emailId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/forget-password');
      final payload = {
        'emailId': emailId.trim(),
      };

      final headers = _buildHeaders();
      final bodyStr = jsonEncode(payload);
      logRequest('POST', uri, headers, bodyStr);
      final response = await http.post(
        uri,
        headers: headers,
        body: bodyStr,
      );

      _extractCookies(response);
      logResponse('POST', uri, response);

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      final isSuccess = response.statusCode == 200 || response.statusCode == 201;
      if (isSuccess) {
        return ApiResponse(
          success: true,
          message: 'OTP sent to your email address successfully.',
          data: decoded is Map<String, dynamic> ? decoded : null,
          statusCode: response.statusCode,
        );
      } else {
        final errorMsg = _extractErrorMessage(decoded, response.statusCode);
        return ApiResponse(
          success: false,
          message: errorMsg,
          data: decoded is Map<String, dynamic> ? decoded : null,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('FP Step 1 exception: $e');
      return ApiResponse(
        success: false,
        message: 'Network error: Please check your internet connection.',
        statusCode: 0,
      );
    }
  }

  /// Forgot Password - Step 2: Verify OTP
  /// POST https://apihis.hmissupport.in/api/v1/auth/forget-password
  /// Payload: {"emailId":"screen@gmail.com","otp":"123456"}
  Future<ApiResponse> forgotPasswordVerifyOtp({
    required String emailId,
    required String otp,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/forget-password');
      final payload = {
        'emailId': emailId.trim(),
        'otp': otp.trim(),
      };

      final headers = _buildHeaders();
      final bodyStr = jsonEncode(payload);
      logRequest('POST', uri, headers, bodyStr);
      final response = await http.post(
        uri,
        headers: headers,
        body: bodyStr,
      );

      _extractCookies(response);
      logResponse('POST', uri, response);

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      final isSuccess = response.statusCode == 200 || response.statusCode == 201;
      if (isSuccess) {
        return ApiResponse(
          success: true,
          message: 'OTP verified successfully.',
          data: decoded is Map<String, dynamic> ? decoded : null,
          statusCode: response.statusCode,
        );
      } else {
        final errorMsg = _extractErrorMessage(decoded, response.statusCode);
        return ApiResponse(
          success: false,
          message: errorMsg,
          data: decoded is Map<String, dynamic> ? decoded : null,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('FP Step 2 exception: $e');
      return ApiResponse(
        success: false,
        message: 'Network error: Please check your internet connection.',
        statusCode: 0,
      );
    }
  }

  /// Forgot Password - Step 3: Reset Password
  /// POST https://apihis.hmissupport.in/api/v1/auth/forget-password
  /// Payload: {"password":"Test@123456","confirm_password":"Test@123456"}
  Future<ApiResponse> forgotPasswordReset({
    required String password,
    required String confirmPassword,
    String? emailId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/forget-password');
      final payload = <String, dynamic>{
        'password': password,
        'confirm_password': confirmPassword,
      };
      if (emailId != null && emailId.trim().isNotEmpty) {
        payload['emailId'] = emailId.trim();
      }

      final headers = _buildHeaders();
      final bodyStr = jsonEncode(payload);
      logRequest('POST', uri, headers, bodyStr);
      final response = await http.post(
        uri,
        headers: headers,
        body: bodyStr,
      );

      _extractCookies(response);
      logResponse('POST', uri, response);

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      final isSuccess = response.statusCode == 200 || response.statusCode == 201;
      if (isSuccess) {
        return ApiResponse(
          success: true,
          message: 'Password reset successfully! You can now sign in.',
          data: decoded is Map<String, dynamic> ? decoded : null,
          statusCode: response.statusCode,
        );
      } else {
        final errorMsg = _extractErrorMessage(decoded, response.statusCode);
        return ApiResponse(
          success: false,
          message: errorMsg,
          data: decoded is Map<String, dynamic> ? decoded : null,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('FP Step 3 exception: $e');
      return ApiResponse(
        success: false,
        message: 'Network error: Please check your internet connection.',
        statusCode: 0,
      );
    }
  }

  /// GET /api/v1/user-management/access/mobile/menus
  /// Dynamic menu fetch for authenticated staff member
  Future<List<MobileMenu>> fetchMobileMenus() async {
    try {
      final uri = Uri.parse('$baseUrl/user-management/access/mobile/menus');
      final headers = _buildHeaders();
      logRequest('GET', uri, headers);
      final response = await http.get(
        uri,
        headers: headers,
      );

      _extractCookies(response);
      logResponse('GET', uri, response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map ? decoded['data'] : null;
        final menusRaw = data is Map
            ? data['menus']
            : (decoded is Map ? decoded['menus'] : null);
        if (menusRaw is List) {
          final list = menusRaw
              .map((m) => MobileMenu.fromJson(m as Map<String, dynamic>))
              .toList();
          list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
          return list;
        }
      }
      return [];
    } catch (e) {
      debugPrint('fetchMobileMenus exception: $e');
      return [];
    }
  }
}
