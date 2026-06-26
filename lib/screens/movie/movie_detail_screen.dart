import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../app_colors.dart';
import '../../app_theme.dart';
import '../../models/api_movie.dart';
import '../../services/download_service.dart';
import '../../services/movie_service.dart';
import '../../services/payment_service.dart';
import '../../services/review_service.dart';
import '../payment/payment_completion_screen.dart';
import '../player/video_player_screen.dart';
import '../subscription/subscription_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final ApiMovie movie;

  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen>
    with WidgetsBindingObserver {
  bool _isSaved = false;
  bool _savingInProgress = false;
  bool _showSavedToast = false;
  List<ApiMovie> _similarMovies = [];
  List<ReviewItem> _reviews = [];
  bool _reviewsLoading = true;
  bool _showAllCast = false;

  // Access control
  bool _accessLoading = true;
  bool _hasAccess = false;
  String _paymentAmount = '200.00';
  String _downloadUrl = '';
  bool _isDownloaded = false;
  bool _downloadLoading = false;
  double? _downloadProgress;   // null = idle, 0.0–1.0 = downloading
  bool _addedToDownloads = false;
  bool _isDownloadPaused = false;  // true when a .part file exists
  String _activeDownloadUrl = ''; // URL reused on resume

  // Inline trailer player (media_kit)
  Player? _trailerPlayer;
  VideoController? _trailerVideoController;
  bool _trailerInitialized = false;
  bool _trailerMuted = true;
  bool _trailerPaused = false;
  bool _showPauseIcon = false;

  String get _effectiveTrailerUrl {
    if (widget.movie.thrillerClipUrl.isNotEmpty) return widget.movie.thrillerClipUrl;
    if (widget.movie.trailerUrl.isNotEmpty) return widget.movie.trailerUrl;
    return '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSimilar();
    _loadReviews();
    _checkAccess();
    _checkLocalDownload();
    // Defer trailer init until after the first frame renders.
    // Running _initTrailer() synchronously in initState blocks the raster
    // thread during codec negotiation, causing 100+ frame Choreographer skips.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initTrailer();
    });
  }

  Future<void> _initTrailer() async {
    final url = _effectiveTrailerUrl;
    if (url.isEmpty) return;
    try {
      final player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 8 * 1024 * 1024, // 8 MB — small buffer for a preview clip
        ),
      );
      final videoCtrl = VideoController(player);

      // Mute before opening so we never steal AudioFocus from the main player
      await player.setVolume(0);
      await player.setPlaylistMode(PlaylistMode.loop);
      await player.open(Media(url, httpHeaders: {'Connection': 'keep-alive'}));

      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _trailerPlayer = player;
        _trailerVideoController = videoCtrl;
        _trailerInitialized = true;
      });
    } catch (_) {
      // Silently fall back to static thumbnail
    }
  }

  Future<void> _checkLocalDownload() async {
    final downloaded = await DownloadService.isDownloaded(widget.movie.id);
    final paused = downloaded ? false : await DownloadService.isPaused(widget.movie.id);
    if (mounted) {
      setState(() {
        _isDownloaded = downloaded;
        _isDownloadPaused = paused;
      });
    }
  }

  Future<void> _checkAccess() async {
    setState(() => _accessLoading = true);
    try {
      final result =
          await MovieService.checkDownloadAccess(widget.movie.id);
      if (mounted) {
        setState(() {
          _hasAccess = result.allowed;
          _paymentAmount = result.amount;
          if (result.downloadUrl.isNotEmpty) _downloadUrl = result.downloadUrl;
        });
      }
    } catch (_) {
      // Network error — fail open so the UI isn't permanently blocked
      if (mounted) setState(() => _hasAccess = false);
    } finally {
      if (mounted) setState(() => _accessLoading = false);
    }
  }

  Future<void> _playMovie() async {
    final localPath = await DownloadService.getLocalPath(widget.movie.id);
    final url = localPath ??
        (_downloadUrl.isNotEmpty ? _downloadUrl : widget.movie.movieFileUrl);
    if (url.isEmpty) return;
    if (!mounted) return;
    // Pause trailer before entering full player to release AudioFocus entirely,
    // preventing the AudioTrack-disabled underrun chain seen in logcat.
    _trailerPlayer?.pause();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: url,
          title: widget.movie.title,
          movieId: widget.movie.id,
        ),
      ),
    );
    // Resume trailer only if user did not manually pause it before navigating.
    if (mounted && !_trailerPaused && _trailerInitialized) {
      _trailerPlayer?.play();
    }
  }

  Future<void> _handleDownload() async {
    setState(() => _downloadLoading = true);
    try {
      // Resolve the video URL — reuse cached URL on resume to avoid a
      // redundant confirmMoviePayment round-trip when possible.
      String videoUrl = _activeDownloadUrl;
      if (videoUrl.isEmpty) {
        final backendUrl = await MovieService.confirmMoviePayment(widget.movie.id);
        videoUrl = backendUrl.isNotEmpty ? backendUrl : _downloadUrl;
      }
      if (videoUrl.isEmpty) throw Exception('No download URL');

      setState(() {
        _activeDownloadUrl = videoUrl;
        _downloadProgress = 0.0;
        _isDownloadPaused = false;
      });

      await DownloadService.downloadMovie(
        widget.movie.id,
        videoUrl,
        (p) { if (mounted) setState(() => _downloadProgress = p); },
      );

      if (!mounted) return;
      setState(() {
        _isDownloaded = true;
        _addedToDownloads = true;
        _downloadProgress = null;
        _activeDownloadUrl = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloaded — watch offline anytime'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } on DownloadPausedException {
      // User tapped pause — not an error, just update UI
      if (!mounted) return;
      setState(() {
        _downloadProgress = null;
        _isDownloadPaused = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloadProgress = null;
        _activeDownloadUrl = '';
      });
      final msg = e.toString().replaceAll('Exception:', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $msg'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _downloadLoading = false);
    }
  }

  void _pauseDownload() {
    DownloadService.pauseDownload(widget.movie.id);
  }

  void _showPaywall() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PaywallSheet(
        movieTitle: widget.movie.title,
        amount: _paymentAmount,
        onPremium: () async {
          Navigator.pop(context);
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const SubscriptionScreen()),
          );
          // Re-check access in case they just subscribed
          _checkAccess();
        },
        onPayPerMovie: () async {
          Navigator.pop(context); // dismiss paywall sheet
          setState(() => _accessLoading = true);
          try {
            final paymentLink = await PaymentService.initiatePayment(1); // BASIC plan
            final txRef = await PaymentService.getPendingTxRef() ?? '';
            if (!mounted || txRef.isEmpty) return;

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentCompletionScreen(
                  paymentLink: paymentLink,
                  txRef: txRef,
                  planName: 'Basic Movie',
                  onPaymentSuccess: (verifiedTxRef) async {
                    await MovieService.confirmMoviePayment(
                      widget.movie.id,
                      txRef: verifiedTxRef,
                    );
                  },
                ),
              ),
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not initiate payment: $e')),
              );
            }
          } finally {
            if (mounted) _checkAccess();
          }
        },
      ),
    );
  }

  Future<void> _loadReviews() async {
    setState(() => _reviewsLoading = true);
    try {
      final reviews = await ReviewService.fetchReviews(widget.movie.id);
      if (mounted) setState(() => _reviews = reviews);
    } catch (_) {
      // silent — reviews section will just show empty
    } finally {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _loadSimilar() async {
    try {
      final cats = await MovieService.fetchCategories();
      // Find the first matching category id
      final firstCat = widget.movie.categoryNames.isNotEmpty
          ? widget.movie.categoryNames.first
          : null;
      if (firstCat == null) return;
      final match = cats.firstWhere(
        (c) => c['name'].toString() == firstCat,
        orElse: () => {},
      );
      if (match.isEmpty) return;
      final movies = await MovieService.fetchMovies(
          categoryId: match['id'] as int);
      if (mounted) {
        setState(() {
          _similarMovies =
              movies.where((m) => m.id != widget.movie.id).take(4).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    if (_savingInProgress) return;
    setState(() => _savingInProgress = true);
    try {
      if (_isSaved) {
        await MovieService.unsaveMovie(widget.movie.id);
        if (mounted) setState(() => _isSaved = false);
      } else {
        await MovieService.saveMovie(widget.movie.id);
        if (mounted) {
          setState(() {
            _isSaved = true;
            _showSavedToast = true;
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _showSavedToast = false);
          });
        }
      }
    } catch (_) {
      // silent fail — UI stays as-is
    } finally {
      if (mounted) setState(() => _savingInProgress = false);
    }
  }

  void _showRatingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RatingSheet(
        onSubmit: (rating, comment) async {
          try {
            final review = await ReviewService.submitReview(
                widget.movie.id, rating, comment);
            if (mounted) {
              setState(() => _reviews = [review, ..._reviews]);
              Navigator.pop(context);
              _showRatingSuccess();
            }
          } on ReviewException catch (e) {
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.message)),
              );
            }
          }
        },
      ),
    );
  }

  void _showRatingSuccess() {
    final theme = AppTheme.of(context);
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(120),
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.iconBg),
                    ),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Rating Submitted',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Thank you for your feedback this helps us improve our services',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Okay, got it',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trailerPlayer?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_trailerPlayer == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _trailerPlayer!.pause();
      if (mounted) setState(() => _trailerPaused = true);
    } else if (state == AppLifecycleState.resumed && !_trailerPaused) {
      _trailerPlayer!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movie;
    final genre = m.categoryNames.join(', ');
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Video player / thumbnail area
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    // Inline trailer (autoplays, muted) or static thumbnail
                    SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: _trailerInitialized
                          ? Video(
                              controller: _trailerVideoController!,
                              fill: Colors.black,
                              fit: BoxFit.cover,
                              controls: NoVideoControls,
                            )
                          : (m.thumbnailUrl.isNotEmpty
                              ? Image.network(
                                  m.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (ctx, err, st) =>
                                      Container(color: theme.iconBg),
                                )
                              : Container(color: theme.iconBg)),
                    ),
                    // Bottom gradient for readability
                    const Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 80,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black45],
                          ),
                        ),
                      ),
                    ),
                    // Tap whole area → pause/resume trailer (if playing) or play/paywall
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _trailerInitialized
                            ? () {
                                if (_trailerPaused) {
                                  _trailerPlayer!.play();
                                } else {
                                  _trailerPlayer!.pause();
                                }
                                setState(() {
                                  _trailerPaused = !_trailerPaused;
                                  _showPauseIcon = true;
                                });
                                Future.delayed(const Duration(milliseconds: 800), () {
                                  if (mounted) setState(() => _showPauseIcon = false);
                                });
                              }
                            : (_accessLoading
                                ? null
                                : (_hasAccess ? _playMovie : _showPaywall)),
                        child: _trailerInitialized
                            ? AnimatedOpacity(
                                opacity: _showPauseIcon ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Center(
                                  child: Container(
                                    width: 54,
                                    height: 54,
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _trailerPaused
                                          ? Icons.play_arrow_rounded
                                          : Icons.pause_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const _PlayButton(),
                                    if (_effectiveTrailerUrl.isNotEmpty)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: Text(
                                          'TRAILER',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    // Mute / unmute (only while trailer playing inline)
                    if (_trailerInitialized)
                      Positioned(
                        bottom: 8,
                        right: 48,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _trailerMuted = !_trailerMuted);
                            _trailerPlayer?.setVolume(_trailerMuted ? 0 : 100);
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _trailerMuted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                        ),
                      ),
                    // Fullscreen button (only while trailer playing inline)
                    if (_trailerInitialized)
                      Positioned(
                        bottom: 8,
                        right: 10,
                        child: GestureDetector(
                          onTap: () async {
                            _trailerPlayer?.pause();
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VideoPlayerScreen(
                                  videoUrl: _effectiveTrailerUrl,
                                  title: '${widget.movie.title} — Trailer',
                                ),
                              ),
                            );
                            if (mounted && !_trailerPaused && _trailerInitialized) {
                              _trailerPlayer?.play();
                            }
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.fullscreen_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    // Close / back button
                    Positioned(
                      top: 40,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(120),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trailer',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Movie info row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: m.thumbnailUrl.isNotEmpty
                                ? Image.network(
                                    m.thumbnailUrl,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, st) => Container(
                                      width: 40,
                                      height: 40,
                                      color: theme.iconBg,
                                    ),
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    color: theme.iconBg,
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textPrimary,
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (m.releaseYear.isNotEmpty)
                                      Text(m.releaseYear,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textGrey)),
                                    if (m.releaseYear.isNotEmpty &&
                                        m.runtime.isNotEmpty)
                                      const SizedBox(width: 8),
                                    if (m.runtime.isNotEmpty)
                                      Text(m.runtime,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textGrey)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey.shade400),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'HD',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textGrey),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!_isSaved)
                            OutlinedButton.icon(
                              onPressed: _toggleSave,
                              icon: const Icon(Icons.bookmark_border,
                                  size: 16),
                              label: const Text('Save Movie',
                                  style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.textPrimary,
                                side: BorderSide(
                                    color: theme.iconBg),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Play button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _accessLoading
                              ? null
                              : (_hasAccess ? _playMovie : _showPaywall),
                          icon: _accessLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _hasAccess
                                      ? Icons.play_arrow
                                      : Icons.lock_outline,
                                  size: 20,
                                ),
                          label: Text(
                            _accessLoading ? 'Checking...' : 'Play',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Download button (with pause/resume support)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: (_accessLoading || (_downloadLoading && _downloadProgress == null))
                              ? null
                              : (_downloadProgress != null
                                  // Actively downloading → tap pauses
                                  ? _pauseDownload
                                  : (_isDownloaded || _addedToDownloads
                                      ? null
                                      : (_hasAccess
                                          // Paused or fresh → tap starts/resumes
                                          ? _handleDownload
                                          : _showPaywall))),
                          icon: (_accessLoading || (_downloadLoading && _downloadProgress == null))
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : _downloadProgress != null
                                  ? const Icon(Icons.pause, size: 20)
                                  : Icon(
                                      (_isDownloaded || _addedToDownloads)
                                          ? Icons.download_done
                                          : _isDownloadPaused
                                              ? Icons.play_arrow
                                              : (_hasAccess
                                                  ? Icons.download
                                                  : Icons.lock_outline),
                                      size: 20,
                                    ),
                          label: Text(
                            (_accessLoading || (_downloadLoading && _downloadProgress == null))
                                ? 'Preparing...'
                                : _downloadProgress != null
                                    ? 'Downloading ${(_downloadProgress! * 100).toInt()}%  —  tap to pause'
                                    : (_isDownloaded || _addedToDownloads)
                                        ? 'Downloaded'
                                        : _isDownloadPaused
                                            ? 'Resume Download'
                                            : 'Download Movie',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.darkBg,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      if (_downloadProgress != null) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _downloadProgress,
                            minHeight: 4,
                            color: AppColors.primary,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                      ],
                      if (_isSaved) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _toggleSave,
                            icon: const Icon(Icons.bookmark, size: 20),
                            label: const Text('Save Movie',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.darkBg,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Movie details
                      Text(
                        'Movie details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (m.synopsis.isNotEmpty)
                        Text(
                          m.synopsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textGrey,
                            height: 1.5,
                          ),
                        ),

                      // Extra details
                      if (m.director.isNotEmpty ||
                          m.cast.isNotEmpty ||
                          genre.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        if (m.director.isNotEmpty)
                          _DetailRow(label: 'Director', value: m.director),
                        if (m.cast.isNotEmpty) ...[
                          Builder(builder: (context) {
                            final allCast = m.cast
                                .split(',')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty)
                                .toList();
                            final visible = _showAllCast
                                ? allCast
                                : allCast.take(3).toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DetailRow(
                                    label: 'Cast',
                                    value: visible.join(', ')),
                                if (allCast.length > 3)
                                  GestureDetector(
                                    onTap: () => setState(
                                        () => _showAllCast = !_showAllCast),
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        children: [
                                          const SizedBox(width: 84),
                                          Text(
                                            _showAllCast
                                                ? 'View less'
                                                : 'View more cast',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Icon(
                                            _showAllCast
                                                ? Icons.keyboard_arrow_up
                                                : Icons.keyboard_arrow_down,
                                            size: 14,
                                            color: AppColors.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }),
                        ],
                        if (genre.isNotEmpty)
                          _DetailRow(label: 'Genre', value: genre),
                        if (m.rating.isNotEmpty)
                          _DetailRow(label: 'Rating', value: m.rating),
                      ],

                      const SizedBox(height: 24),

                      // Similar movies
                      if (_similarMovies.isNotEmpty) ...[
                        Text(
                          'Similar Movie Genre',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          genre,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textGrey),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _similarMovies.length,
                            itemBuilder: (context, i) {
                              final sim = _similarMovies[i];
                              return GestureDetector(
                                onTap: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MovieDetailScreen(movie: sim),
                                  ),
                                ),
                                child: Container(
                                  width: 95,
                                  margin: const EdgeInsets.only(right: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: sim.thumbnailUrl.isNotEmpty
                                              ? Image.network(
                                                  sim.thumbnailUrl,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  errorBuilder:
                                                      (_, _, _) =>
                                                          Container(
                                                    color:
                                                        theme.iconBg,
                                                  ),
                                                )
                                              : Container(
                                                  color:
                                                      theme.iconBg),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(sim.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500)),
                                      Text(
                                        sim.releaseYear.isNotEmpty
                                            ? '${sim.releaseYear} · ${sim.runtime}'
                                            : sim.runtime,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textGrey),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Reviews section
                      Row(
                        children: [
                          Text(
                            _reviewsLoading
                                ? 'Reviews'
                                : 'Reviews (${_reviews.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.star,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            m.rating.isNotEmpty ? m.rating : '—',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Review list
                      if (_reviewsLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        )
                      else if (_reviews.isNotEmpty)
                        ...List.generate(_reviews.length, (i) {
                          final r = _reviews[i];
                          return _ReviewCard(review: r);
                        }),

                      const SizedBox(height: 16),

                      // Rate movie button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _showRatingSheet,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                                color: AppColors.primary, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Rate Movie',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Saved toast
          if (_showSavedToast)
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Material(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.primary,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Saved  Video added to your saved list',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Detail row (Director, Cast, etc.)
// ─────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.textPrimary),
            ),
          ),
          const Text(': ',
              style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Play button overlay
// ─────────────────────────────────────────────

class _PlayButton extends StatelessWidget {
  const _PlayButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
        color: Colors.white.withAlpha(200),
      ),
      child: const Icon(Icons.play_arrow, color: AppColors.primary, size: 32),
    );
  }
}

// ─────────────────────────────────────────────
// Review card
// ─────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final ReviewItem review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withAlpha(30),
                child: Text(
                  review.username.isNotEmpty
                      ? review.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.username,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: theme.textPrimary),
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: AppColors.primary,
                  );
                }),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.comment,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textGrey, height: 1.4),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Rating sheet
// ─────────────────────────────────────────────

class _RatingSheet extends StatefulWidget {
  final Future<void> Function(int rating, String comment) onSubmit;
  const _RatingSheet({required this.onSubmit});

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _rating = 4;
  final _reviewController = TextEditingController();
  final Set<String> _selectedTags = {};

  final List<String> _tags = [
    'Reliable',
    'Fast',
    'Good Service',
    'Nice Story',
    'Not Good',
    'Poor Service',
  ];

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rate Movie',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.iconBg),
                  ),
                  child: const Icon(Icons.close,
                      size: 16, color: AppColors.textGrey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Icon(
                  i < _rating ? Icons.star : Icons.star_border,
                  color: AppColors.primary,
                  size: 36,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reviewController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Write Review (Optional)',
              hintStyle:
                  const TextStyle(color: AppColors.textLight, fontSize: 14),
              filled: true,
              fillColor: AppColors.inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              final selected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedTags.remove(tag);
                  } else {
                    _selectedTags.add(tag);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : theme.iconBg,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          selected ? Colors.white : theme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () =>
                  widget.onSubmit(_rating, _reviewController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Submit',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Paywall sheet
// ─────────────────────────────────────────────

class _PaywallSheet extends StatefulWidget {
  final String movieTitle;
  final String amount;
  final Future<void> Function() onPremium;
  final Future<void> Function() onPayPerMovie;

  const _PaywallSheet({
    required this.movieTitle,
    required this.amount,
    required this.onPremium,
    required this.onPayPerMovie,
  });

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  bool _paying = false;

  Future<void> _handlePayPerMovie() async {
    setState(() => _paying = true);
    try {
      await widget.onPayPerMovie();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Get Access',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.movieTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: theme.iconBg, width: 1.5),
                  ),
                  child: const Icon(Icons.close, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Option A — PREMIUM
          GestureDetector(
            onTap: () async {
              await widget.onPremium();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primary.withAlpha(80), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.diamond_outlined,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subscribe to PREMIUM',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: theme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '₦5,500/mo · Unlimited access to all movies',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textGrey),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.primary, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: theme.iconBg)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('or',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textGrey)),
              ),
              Expanded(child: Divider(color: theme.iconBg)),
            ],
          ),
          const SizedBox(height: 12),

          // Option B — Pay per movie
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _paying ? null : _handlePayPerMovie,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBg,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _paying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Pay ₦${widget.amount} for this movie',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'One-time payment · Valid for 10 days',
              style: TextStyle(fontSize: 11, color: AppColors.textGrey),
            ),
          ),
        ],
      ),
    );
  }
}
