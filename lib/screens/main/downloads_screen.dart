import 'dart:async';

import 'package:flutter/material.dart';
import '../../app_colors.dart';
import '../../app_theme.dart';
import '../../models/api_movie.dart';
import '../../services/download_service.dart';
import '../../services/movie_service.dart';
import '../player/video_player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<DownloadItem> _items = [];
  bool _isLoading = true;
  String? _error;

  /// Per-movie local state — refreshed on load and on every progress event.
  Map<int, bool> _isDownloaded = {};
  Map<int, bool> _isPaused = {};

  StreamSubscription<void>? _progressSub;

  @override
  void initState() {
    super.initState();
    _load();
    // Re-check local state whenever any download makes progress or finishes.
    _progressSub = DownloadService.progressUpdates.listen((_) {
      if (mounted) _refreshLocalState();
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  /// Days remaining in the 10-day access window starting from [paidAt].
  int _daysLeft(String paidAt) {
    if (paidAt.isEmpty) return 0;
    try {
      final purchased = DateTime.parse(paidAt);
      final expires = purchased.add(const Duration(days: 10));
      return expires.difference(DateTime.now()).inDays.clamp(0, 10);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await MovieService.fetchMyDownloads();
      if (!mounted) return;
      setState(() => _items = items);
      await _refreshLocalState();
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load downloads');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Pre-computes downloaded/paused state for all items.
  /// Called on initial load and whenever the progress stream fires.
  Future<void> _refreshLocalState() async {
    final downloaded = <int, bool>{};
    final paused = <int, bool>{};
    for (final item in _items) {
      downloaded[item.movieId] = await DownloadService.isDownloaded(item.movieId);
      paused[item.movieId] = downloaded[item.movieId]!
          ? false
          : await DownloadService.isPaused(item.movieId);
    }
    if (mounted) {
      setState(() {
        _isDownloaded = downloaded;
        _isPaused = paused;
      });
    }
  }

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
          'Downloads',
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
              'Your Download History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
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
        itemBuilder: (_, _) => _DownloadShimmer(theme: theme),
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
            Text(_error!, style: const TextStyle(color: AppColors.textGrey)),
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
            Icon(Icons.download_done_rounded,
                color: theme.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text(
              'No downloads yet',
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
        itemBuilder: (context, i) => _buildItem(context, _items[i], theme),
      ),
    );
  }

  Widget _buildItem(BuildContext context, DownloadItem item, AppTheme theme) {
    final daysLeft = _daysLeft(item.paidAt);
    final expired = daysLeft <= 0;
    final downloaded = _isDownloaded[item.movieId] ?? false;
    final paused = _isPaused[item.movieId] ?? false;
    final activeProgress = DownloadService.currentProgress(item.movieId);
    final downloading = activeProgress != null;

    // Play is only available when fully on disk, not expired, not mid-download.
    final canPlay = downloaded && !expired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item.movieThumbnailUrl.isNotEmpty
                  ? Image.network(
                      item.movieThumbnailUrl,
                      width: 90,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _ThumbnailPlaceholder(width: 90, height: 70, theme: theme),
                    )
                  : _ThumbnailPlaceholder(width: 90, height: 70, theme: theme),
            ),
            const SizedBox(width: 14),

            // Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + status icon
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.movieTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: expired
                                ? AppColors.textGrey
                                : theme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (downloaded)
                        const Icon(Icons.download_done_rounded,
                            color: AppColors.successGreen, size: 14)
                      else if (downloading)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            value: activeProgress,
                            color: AppColors.primary,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.2),
                          ),
                        )
                      else if (paused)
                        const Icon(Icons.pause_circle_outline_rounded,
                            color: AppColors.textGrey, size: 14),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Status line
                  Text(
                    expired
                        ? 'Expired'
                        : downloading
                            ? 'Downloading ${(activeProgress * 100).toInt()}%'
                            : paused
                                ? 'Download paused — tap play to resume'
                                : downloaded
                                    ? '${daysLeft}d left · Ready to watch'
                                    : '${daysLeft}d left',
                    style: TextStyle(
                      fontSize: 12,
                      color: expired
                          ? AppColors.errorRed
                          : downloading || paused
                              ? AppColors.primary
                              : AppColors.textGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Play button
            GestureDetector(
              onTap: canPlay
                  ? () async {
                      final localPath =
                          await DownloadService.getLocalPath(item.movieId);
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(
                            videoUrl: localPath ?? item.movieFileUrl,
                            title: item.movieTitle,
                          ),
                        ),
                      );
                    }
                  : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: canPlay ? theme.textPrimary : AppColors.textGrey,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: canPlay ? theme.textPrimary : AppColors.textGrey,
                  size: 18,
                ),
              ),
            ),
          ],
        ),

        // Progress bar — shown while downloading or paused mid-download
        if (downloading || paused) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: downloading ? activeProgress : null,
              minHeight: 3,
              color: AppColors.primary,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
        ],
      ],
    );
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

class _DownloadShimmer extends StatelessWidget {
  final AppTheme theme;
  const _DownloadShimmer({required this.theme});

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
        const SizedBox(width: 14),
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
              const SizedBox(height: 6),
              Container(
                  height: 12,
                  width: 60,
                  decoration: BoxDecoration(
                      color: theme.iconBg,
                      borderRadius: BorderRadius.circular(6))),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.iconBg,
          ),
        ),
      ],
    );
  }
}
