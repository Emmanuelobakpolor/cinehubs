import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../app_assets.dart';
import '../../app_colors.dart';
import '../../app_theme.dart';
import '../../models/api_movie.dart';
import '../../models/app_notification.dart';
import '../../services/fcm_service.dart';
import '../../services/movie_service.dart';
import '../../services/notification_service.dart';
import '../movie/movie_detail_screen.dart';
import '../browse/browse_screen.dart';
import '../notifications/notifications_screen.dart';

// ─── Top-level genre helpers ───────────────────────────────────────────────


const List<List<Color>> _kCardGradients = [
  [Color(0xFF8E24AA), Color(0xFF5C1A8C)],
  [Color(0xFFE53935), Color(0xFF8B0000)],
  [Color(0xFF1E88E5), Color(0xFF0D47A1)],
  [Color(0xFF43A047), Color(0xFF1B5E20)],
  [Color(0xFFBFA726), Color(0xFF7A6A10)],
  [Color(0xFFFF6F00), Color(0xFFBF360C)],
  [Color(0xFF00897B), Color(0xFF004D40)],
  [Color(0xFF3949AB), Color(0xFF1A237E)],
  [Color(0xFFD81B60), Color(0xFF880E4F)],
  [Color(0xFF00ACC1), Color(0xFF006064)],
];

List<Color> _gradientFor(int index) => _kCardGradients[index % _kCardGradients.length];

// ──────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 0 = TV Shows, 1 = Movies, 2 = Categories
  int _selectedTab = 1;
  String? _pickedCategory;

  ApiMovie? _featuredMovie;
  Map<String, List<ApiMovie>> _categoryMovies = {};
  bool _loading = true;

  // Notifications
  int _unreadCount = 0;
  Timer? _notifTimer;
  // IDs seen in this session — populated on first poll so we don't
  // banner-notify for notifications that already existed before the user opened the app.
  Set<int>? _seenNotifIds;
  OverlayEntry? _bannerEntry;

  @override
  void initState() {
    super.initState();
    _loadData();
    _pollNotifications();
    // Poll every 30 seconds so the badge stays fresh
    _notifTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _pollNotifications(),
    );
    // Open notifications if user tapped a system notification to open the app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FCMService.consumePendingTap()) {
        _openNotifications();
      }
      // Subscribe to FCM messages that arrive while the app is in foreground.
      // These won't show a system notification — we show our in-app banner instead.
      FirebaseMessaging.onMessage.listen((message) {
        if (!mounted) return;
        final title = message.notification?.title ?? '';
        final body  = message.notification?.body  ?? '';
        if (title.isEmpty && body.isEmpty) return;
        final notif = AppNotification(
          id: DateTime.now().millisecondsSinceEpoch,
          title: title,
          message: body,
          notificationType: 'BROADCAST',
          targetAudience: message.data['audience'] ?? 'ALL',
          createdAt: DateTime.now(),
        );
        _showNotificationBanner(notif);
        _pollNotifications(); // refresh badge count
      });
    });
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    _bannerEntry?.remove();
    super.dispose();
  }

  Future<void> _pollNotifications() async {
    try {
      final notifications = await NotificationService.fetchMyNotifications();
      if (!mounted) return;

      final unread = notifications.where((n) => !n.isRead).length;
      final currentIds = notifications.map((n) => n.id).toSet();

      if (_seenNotifIds == null) {
        // First poll — just record what's there, no banners.
        _seenNotifIds = currentIds;
      } else {
        // Subsequent polls — find genuinely new notifications.
        final newNotifs = notifications
            .where((n) => !_seenNotifIds!.contains(n.id))
            .toList();
        _seenNotifIds = currentIds;

        // Show a banner for the most recent new notification (newest last in list).
        if (newNotifs.isNotEmpty) {
          _showNotificationBanner(newNotifs.last);
        }
      }

      setState(() => _unreadCount = unread);
    } catch (_) {}
  }

  void _showNotificationBanner(AppNotification notif) {
    // Remove any existing banner first so we don't stack them.
    _bannerEntry?.remove();
    _bannerEntry = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NotificationBanner(
        notif: notif,
        onTap: () {
          entry.remove();
          _bannerEntry = null;
          _openNotifications();
        },
        onDismiss: () {
          entry.remove();
          _bannerEntry = null;
        },
      ),
    );

    _bannerEntry = entry;
    Overlay.of(context).insert(entry);

    // Auto-dismiss after 6 seconds.
    Future.delayed(const Duration(seconds: 6), () {
      if (_bannerEntry == entry) {
        try { entry.remove(); } catch (_) {}
        _bannerEntry = null;
      }
    });
  }

  void _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    // Re-poll when returning so badge updates immediately.
    _pollNotifications();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);
    try {
      ApiMovie? featured = await MovieService.fetchFeatured();
      if (featured == null) {
        final trending = await MovieService.fetchTrending();
        featured = trending.isNotEmpty ? trending.first : null;
      }

      final categories = await MovieService.fetchCategories();
      final Map<String, List<ApiMovie>> catMovies = {};
      for (final cat in categories) {
        final id = cat['id'] as int;
        final name = cat['name'].toString();
        final movies = await MovieService.fetchMovies(categoryId: id);
        if (movies.isNotEmpty) catMovies[name] = movies;
      }

      if (mounted) {
        setState(() {
          _featuredMovie = featured;
          _categoryMovies = catMovies;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<ApiMovie>> get _visibleMovies {
    if (_selectedTab == 0) {
      final tv = Map.fromEntries(_categoryMovies.entries.where((e) {
        final n = e.key.toLowerCase();
        return n.contains('tv') ||
            n.contains('series') ||
            n.contains('show') ||
            n.contains('episode');
      }));
      return tv.isEmpty ? _categoryMovies : tv;
    }
    if (_selectedTab == 2 && _pickedCategory != null) {
      final movies = _categoryMovies[_pickedCategory!];
      if (movies != null) return {_pickedCategory!: movies};
    }
    return _categoryMovies;
  }

  void _onTabTap(int i) {
    if (i == 2) {
      _openCategoriesPage();
    } else {
      setState(() {
        _selectedTab = i;
        _pickedCategory = null;
      });
    }
  }

  void _openCategoriesPage() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return _CategoriesPage(
            categoryMovies: _categoryMovies,
            pickedCategory: _pickedCategory,
            onCategorySelected: (name) {
              setState(() {
                _selectedTab = 2;
                _pickedCategory = name;
              });
            },
            onAllSelected: () {
              setState(() {
                _selectedTab = 2;
                _pickedCategory = null;
              });
            },
          );
        },
        transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          return SlideTransition(position: slide, child: child);
        },
      ),
    );
  }

  String get _categoriesPillLabel =>
      (_selectedTab == 2 && _pickedCategory != null)
          ? _pickedCategory!
          : 'Categories';

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final featured = _featuredMovie;

    return Scaffold(
      backgroundColor: theme.background,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FeaturedHero(
                          featured: featured,
                          selectedTab: _selectedTab,
                          categoriesPillLabel: _categoriesPillLabel,
                          onTabTap: _onTabTap,
                          unreadCount: _unreadCount,
                          onNotificationTap: _openNotifications,
                          onTap: featured == null
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          MovieDetailScreen(movie: featured),
                                    ),
                                  ),
                          onSearchTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BrowseScreen()),
                          ),
                        ),

                        const SizedBox(height: 20),

                        if (_visibleMovies.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 40),
                            child: Center(
                              child: Text(
                                'No movies found in this category.',
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        else
                          ..._visibleMovies.entries.map((entry) => Padding(
                                padding: const EdgeInsets.only(
                                    left: 16, right: 16, bottom: 36),
                                child: _CategorySection(
                                  title: entry.key,
                                  movies: entry.value,
                                ),
                              )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────
// Full-Screen Categories Page
// ─────────────────────────────────────────────

class _CategoriesPage extends StatefulWidget {
  final Map<String, List<ApiMovie>> categoryMovies;
  final String? pickedCategory;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onAllSelected;

  const _CategoriesPage({
    required this.categoryMovies,
    required this.pickedCategory,
    required this.onCategorySelected,
    required this.onAllSelected,
  });

  @override
  State<_CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<_CategoriesPage> {
  late String? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.pickedCategory;
  }

  @override
  Widget build(BuildContext context) {
    final categoryNames = widget.categoryMovies.keys.toList();
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          SizedBox(height: topPadding + 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Browse',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      '${categoryNames.length} genres available',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── "All" chip ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: GestureDetector(
              onTap: () {
                widget.onAllSelected();
                Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                decoration: BoxDecoration(
                  color: _picked == null
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: _picked == null
                      ? null
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.apps_rounded,
                      size: 15,
                      color: _picked == null ? Colors.black : Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'All Categories',
                      style: TextStyle(
                        color: _picked == null ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Genre Grid ─────────────────────────────────────────────────
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
              ),
              itemCount: categoryNames.length,
              itemBuilder: (ctx, i) {
                final name = categoryNames[i];
                final isSelected = _picked == name;
                final movies = widget.categoryMovies[name] ?? [];
                final thumbUrl =
                    movies.isNotEmpty ? movies.first.thumbnailUrl : '';
                final gradient = _gradientFor(i);

                return GestureDetector(
                  onTap: () {
                    setState(() => _picked = name);
                    widget.onCategorySelected(name);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: AppColors.primary, width: 2.5)
                          : Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                              width: 1,
                            ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                          isSelected ? 10 : 11),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // ── Background: thumbnail or gradient fallback ──
                          if (thumbUrl.isNotEmpty)
                            Image.network(
                              thumbUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _GradientFallback(gradient: gradient),
                            )
                          else
                            _GradientFallback(gradient: gradient),

                          // ── Cinematic dark overlay ──────────────────────
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.15),
                                  Colors.black.withValues(alpha: 0.80),
                                ],
                                stops: const [0.0, 1.0],
                              ),
                            ),
                          ),

                          // ── Gold tint when selected ─────────────────────
                          if (isSelected)
                            Container(
                              color:
                                  AppColors.primary.withValues(alpha: 0.18),
                            ),

                          // ── Text content ────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: 0.2,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black87,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${movies.length} title${movies.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.65),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Selected checkmark badge ────────────────────
                          if (isSelected)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.black,
                                  size: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Gradient fallback when thumbnail is missing
// ─────────────────────────────────────────────

class _GradientFallback extends StatelessWidget {
  final List<Color> gradient;

  const _GradientFallback({required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Category Section (horizontal scroll row)
// ─────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final String title;
  final List<ApiMovie> movies;

  const _CategorySection({required this.title, required this.movies});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            itemBuilder: (context, i) {
              final movie = movies[i];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MovieDetailScreen(movie: movie),
                  ),
                ),
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: 160,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: theme.iconBg,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: movie.thumbnailUrl.isNotEmpty
                                  ? Image.network(
                                      movie.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, st) =>
                                          Container(color: theme.iconBg),
                                    )
                                  : Container(color: theme.iconBg),
                            ),
                          ),
                          // Play icon overlay on hover (always visible, subtle)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (movie.releaseYear.isNotEmpty) movie.releaseYear,
                          if (movie.runtime.isNotEmpty) movie.runtime,
                        ].join('  •  '),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Featured Hero
// ─────────────────────────────────────────────

class _FeaturedHero extends StatelessWidget {
  final ApiMovie? featured;
  final int selectedTab;
  final String categoriesPillLabel;
  final ValueChanged<int> onTabTap;
  final VoidCallback? onTap;
  final VoidCallback onSearchTap;
  final int unreadCount;
  final VoidCallback onNotificationTap;

  const _FeaturedHero({
    required this.featured,
    required this.selectedTab,
    required this.categoriesPillLabel,
    required this.onTabTap,
    required this.onTap,
    required this.onSearchTap,
    required this.unreadCount,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    final List<String> tabLabels = ['TV Shows', 'Movies', categoriesPillLabel];

    return SizedBox(
      height: screenHeight * 0.87,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Movie poster — full bleed background
          if (featured != null && featured!.thumbnailUrl.isNotEmpty)
            Image.network(
              featured!.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) =>
                  Container(color: const Color(0xFF2D1B4E)),
            )
          else
            Container(color: const Color(0xFF2D1B4E)),

          // 2. Top gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.heroTopGradient.withValues(alpha: 0.92),
                  theme.heroTopGradient.withValues(alpha: 0.60),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.18, 0.36],
              ),
            ),
          ),

          // 3. Bottom gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.45, 1.0],
              ),
            ),
          ),

          // 4. Logo + search + notifications row
          Positioned(
            top: topPadding + 2,
            left: 16,
            right: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(AppAssets.logo, height: 67),
                const Spacer(),
                // Notification bell with unread badge
                GestureDetector(
                  onTap: onNotificationTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.notifications_outlined, color: theme.heroIcon, size: 26),
                        if (unreadCount > 0)
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.search, color: theme.heroIcon, size: 24),
                  onPressed: onSearchTap,
                ),
              ],
            ),
          ),

          // 5. Tab pills
          Positioned(
            top: topPadding + 62,
            left: 16,
            right: 16,
            child: Row(
              children: List.generate(tabLabels.length, (i) {
                final isSelected = selectedTab == i;
                return GestureDetector(
                  onTap: () => onTabTap(i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.heroPillFill
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? theme.heroPillFill
                            : theme.heroPillBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tabLabels[i],
                          style: TextStyle(
                            color: isSelected
                                ? theme.heroPillText
                                : theme.heroIcon,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        if (i == 2) ...[
                          const SizedBox(width: 3),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: isSelected
                                ? theme.heroPillText
                                : theme.heroIcon,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          // 6. Title + description + buttons
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  featured?.title ?? '',
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                  ),
                ),
                if (featured?.synopsis.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    featured!.synopsis,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.45,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow,
                                size: 22, color: Colors.black),
                            SizedBox(width: 6),
                            Text(
                              'Play Movie',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Colors.white, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline,
                                size: 20, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'More info',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Broadcast notification banner (slides in from top)
// ─────────────────────────────────────────────

class _NotificationBanner extends StatefulWidget {
  final AppNotification notif;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.notif,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Padding(
            padding: EdgeInsets.only(
              top: topPad + 10,
              left: 12,
              right: 12,
            ),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {
                  _ctrl.reverse().then((_) {
                    if (mounted) widget.onTap();
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.notif.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.notif.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap to view',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _dismiss,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            color: Colors.white38,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
