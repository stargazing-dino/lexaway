import 'package:intl/intl.dart';

/// Formats a step count as a human-readable distance, treating one step as
/// one in-game meter. Below 1km we show whole metres ("742 m"); at or above
/// 1km we show one decimal ("1.2 km") with a locale-aware decimal separator
/// and grouping. The dino isn't really walking 1m per step, but the metaphor
/// turns an opaque integer into something that feels like a journey.
String formatWalkedDistance(int steps, {String? locale}) {
  if (steps < 1000) {
    return '${NumberFormat.decimalPattern(locale).format(steps)} m';
  }
  final km = steps / 1000;
  return '${NumberFormat('#,##0.0', locale).format(km)} km';
}
