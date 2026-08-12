const String kMediaBase = 'https://web-production-3fa8c.up.railway.app';

String buildMediaUrl(dynamic path) {
  if (path == null || path.toString().isEmpty) return '';
  final s = path.toString();
  return s.startsWith('http') ? s : '$kMediaBase$s';
}

class ApiMovie {
  final int id;
  final String title;
  final String synopsis;
  final String thumbnailUrl;
  final String movieFileUrl;
  final List<String> categoryNames;
  final String cast;
  final String releaseYear;
  final String runtime;
  final String rating;
  final String director;
  final int viewsCount;
  final bool isTrending;
  final bool isFeatured;
  final String createdAt;
  final String trailerUrl;
  final String thrillerClipUrl;

  const ApiMovie({
    required this.id,
    required this.title,
    required this.synopsis,
    required this.thumbnailUrl,
    required this.movieFileUrl,
    required this.categoryNames,
    required this.cast,
    required this.releaseYear,
    required this.runtime,
    required this.rating,
    required this.director,
    required this.viewsCount,
    required this.isTrending,
    required this.isFeatured,
    required this.createdAt,
    required this.trailerUrl,
    required this.thrillerClipUrl,
  });

  factory ApiMovie.fromJson(Map<String, dynamic> json) {
    return ApiMovie(
      id: json['id'] as int,
      title: json['title']?.toString() ?? '',
      synopsis: json['synopsis']?.toString() ?? '',
      thumbnailUrl: buildMediaUrl(json['thumbnail']),
      movieFileUrl: buildMediaUrl(json['movie_file']),
      categoryNames: (json['category_names'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      cast: json['cast']?.toString() ?? '',
      releaseYear: json['release_year']?.toString() ?? '',
      runtime: json['runtime']?.toString() ?? '',
      rating: json['rating']?.toString() ?? '',
      director: json['director']?.toString() ?? '',
      viewsCount: json['views_count'] as int? ?? 0,
      isTrending: json['is_trending'] as bool? ?? false,
      isFeatured: json['is_featured'] as bool? ?? false,
      createdAt: json['created_at']?.toString() ?? '',
      trailerUrl: buildMediaUrl(json['trailer_url']),
      thrillerClipUrl: buildMediaUrl(json['thriller_clip']),
    );
  }
}

class WatchHistoryItem {
  final int id;
  final int movieId;
  final String movieTitle;
  final String movieThumbnailUrl;
  final String watchedAt;
  final int watchDuration; // seconds
  /// ISO-8601 expiry from UserMovieAccess. Null if no access record exists.
  final String? expiresAt;

  const WatchHistoryItem({
    required this.id,
    required this.movieId,
    required this.movieTitle,
    required this.movieThumbnailUrl,
    required this.watchedAt,
    required this.watchDuration,
    this.expiresAt,
  });

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return WatchHistoryItem(
      id: json['id'] as int,
      movieId: json['movie'] as int,
      movieTitle: json['movie_title']?.toString() ?? '',
      movieThumbnailUrl: buildMediaUrl(json['movie_thumbnail']),
      watchedAt: json['watched_at']?.toString() ?? '',
      watchDuration: json['watch_duration'] as int? ?? 0,
      expiresAt: json['expires_at']?.toString(),
    );
  }
}

class DownloadItem {
  final int id;
  final int movieId;
  final String movieTitle;
  final String movieThumbnailUrl;
  final String movieFileUrl;
  final String amountPaid;
  final String paidAt;

  const DownloadItem({
    required this.id,
    required this.movieId,
    required this.movieTitle,
    required this.movieThumbnailUrl,
    required this.movieFileUrl,
    required this.amountPaid,
    required this.paidAt,
  });

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] as int,
      movieId: json['movie'] as int,
      movieTitle: json['movie_title']?.toString() ?? '',
      movieThumbnailUrl: buildMediaUrl(json['movie_thumbnail']),
      movieFileUrl: buildMediaUrl(json['movie_file']),
      amountPaid: json['amount_paid']?.toString() ?? '0',
      paidAt: json['paid_at']?.toString() ?? '',
    );
  }
}
