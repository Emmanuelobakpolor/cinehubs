import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app_colors.dart';
import '../../services/movie_service.dart';

// ─── Screen ────────────────────────────────────────────────────────────────

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  /// Pass the backend movie ID to enable watch-progress tracking.
  /// Null for trailers (no progress saved).
  final int? movieId;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    this.movieId,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // ── media_kit objects ──
  late final Player _player;
  late final VideoController _videoController;

  // ── controls animation ──
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  bool _controlsVisible = true;
  bool _isFullscreen = false;
  bool _hasError = false;
  String _errorMessage = '';

  Timer? _hideTimer;
  Timer? _progressTimer;
  StreamSubscription<String?>? _errorSub;
  StreamSubscription<bool>? _completedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Controls fade controller — starts visible (value = 1.0)
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Player with 32 MB pre-buffer
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
      ),
    );
    _videoController = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _openMedia();
    _startProgressTimer();
    _scheduleHideControls();

    _errorSub = _player.stream.error.listen((err) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = err;
        });
      }
    });

    _completedSub = _player.stream.completed.listen((done) {
      if (done && mounted) _showControls();
    });
  }

  void _openMedia() {
    _player.open(
      Media(widget.videoUrl, httpHeaders: const {'Connection': 'keep-alive'}),
    );
  }

  // ── Progress tracking ──

  void _startProgressTimer() {
    if (widget.movieId == null) return;
    _progressTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _sendProgress());
  }

  void _sendProgress() {
    if (widget.movieId == null) return;
    MovieService.updateWatchProgress(
        widget.movieId!, _player.state.position.inSeconds);
  }

  // ── Controls visibility ──

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _player.state.playing && _controlsVisible) {
        _fadeCtrl.reverse();
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      _fadeCtrl.reverse();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  void _showControls() {
    if (!_controlsVisible) {
      _fadeCtrl.forward();
      setState(() => _controlsVisible = true);
    }
    _scheduleHideControls();
  }

  // ── Fullscreen ──

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    _showControls();
  }

  // ── Retry after error ──

  void _retry() {
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
    _openMedia();
  }

  // ── Lifecycle ──

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _player.pause();
      _sendProgress();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _errorSub?.cancel();
    _completedSub?.cancel();
    _fadeCtrl.dispose();
    _sendProgress();
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _player.dispose();
    super.dispose();
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video is GPU-rendered via a Texture widget internally —
            // completely isolated from Flutter's UI thread.
            RepaintBoundary(
              child: Video(
                controller: _videoController,
                fill: Colors.black,
                fit: BoxFit.contain,
                controls: NoVideoControls,
              ),
            ),

            // Error overlay
            if (_hasError)
              _ErrorView(message: _errorMessage, onRetry: _retry),

            // Controls overlay — fades in/out, pointer-ignored when hidden
            if (!_hasError)
              FadeTransition(
                opacity: _fadeAnim,
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: _ControlsOverlay(
                    player: _player,
                    title: widget.title,
                    isFullscreen: _isFullscreen,
                    onBack: () => Navigator.of(context).pop(),
                    onToggleFullscreen: _toggleFullscreen,
                    onInteraction: _showControls,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Controls Overlay ──────────────────────────────────────────────────────

class _ControlsOverlay extends StatelessWidget {
  final Player player;
  final String title;
  final bool isFullscreen;
  final VoidCallback onBack;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onInteraction;

  const _ControlsOverlay({
    required this.player,
    required this.title,
    required this.isFullscreen,
    required this.onBack,
    required this.onToggleFullscreen,
    required this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xBB000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xBB000000),
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: Column(
        children: [
          // ── Top bar ──
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                    onPressed: onBack,
                  ),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _SpeedButton(player: player, onInteraction: onInteraction),
                ],
              ),
            ),
          ),

          // ── Center: skip + play/pause ──
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _SkipButton(
                    player: player, seconds: -10, onInteraction: onInteraction),
                _PlayPauseButton(
                    player: player, onInteraction: onInteraction),
                _SkipButton(
                    player: player, seconds: 10, onInteraction: onInteraction),
              ],
            ),
          ),

          // ── Bottom: seek bar + time + fullscreen ──
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProgressBar(
                      player: player, onInteraction: onInteraction),
                  Row(
                    children: [
                      _TimeDisplay(player: player),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          isFullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: onToggleFullscreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Play / Pause ──────────────────────────────────────────────────────────

class _PlayPauseButton extends StatelessWidget {
  final Player player;
  final VoidCallback onInteraction;

  const _PlayPauseButton(
      {required this.player, required this.onInteraction});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: player.stream.buffering,
      initialData: player.state.buffering,
      builder: (_, bufSnap) {
        if (bufSnap.data == true) {
          return const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 3),
          );
        }
        return StreamBuilder<bool>(
          stream: player.stream.playing,
          initialData: player.state.playing,
          builder: (_, playSnap) {
            final playing = playSnap.data ?? false;
            return IconButton(
              iconSize: 64,
              icon: Icon(
                playing
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: Colors.white,
              ),
              onPressed: () {
                onInteraction();
                player.playOrPause();
              },
            );
          },
        );
      },
    );
  }
}

// ─── Skip ±N seconds ───────────────────────────────────────────────────────

class _SkipButton extends StatelessWidget {
  final Player player;
  final int seconds;
  final VoidCallback onInteraction;

  const _SkipButton({
    required this.player,
    required this.seconds,
    required this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 36,
      icon: Icon(
        seconds < 0 ? Icons.replay_10 : Icons.forward_10,
        color: Colors.white,
      ),
      onPressed: () {
        onInteraction();
        final pos = player.state.position + Duration(seconds: seconds);
        player.seek(pos.isNegative ? Duration.zero : pos);
      },
    );
  }
}

// ─── Speed selector ────────────────────────────────────────────────────────

class _SpeedButton extends StatelessWidget {
  final Player player;
  final VoidCallback onInteraction;

  const _SpeedButton(
      {required this.player, required this.onInteraction});

  static String _label(double r) =>
      r == r.truncateToDouble() ? '${r.toInt()}x' : '${r}x';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.stream.rate,
      initialData: player.state.rate,
      builder: (context, snap) {
        final rate = snap.data ?? 1.0;
        return PopupMenuButton<double>(
          initialValue: rate,
          color: const Color(0xFF1C1C1C),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          onSelected: (v) {
            onInteraction();
            player.setRate(v);
          },
          itemBuilder: (_) => const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
              .map(
                (s) => PopupMenuItem(
                  value: s,
                  child: Text(
                    _label(s),
                    style: TextStyle(
                      color:
                          s == rate ? AppColors.primary : Colors.white,
                      fontWeight: s == rate
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              )
              .toList(),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              _label(rate),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Time display ──────────────────────────────────────────────────────────

class _TimeDisplay extends StatelessWidget {
  final Player player;

  const _TimeDisplay({required this.player});

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (_, posSnap) => StreamBuilder<Duration>(
        stream: player.stream.duration,
        initialData: player.state.duration,
        builder: (_, durSnap) {
          final pos = posSnap.data ?? Duration.zero;
          final dur = durSnap.data ?? Duration.zero;
          return Text(
            '${_fmt(pos)} / ${_fmt(dur)}',
            style:
                const TextStyle(color: Colors.white70, fontSize: 12),
          );
        },
      ),
    );
  }
}

// ─── Progress / seek bar ───────────────────────────────────────────────────

class _ProgressBar extends StatefulWidget {
  final Player player;
  final VoidCallback onInteraction;

  const _ProgressBar(
      {required this.player, required this.onInteraction});

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  bool _dragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.duration,
      initialData: widget.player.state.duration,
      builder: (_, durSnap) {
        final duration = durSnap.data ?? Duration.zero;

        // While duration is unknown, show indeterminate bar
        if (duration == Duration.zero) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: LinearProgressIndicator(
              value: null,
              backgroundColor: Colors.white24,
              color: AppColors.primary,
              minHeight: 3,
            ),
          );
        }

        return StreamBuilder<Duration>(
          stream: widget.player.stream.position,
          initialData: widget.player.state.position,
          builder: (_, posSnap) {
            final position = posSnap.data ?? Duration.zero;
            final value = _dragging
                ? _dragValue
                : (position.inMilliseconds / duration.inMilliseconds)
                    .clamp(0.0, 1.0);

            return SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 18),
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: AppColors.primary,
                overlayColor:
                    AppColors.primary.withValues(alpha: 0.25),
              ),
              child: Slider(
                value: value,
                onChangeStart: (v) {
                  widget.onInteraction();
                  setState(() {
                    _dragging = true;
                    _dragValue = v;
                  });
                },
                onChanged: (v) => setState(() => _dragValue = v),
                onChangeEnd: (v) {
                  setState(() => _dragging = false);
                  widget.player.seek(duration * v);
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Error view ────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.errorRed, size: 52),
            const SizedBox(height: 16),
            Text(
              message.isNotEmpty ? message : 'Could not load video.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
