import 'package:flutter/material.dart';
import '../../app_colors.dart';
import '../../models/api_movie.dart';
import '../../services/movie_service.dart';
import '../movie/movie_detail_screen.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  // API state
  List<Map<String, dynamic>> _categories = [];
  List<ApiMovie> _allMovies = [];
  bool _loading = true;
  int _selectedGenreIndex = 0; // 0 = All

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final cats = await MovieService.fetchCategories();
      final movies = await MovieService.fetchMovies();
      if (mounted) {
        setState(() {
          _categories = cats;
          _allMovies = movies;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ApiMovie> get _searchResults {
    final q = _searchController.text.toLowerCase();
    if (q.isEmpty) return _allMovies;
    return _allMovies
        .where((m) =>
            m.title.toLowerCase().contains(q) ||
            m.cast.toLowerCase().contains(q) ||
            m.director.toLowerCase().contains(q) ||
            m.categoryNames.any((c) => c.toLowerCase().contains(q)))
        .toList();
  }

  List<ApiMovie> get _filteredMovies {
    if (_selectedGenreIndex == 0) return _allMovies;
    final name = _categories[_selectedGenreIndex - 1]['name'].toString();
    return _allMovies
        .where((m) => m.categoryNames.contains(name))
        .toList();
  }

  // Group filtered movies by category
  Map<String, List<ApiMovie>> get _groupedMovies {
    if (_selectedGenreIndex != 0) {
      final name = _categories[_selectedGenreIndex - 1]['name'].toString();
      final movies = _filteredMovies;
      return movies.isEmpty ? {} : {name: movies};
    }
    final Map<String, List<ApiMovie>> grouped = {};
    for (final cat in _categories) {
      final name = cat['name'].toString();
      final movies =
          _allMovies.where((m) => m.categoryNames.contains(name)).toList();
      if (movies.isNotEmpty) grouped[name] = movies;
    }
    return grouped;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final genreLabels = ['All', ..._categories.map((c) => c['name'].toString())];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              if (!_isSearching) ...[
                const Text(
                  'Browse',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Explore the full catalogue by genre.',
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
                const SizedBox(height: 16),
              ],

              // Search bar
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isSearching = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isSearching
                              ? Colors.white
                              : AppColors.inputBg,
                          borderRadius: BorderRadius.circular(10),
                          border: _isSearching
                              ? Border.all(
                                  color: AppColors.primary, width: 1.5)
                              : null,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                color: AppColors.textGrey, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _isSearching
                                  ? TextField(
                                      controller: _searchController,
                                      autofocus: true,
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Search titles, directors, casts....',
                                        hintStyle: TextStyle(
                                            color: AppColors.textGrey,
                                            fontSize: 14),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    )
                                  : const Text(
                                      'Search titles, directors, casts....',
                                      style: TextStyle(
                                          color: AppColors.textGrey,
                                          fontSize: 14),
                                    ),
                            ),
                            if (_isSearching &&
                                _searchController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                child: const Icon(Icons.close,
                                    color: AppColors.textGrey, size: 18),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isSearching) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _isSearching = false);
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              if (_loading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_isSearching)
                // Search results
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Movies & TV',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final movie = _searchResults[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MovieDetailScreen(movie: movie),
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: movie.thumbnailUrl.isNotEmpty
                                        ? Image.network(
                                            movie.thumbnailUrl,
                                            width: 64,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (ctx, err, st) =>
                                                    Container(
                                              width: 64,
                                              height: 50,
                                              color: Colors.grey.shade200,
                                            ),
                                          )
                                        : Container(
                                            width: 64,
                                            height: 50,
                                            color: Colors.grey.shade200,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      movie.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppColors.textDark,
                                          width: 1.5),
                                    ),
                                    child: const Icon(Icons.play_arrow,
                                        size: 16,
                                        color: AppColors.textDark),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // Genre pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(genreLabels.length, (i) {
                      final selected = _selectedGenreIndex == i;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedGenreIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: selected
                                ? null
                                : Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            genreLabels[i],
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppColors.textDark,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),

                // Genre sections grid
                Expanded(
                  child: _groupedMovies.isEmpty
                      ? const Center(
                          child: Text('No movies found.',
                              style: TextStyle(color: AppColors.textGrey)),
                        )
                      : ListView(
                          children: [
                            ..._groupedMovies.entries.map(
                              (entry) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 24),
                                child: _GenreGrid(
                                  title: entry.key,
                                  movies: entry.value,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GenreGrid extends StatelessWidget {
  final String title;
  final List<ApiMovie> movies;

  const _GenreGrid({required this.title, required this.movies});

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.65,
          ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: movie.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              movie.thumbnailUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (ctx, err, st) => Container(
                                color: Colors.grey.shade200,
                              ),
                            )
                          : Container(color: Colors.grey.shade200),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    movie.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    [
                      if (movie.releaseYear.isNotEmpty) movie.releaseYear,
                      if (movie.runtime.isNotEmpty) movie.runtime,
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textGrey),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
