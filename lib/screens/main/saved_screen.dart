import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../app_colors.dart';
import '../../app_theme.dart';
import '../../models/api_movie.dart';
import '../../services/storage_service.dart';
import '../movie/movie_detail_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => SavedScreenState();
}

class SavedScreenState extends State<SavedScreen> {
  static const String _base = 'https://web-production-a39f0a.up.railway.app/api';
  static final Dio _dio = Dio();

  List<_SavedEntry> _saved = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  /// Called by MainScreen when the Saved tab is selected.
  void refresh() => _loadSaved();

  Future<void> _loadSaved() async {
    try {
      final token = await StorageService.getAccessToken();
      final res = await _dio.get(
        '$_base/movies/saved/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final list = res.data is List ? res.data as List : [];
      final entries = list.map((e) {
        final thumb = e['movie_thumbnail']?.toString() ?? '';
        final fullThumb = thumb.startsWith('http')
            ? thumb
            : thumb.isNotEmpty
                ? '${kMediaBase}$thumb'
                : '';
        return _SavedEntry(
          savedId: e['id'] as int,
          movieId: e['movie'] as int,
          title: e['movie_title']?.toString() ?? '',
          thumbnailUrl: fullThumb,
        );
      }).toList();
      if (mounted) setState(() { _saved = entries; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unsave(int savedId) async {
    final entry = _saved.firstWhere((s) => s.savedId == savedId);
    try {
      final token = await StorageService.getAccessToken();
      await _dio.delete(
        '$_base/movies/saved/${entry.movieId}/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) setState(() => _saved.removeWhere((s) => s.savedId == savedId));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Movies Saved',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_saved.length} movie${_saved.length == 1 ? '' : 's'} saved in your queue',
                style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _loadSaved,
                    child: _saved.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: 300,
                                child: Center(
                                  child: Text(
                                    'No saved movies yet.',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: theme.textSecondary),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.65,
                    ),
                    itemCount: _saved.length,
                    itemBuilder: (context, i) {
                      final entry = _saved[i];
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MovieDetailScreen(
                              movie: ApiMovie(
                                id: entry.movieId,
                                title: entry.title,
                                synopsis: '',
                                thumbnailUrl: entry.thumbnailUrl,
                                movieFileUrl: '',
                                categoryNames: const [],
                                cast: '',
                                releaseYear: '',
                                runtime: '',
                                rating: '',
                                director: '',
                                viewsCount: 0,
                                isTrending: false,
                                isFeatured: false,
                                createdAt: '',
                                trailerUrl: '',
                                thrillerClipUrl: '',
                              ),
                            ),
                          ),
                        ).then((_) => _loadSaved()),
                        onLongPress: () => _unsave(entry.savedId),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: entry.thumbnailUrl.isNotEmpty
                                    ? Image.network(
                                        entry.thumbnailUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (ctx, err, st) =>
                                            Container(
                                                color: theme.iconBg),
                                      )
                                    : Container(color: theme.iconBg),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: theme.textPrimary,
                              ),
                            ),
                            const Text(
                              'Saved',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      );
                    },
                  ),  // GridView.builder
                ),    // RefreshIndicator
              ),      // Expanded
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedEntry {
  final int savedId;
  final int movieId;
  final String title;
  final String thumbnailUrl;

  const _SavedEntry({
    required this.savedId,
    required this.movieId,
    required this.title,
    required this.thumbnailUrl,
  });
}
