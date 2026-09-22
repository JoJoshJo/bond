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

/// A place result card returned by the creature's tool-use (Google Places).
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

/// One side of a proposed calendar change (validated by the router; the app
/// re-validates on parse and never trusts it for the write — see
/// [CalendarProposal]).
@immutable
class ProposedEvent {
  const ProposedEvent({
    required this.title,
    required this.date,
    this.hour,
    this.minute,
    this.note,
    this.type = 'custom',
    this.recurring = false,
  });

  final String title;
  final DateTime date; // date-only, local
  final int? hour; // null = all-day
  final int? minute;
  final String? note;
  final String type;
  final bool recurring;

  bool get hasTime => hour != null && minute != null;

  static const _types = {
    'anniversary', 'date_night', 'milestone', 'reminder', 'custom'
  };

  /// Strict parse: null on anything malformed (bad date/time, empty title).
  static ProposedEvent? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    final title = (j['title'] as String?)?.trim() ?? '';
    final ymd = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$')
        .firstMatch((j['date'] as String?) ?? '');
    if (title.isEmpty || ymd == null) return null;
    final y = int.parse(ymd[1]!), mo = int.parse(ymd[2]!), d = int.parse(ymd[3]!);
    final date = DateTime(y, mo, d);
    if (date.year != y || date.month != mo || date.day != d) return null;
    int? hour, minute;
    final t = j['time'];
    if (t != null) {
      final hm = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(t as String? ?? '');
      if (hm == null) return null;
      hour = int.parse(hm[1]!);
      minute = int.parse(hm[2]!);
      if (hour > 23 || minute > 59) return null;
    }
    final type = j['type'] as String?;
    final note = (j['note'] as String?)?.trim();
    return ProposedEvent(
      title: title.length > 80 ? title.substring(0, 80) : title,
      date: date,
      hour: hour,
      minute: minute,
      note: (note == null || note.isEmpty) ? null : note,
      type: _types.contains(type) ? type! : 'custom',
      recurring: j['recurring'] == true,
    );
  }
}

enum CalendarOp { add, update, delete }

/// A calendar change Usora PROPOSED. Nothing is written until the couple taps
/// Yes; the app then writes through its normal calendar controller (same RLS).
@immutable
class CalendarProposal {
  const CalendarProposal(
      {required this.op, this.eventId, this.before, this.after});

  final CalendarOp op;
  final String? eventId; // update / delete
  final ProposedEvent? before; // update / delete (as the router saw it)
  final ProposedEvent? after; // add / update

  /// Null unless the payload is complete and well-formed for its op.
  static CalendarProposal? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    final op = switch (j['op']) {
      'add' => CalendarOp.add,
      'update' => CalendarOp.update,
      'delete' => CalendarOp.delete,
      _ => null,
    };
    if (op == null) return null;
    final id = j['eventId'] as String?;
    final before = ProposedEvent.tryParse(j['before']);
    final after = ProposedEvent.tryParse(j['after']);
    final valid = switch (op) {
      CalendarOp.add => after != null,
      CalendarOp.update => id != null && before != null && after != null,
      CalendarOp.delete => id != null && before != null,
    };
    if (!valid) return null;
    return CalendarProposal(op: op, eventId: id, before: before, after: after);
  }
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
    this.calendarAction,
    this.premiumRequired = false,
  });

  final String text;
  final String provider;
  final String model;
  final List<MovieCard> movies;
  final List<PlaceCard> places;
  final bool needsLocation;

  /// A proposed calendar change awaiting the couple's Yes (never auto-applied).
  final CalendarProposal? calendarAction;

  /// The router's server-side check says this needs Usora+ (nothing changed).
  final bool premiumRequired;

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
      calendarAction: CalendarProposal.tryParse(json['calendarAction']),
      premiumRequired: json['premiumRequired'] == true,
    );
  }
}
