import 'dart:math';

/// Generates a cute adjective+noun couple name (editable later).
/// Kept tiny and dependency-free; the full curated list can grow in Layer 2.
class CoupleNameGenerator {
  const CoupleNameGenerator._();

  static const _adjectives = [
    'Honey', 'Cozy', 'Sunny', 'Velvet', 'Maple', 'Cosmic',
    'Peachy', 'Golden', 'Lucky', 'Mellow', 'Dreamy', 'Toasty',
  ];

  static const _nouns = [
    'Otters', 'Foxes', 'Sparrows', 'Pandas', 'Bears', 'Doves',
    'Koalas', 'Puffins', 'Hedgehogs', 'Bunnies', 'Penguins', 'Cubs',
  ];

  static String generate([Random? random]) {
    final r = random ?? Random();
    final adj = _adjectives[r.nextInt(_adjectives.length)];
    final noun = _nouns[r.nextInt(_nouns.length)];
    return '$adj $noun';
  }
}
