import 'package:flutter/material.dart';
import '../../app_colors.dart';
import '../../app_theme.dart';
import '../../models/api_movie.dart';
import '../../services/movie_service.dart';

class WatchHistoryScreen extends StatefulWidget {
  const WatchHistoryScreen({super.key});

  @override
  State<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends State<WatchHistoryScreen> {
  List<WatchHistoryItem> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await MovieService.fetchWatchHistory();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load watch history');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Days remaining using the accurate expires_at from UserMovieAccess.
  int _daysLeft(String? expiresAt) {
    if (expiresAt == null || expiresAt.isEmpty) return 0;
    try {
      final expires = DateTime.parse(expiresAt);
      return expires.difference(DateTime.now()).inDays.clamp(0, 10);
    } catch (_) {
      return 0;
    }
  }

  /// Progress estimate: watch_duration / 7200 s (≈ 2-hour movie).
  double _progress(int watchDuration) =>
      (watchDuration / 7200.0).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Watch History',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.textSecondary),
            onPressed: _load,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Watch History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Titles auto-expire 10 days after first play',
              style: TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppTheme theme) {
    if (_isLoading) {
      return ListView.separated(
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, _) => _HistoryShimmer(theme: theme),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.textGrey, size: 40),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppColors.textGrey)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _load,
              child: const Text('Retry',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, color: theme.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text(
              'No watch history yet',
              style: TextStyle(color: theme.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final item = _items[i];
        final daysLeft = _daysLeft(item.expiresAt);
        final progress = _progress(item.watchDuration);

        return Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item.movieThumbnailUrl.isNotEmpty
                  ? Image.network(
                      item.movieThumbnailUrl,
                      width: 90,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _ThumbnailPlaceholder(
                          width: 90, height: 70, theme: theme),
                    )
                  : _ThumbnailPlaceholder(
                      width: 90, height: 70, theme: theme),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.movieTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: theme.progressTrack,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              daysLeft > 0 ? '${daysLeft}d left' : 'Expired',
              style: TextStyle(
                fontSize: 12,
                color:
                    daysLeft > 0 ? AppColors.textGrey : AppColors.errorRed,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    ),    // ListView.separated
    );    // RefreshIndicator
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final AppTheme theme;
  const _ThumbnailPlaceholder(
      {required this.width, required this.height, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: theme.iconBg,
      child: const Icon(Icons.movie, color: AppColors.textGrey),
    );
  }
}

class _HistoryShimmer extends StatelessWidget {
  final AppTheme theme;
  const _HistoryShimmer({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 90,
          height: 70,
          decoration: BoxDecoration(
            color: theme.iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: theme.iconBg,
                      borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 8),
              Container(
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: theme.iconBg,
                      borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
            height: 12,
            width: 40,
            decoration: BoxDecoration(
                color: theme.iconBg,
                borderRadius: BorderRadius.circular(6))),
      ],
    );
  }
}
