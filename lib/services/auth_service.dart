import 'package:dio/dio.dart';
import 'storage_service.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static const String _baseUrl = 'https://web-production-a39f0a.up.railway.app/api/users';

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    contentType: 'application/json',
  ));

  // ── Registration ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    try {
      final response = await _dio.post('/register/', data: {
        'full_name': fullName,
        'email': email,
        'password': password,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phone_number': phoneNumber,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw AuthException(_parseError(e));
    }
  }

  // ── Email OTP Verification ────────────────────────────────────

  static Future<void> verifyEmail({required String otp}) async {
    try {
      final accessToken = await StorageService.getAccessToken();
      await _dio.post(
        '/verify-email/',
        data: {'otp': otp},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } on DioException catch (e) {
      throw AuthException(_parseError(e));
    }
  }

  static Future<void> resendEmailOtp() async {
    try {
      final accessToken = await StorageService.getAccessToken();
      await _dio.post(
        '/send-email-otp/',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } on DioException catch (e) {
      throw AuthException(_parseError(e));
    }
  }

  // ── Login / Logout ────────────────────────────────────────────

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/login/', data: {
        'email': email,
        'password': password,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw AuthException(_parseError(e));
    }
  }

  static Future<void> logout() async {
    try {
      final accessToken = await StorageService.getAccessToken();
      final refreshToken = await StorageService.getRefreshToken();
      await _dio.post(
        '/logout/',
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } catch (_) {
      // Always clear local tokens even if the API call fails
    } finally {
      await StorageService.clearTokens();
    }
  }

  // ── Forgot / Reset Password ───────────────────────────────────

  static Future<void> forgotPassword({required String email}) async {
    try {
      await _dio.post('/forgot-password/', data: {'email': email});
    } on DioException catch (e) {
      throw AuthException(_parseError(e));
    }
  }

  static Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await _dio.post('/reset-password/', data: {
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      });
    } on DioException catch (e) {
      throw AuthException(_parseError(e));
    }
  }

  // ── Error Parsing ─────────────────────────────────────────────

  static String _parseError(DioException e) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map) {
        // DRF validation errors come as {field: [msg, ...]} or {detail: msg}
        for (final key in ['detail', 'error', 'non_field_errors']) {
          if (data[key] != null) {
            final v = data[key];
            return v is List ? v.first.toString() : v.toString();
          }
        }
        // Field-level errors – return the first one
        for (final value in data.values) {
          if (value is List && value.isNotEmpty) return value.first.toString();
          if (value is String) return value;
        }
      }
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'Cannot reach server. Check your connection.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
