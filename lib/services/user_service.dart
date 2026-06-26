import 'package:dio/dio.dart';
import 'storage_service.dart';

class UserException implements Exception {
  final String message;
  UserException(this.message);

  @override
  String toString() => message;
}

class UserProfile {
  final int id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? bio;
  final String? profilePictureUrl;
  final bool isEmailVerified;
  final int watchedCount;
  final int savedCount;
  final int reviewsCount;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.bio,
    this.profilePictureUrl,
    required this.isEmailVerified,
    required this.watchedCount,
    required this.savedCount,
    required this.reviewsCount,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      fullName: (json['full_name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phoneNumber: json['phone_number'] as String?,
      bio: json['bio'] as String?,
      profilePictureUrl: json['profile_picture'] as String?,
      isEmailVerified: (json['is_email_verified'] as bool?) ?? false,
      watchedCount: (json['watched_count'] as int?) ?? 0,
      savedCount: (json['saved_count'] as int?) ?? 0,
      reviewsCount: (json['reviews_count'] as int?) ?? 0,
    );
  }

}

class UserService {
  static const String _baseUrl = 'https://web-production-a39f0a.up.railway.app/api/users';

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    contentType: 'application/json',
  ));

  static Future<Options> _authOptions() async {
    final token = await StorageService.getAccessToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ── Fetch Profile ──────────────────────────────────────────────

  static Future<UserProfile> getProfile() async {
    try {
      final response = await _dio.get(
        '/profile/',
        options: await _authOptions(),
      );
      return UserProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw UserException(_parseError(e));
    }
  }

  // ── Update Profile ─────────────────────────────────────────────

  static Future<UserProfile> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? bio,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (fullName != null) body['full_name'] = fullName;
      if (phoneNumber != null) body['phone_number'] = phoneNumber;
      if (bio != null) body['bio'] = bio;

      final response = await _dio.patch(
        '/profile/',
        data: body,
        options: await _authOptions(),
      );
      return UserProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw UserException(_parseError(e));
    }
  }

  // ── Upload Profile Picture ─────────────────────────────────────

  static Future<UserProfile> uploadProfilePicture(String filePath) async {
    try {
      final token = await StorageService.getAccessToken();
      final formData = FormData.fromMap({
        'profile_picture': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.patch(
        '/profile/picture/',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          contentType: 'multipart/form-data',
        ),
      );
      return UserProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw UserException(_parseError(e));
    }
  }

  // ── Change Password ────────────────────────────────────────────

  static Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '/change-password/',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
        options: await _authOptions(),
      );
    } on DioException catch (e) {
      throw UserException(_parseError(e));
    }
  }

  // ── Error Parsing ──────────────────────────────────────────────

  static String _parseError(DioException e) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map) {
        for (final key in ['detail', 'error', 'non_field_errors']) {
          if (data[key] != null) {
            final v = data[key];
            return v is List ? v.first.toString() : v.toString();
          }
        }
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
