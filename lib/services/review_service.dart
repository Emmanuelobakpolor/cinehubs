import 'package:dio/dio.dart';
import 'storage_service.dart';

class ReviewItem {
  final int id;
  final int userId;
  final String username;
  final int movieId;
  final int rating;
  final String comment;
  final String createdAt;

  const ReviewItem({
    required this.id,
    required this.userId,
    required this.username,
    required this.movieId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    return ReviewItem(
      id: json['id'] as int,
      userId: json['user'] as int? ?? 0,
      username: json['username']?.toString() ?? '',
      movieId: json['movie'] as int? ?? 0,
      rating: json['rating'] as int? ?? 0,
      comment: json['comment']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class ReviewException implements Exception {
  final String message;
  ReviewException(this.message);
}

class ReviewService {
  static const String _base = 'https://web-production-a39f0a.up.railway.app/api/reviews';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static Future<Options> _authOptions() async {
    final token = await StorageService.getAccessToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// Fetch reviews for a movie.
  static Future<List<ReviewItem>> fetchReviews(int movieId) async {
    final opts = await _authOptions();
    final res = await _dio.get('$_base/movie/$movieId/', options: opts);
    final data = res.data;
    final list = data is List ? data : (data['results'] as List? ?? []);
    return list
        .map((e) => ReviewItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Submit a review for a movie. Throws [ReviewException] on API error.
  static Future<ReviewItem> submitReview(
      int movieId, int rating, String? comment) async {
    final opts = await _authOptions();
    try {
      final res = await _dio.post(
        '$_base/movie/$movieId/',
        data: {
          'rating': rating,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
        options: opts,
      );
      return ReviewItem.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ReviewException(_extractError(e.response?.data));
    }
  }

  static String _extractError(dynamic data) {
    if (data == null) return 'Something went wrong';
    if (data is Map) {
      final detail = data['detail'] ?? data['error'];
      if (detail != null) return detail.toString();
      final nonField = data['non_field_errors'];
      if (nonField is List && nonField.isNotEmpty) {
        return nonField.first.toString();
      }
      for (final v in data.values) {
        if (v is List && v.isNotEmpty) return v.first.toString();
      }
    }
    return 'Something went wrong';
  }
}
