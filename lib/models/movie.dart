import '../app_assets.dart';

class Movie {
  final String id;
  final String title;
  final String genre;
  final String year;
  final String duration;
  final String imagePath;
  final double rating;
  final int reviewCount;
  final String description;
  final bool isHD;
  final String seasons;

  const Movie({
    required this.id,
    required this.title,
    required this.genre,
    required this.year,
    required this.duration,
    required this.imagePath,
    this.rating = 4.6,
    this.reviewCount = 86,
    this.description = '',
    this.isHD = true,
    this.seasons = '',
  });
}

final List<Movie> thrillerMovies = [
  Movie(
    id: '1',
    title: 'Avengers',
    genre: 'Action',
    year: '2024',
    duration: '2h 14m',
    imagePath: AppAssets.avengers,
    rating: 4.8,
    reviewCount: 124,
    description:
        'Earth\'s mightiest heroes must come together and learn to fight as a team if they are going to stop the mischievous Loki and his alien army from enslaving humanity.',
  ),
  Movie(
    id: '2',
    title: 'Echo',
    genre: 'Drama',
    year: '2024',
    duration: '2h 14m',
    imagePath: AppAssets.echo,
    rating: 4.3,
    reviewCount: 64,
    description:
        'A gripping tale of sound and silence. When a young musician loses her hearing, she discovers a world of vibrations that opens new dimensions of music and life.',
  ),
  Movie(
    id: '3',
    title: 'The Boy',
    genre: 'Thriller',
    year: '2024',
    duration: '1h 58m',
    imagePath: AppAssets.theBoy,
    rating: 4.6,
    reviewCount: 86,
    description:
        'Hearts flip as Heather weds Tarek. Jason and Mary grapple with being ghosted. Go solo or take the next step: The agents face life-changing decisions.\n\nFlying high: Chrishell reveals her latest love – Jason. In LA, the agents get real about the relationship while Christine readies her return.',
  ),
  Movie(
    id: '4',
    title: 'Escape Room',
    genre: 'Thriller',
    year: '2024',
    duration: '1h 30m',
    imagePath: AppAssets.escapeRoom,
    rating: 4.0,
    reviewCount: 48,
    description:
        'Six strangers find themselves in circumstances beyond their control and must use their wits to find the clues or die.',
  ),
];

final List<Movie> actionMovies = [
  Movie(
    id: '5',
    title: 'Avengers',
    genre: 'Action',
    year: '2024',
    duration: '2h 14m',
    imagePath: AppAssets.avengers,
    rating: 4.8,
    reviewCount: 124,
    description:
        'Earth\'s mightiest heroes must come together and learn to fight as a team if they are going to stop the mischievous Loki and his alien army from enslaving humanity.',
  ),
  Movie(
    id: '6',
    title: 'Echo',
    genre: 'Action',
    year: '2024',
    duration: '2h 14m',
    imagePath: AppAssets.echo,
    rating: 4.3,
    reviewCount: 64,
    description: 'A gripping action-packed adventure.',
  ),
  Movie(
    id: '7',
    title: 'The Boy',
    genre: 'Action',
    year: '2024',
    duration: '1h 58m',
    imagePath: AppAssets.theBoy,
    rating: 4.6,
    reviewCount: 86,
    description:
        'A charming story of identity and resilience.',
  ),
];

final List<Movie> dramaMovies = [
  Movie(
    id: '8',
    title: "A Fisherwoman's Dream",
    genre: 'Drama',
    year: '2024',
    duration: '2h 5m',
    imagePath: AppAssets.fisherwomanDream,
    rating: 4.5,
    reviewCount: 72,
    description:
        'A determined fisherwoman battles the odds to provide for her family while chasing a dream that transcends the shores of her village.',
  ),
  Movie(
    id: '9',
    title: 'Escape Room',
    genre: 'Drama',
    year: '2024',
    duration: '1h 30m',
    imagePath: AppAssets.escapeRoom,
    rating: 4.0,
    reviewCount: 48,
    description: 'A drama about finding your way out.',
  ),
  Movie(
    id: '10',
    title: 'Echo',
    genre: 'Drama',
    year: '2024',
    duration: '2h 14m',
    imagePath: AppAssets.echo,
    rating: 4.3,
    reviewCount: 64,
    description: 'A gripping tale of sound and silence.',
  ),
];

final List<Movie> allMovies = [
  ...thrillerMovies,
  ...actionMovies,
  ...dramaMovies,
];

final Movie featuredMovie = Movie(
  id: 'featured',
  title: 'Selling Sunset',
  genre: 'Drama',
  year: '2022',
  duration: '5 Seasons',
  imagePath: AppAssets.sellingSunset,
  rating: 4.6,
  reviewCount: 86,
  seasons: '5 Seasons',
  description:
      'Hearts flip as Heather weds Tarek. Jason and Mary grapple with being ghosted. Go solo or take the next step: The agents face life-changing decisions.\n\nFlying high: Chrishell reveals her latest love – Jason. In LA, the agents get real about the relationship while Christine readies her return.',
);
