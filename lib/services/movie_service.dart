import 'package:dio/dio.dart';
import 'storage_service.dart';
import '../models/api_movie.dart';

class MovieService {
  static const String _base = 'https://web-production-a39f0a.up.railway.app/api/movies';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static Future<Options> _authOptions() async {
    final token = await StorageService.getAccessToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// Fetch all movies, optionally filtered by category ID.
  static Future<List<ApiMovie>> fetchMovies({int? categoryId}) async {
    final opts = await _authOptions();
    final url = categoryId != null
        ? '$_base/?categories=$categoryId&page_size=20'
        : '$_base/?page_size=20';
    final res = await _dio.get(url, options: opts);
    final results = (res.data['results'] as List?) ?? [];
    return results.map((e) => ApiMovie.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Fetch trending movies.
  static Future<List<ApiMovie>> fetchTrending() async {
    final opts = await _authOptions();
    final res = await _dio.get('$_base/trending/', options: opts);
    final data = res.data;
    final list = data is List ? data : (data['results'] as List? ?? []);
    return list.map((e) => ApiMovie.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Returns the admin-featured movie, or null if none is set.
  static Future<ApiMovie?> fetchFeatured() async {
    final opts = await _authOptions();
    try {
      final res = await _dio.get('$_base/featured/', options: opts);
      return ApiMovie.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Fetch all categories: [{id, name}, ...]
  static Future<List<Map<String, dynamic>>> fetchCategories() async {
    final opts = await _authOptions();
    final res = await _dio.get('$_base/categories/?page_size=100', options: opts);
    final data = res.data;
    final list = data is List ? data : (data['results'] as List? ?? []);
    return List<Map<String, dynamic>>.from(list);
  }

  /// Save a movie. Returns true if newly saved, false if already saved.
  static Future<bool> saveMovie(int movieId) async {
    final opts = await _authOptions();
    final res = await _dio.post(
      '$_base/saved/',
      data: {'movie_id': movieId},
      options: opts,
    );
    return res.statusCode == 201;
  }

  /// Remove a movie from saved list.
  static Future<void> unsaveMovie(int movieId) async {
    final opts = await _authOptions();
    await _dio.delete('$_base/saved/$movieId/', options: opts);
  }

  /// Report how many seconds the user has watched of [movieId].
  /// Called periodically during playback and on player exit.
  /// Fails silently — a missed progress update is not critical.
  static Future<void> updateWatchProgress(int movieId, int seconds) async {
    try {
      final opts = await _authOptions();
      await _dio.patch(
        '$_base/$movieId/watch-progress/',
        data: {'watch_duration': seconds},
        options: opts,
      );
    } catch (_) {
      // Silent — don't interrupt playback for a failed progress save
    }
  }

  /// Fetch user's watch history.
  static Future<List<WatchHistoryItem>> fetchWatchHistory() async {
    final opts = await _authOptions();
    final res = await _dio.get('$_base/watch-history/', options: opts);
    final data = res.data;
    final list = data is List ? data : (data['results'] as List? ?? []);
    return list
        .map((e) => WatchHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch user's paid/downloaded movies.
  static Future<List<DownloadItem>> fetchMyDownloads() async {
    final opts = await _authOptions();
    final res = await _dio.get('$_base/my-downloads/', options: opts);
    final data = res.data;
    final list = data is List ? data : (data['results'] as List? ?? []);
    return list
        .map((e) => DownloadItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Check whether the current user can play/download [movieId].
  ///
  /// Returns `(allowed: true, ...)` for PREMIUM users or BASIC users who have
  /// already paid for this movie. Returns `(allowed: false, amount: '200.00')`
  /// when payment is required.
  static Future<({bool allowed, String amount, String downloadUrl})>
      checkDownloadAccess(int movieId) async {
    final opts = await _authOptions();
    try {
      final res = await _dio.get('$_base/$movieId/download/', options: opts);
      return (
        allowed: true,
        amount: '0',
        downloadUrl: res.data['download_url']?.toString() ?? '',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        final amount =
            e.response?.data['amount']?.toString() ?? '200.00';
        return (allowed: false, amount: amount, downloadUrl: '');
      }
      rethrow;
    }
  }

  /// Mark [movieId] as paid for the current user (BASIC per-movie flow).
  ///
  /// [txRef] must be the tx_ref of a completed BASIC Payment record on the backend.
  /// Premium users and users who already paid bypass this check server-side,
  /// so [txRef] may be omitted in those cases.
  /// Returns the download URL on success.
  static Future<String> confirmMoviePayment(int movieId, {String txRef = ''}) async {
    final opts = await _authOptions();
    final res = await _dio.post(
      '$_base/$movieId/confirm-download/',
      data: {'payment_reference': txRef},
      options: opts,
    );
    return res.data['download_url']?.toString() ?? '';
  }
}
