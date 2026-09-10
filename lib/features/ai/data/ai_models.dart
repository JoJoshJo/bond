import 'package:flutter/foundation.dart';

/// A movie result card returned by the creature's tool-use (TMDB via ai-router).
@immutable
class MovieCard {
  const MovieCard({
    required this.title,
    required this.year,
    required this.rating,
    required this.posterUrl,
    required this.overview,
  });

  final String title;
  final String year;
  final double rating;
  final String? posterUrl;
  final String overview;

  factory MovieCard.fromJson(Map<String, dynamic> j) => MovieCard(
        title: (j['title'] as String?) ?? 'Untitled',
        year: (j['year'] as String?) ?? '',
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        posterUrl: j['posterUrl'] as String?,
        overview: (j['overview'] as String?) ?? '',
      );
}

/// A place result card returned by the creature's tool-use (Foursquare).
@immutable
class PlaceCard {
  const PlaceCard({
    required this.name,
    required this.category,
    required this.address,
    required this.distance,
    required this.rating,
    required this.photoUrl,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String category;
  final String address;
  final int? distance; // metres
  final double? rating; // 0–10
  final String? photoUrl;
  final double? lat;
  final double? lng;

  factory PlaceCard.fromJson(Map<String, dynamic> j) => PlaceCard(
        name: (j['name'] as String?) ?? 'Somewhere',
        category: (j['category'] as String?) ?? '',
        address: (j['address'] as String?) ?? '',
        distance: (j['distance'] as num?)?.toInt(),
        rating: (j['rating'] as num?)?.toDouble(),
        photoUrl: j['photoUrl'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );
}

/// Usora's neutral AI response — what the app sees regardless of provider. When
/// the creature used a tool, [movies] / [places] carry result cards.
/// [needsLocation] means a place search was requested without coordinates.
@immutable
class AiResponse {
  const AiResponse({
    required this.text,
    required this.provider,
    required this.model,
    this.movies = const [],
    this.places = const [],
    this.needsLocation = false,
  });

  final String text;
  final String provider;
  final String model;
  final List<MovieCard> movies;
  final List<PlaceCard> places;
  final bool needsLocation;

  factory AiResponse.fromJson(Map<String, dynamic> json) {
    final meta = (json['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final movies = switch (json['movies']) {
      final List<dynamic> l =>
        l.map((m) => MovieCard.fromJson((m as Map).cast<String, dynamic>())).toList(),
      _ => <MovieCard>[],
    };
    final places = switch (json['places']) {
      final List<dynamic> l =>
        l.map((p) => PlaceCard.fromJson((p as Map).cast<String, dynamic>())).toList(),
      _ => <PlaceCard>[],
    };
    return AiResponse(
      text: (json['text'] as String?) ?? '',
      provider: (meta['provider'] as String?) ?? 'unknown',
      model: (meta['model'] as String?) ?? 'unknown',
      movies: movies,
      places: places,
      needsLocation: json['needsLocation'] == true,
    );
  }
}
