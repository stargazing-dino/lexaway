import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/lexaway_game.dart';
import '../game/world/world_map.dart';

/// Biome colors for the mini-map track.
/// Use a loud fallback so missing entries are obvious during development.
const _biomeColors = {
  BiomeType.grassland: Color(0xFF4a8c3f),
};
const _missingBiomeColor = Color(0xFFff00ff); // magenta = "you forgot one"

/// A pixel-art style mini-map painted inside the banner.
/// Shows a track of biome segments with a dino marker for current position.
class MiniMap extends StatelessWidget {
  final WorldMap worldMap;
  final double scrollOffset;

  const MiniMap({super.key, required this.worldMap, required this.scrollOffset});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniMapPainter(
        worldMap: worldMap,
        scrollOffset: scrollOffset,
      ),
      size: const Size(double.infinity, 12),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  final WorldMap worldMap;
  final double scrollOffset;

  _MiniMapPainter({required this.worldMap, required this.scrollOffset});

  @override
  void paint(Canvas canvas, Size size) {
    if (worldMap.segments.isEmpty) return;

    final totalPx = worldMap.totalLengthPx;
    if (totalPx <= 0) return;

    final trackHeight = 6.0;
    final trackY = (size.height - trackHeight) / 2;
    final trackRadius = Radius.circular(trackHeight / 2);

    // Dark track background
    final bgPaint = Paint()..color = const Color(0xFF1a1a2e);
    canvas.drawRRect(
      RRect.fromLTRBR(0, trackY, size.width, trackY + trackHeight, trackRadius),
      bgPaint,
    );

    // Biome-colored segments
    for (final seg in worldMap.segments) {
      final startFrac = seg.startPx / totalPx;
      final endFrac = seg.endPx / totalPx;
      final x1 = startFrac * size.width;
      final x2 = endFrac * size.width;

      final color = _biomeColors[seg.biome] ?? _missingBiomeColor;
      final segPaint = Paint()..color = color;

      canvas.drawRRect(
        RRect.fromLTRBR(
          x1, trackY, x2, trackY + trackHeight, trackRadius,
        ),
        segPaint,
      );
    }

    // Player progress marker
    final progress = (scrollOffset / totalPx).clamp(0.0, 1.0);
    final markerX = progress * size.width;
    final markerSize = 8.0;

    // Diamond shape for the marker
    final markerPath = Path()
      ..moveTo(markerX, trackY - 1)
      ..lineTo(markerX + markerSize / 2, trackY + trackHeight / 2)
      ..lineTo(markerX, trackY + trackHeight + 1)
      ..lineTo(markerX - markerSize / 2, trackY + trackHeight / 2)
      ..close();

    // Marker shadow
    final shadowPaint = Paint()..color = const Color(0x40000000);
    canvas.drawPath(markerPath.shift(const Offset(0, 1)), shadowPaint);

    // Marker fill
    final markerPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(markerX, trackY - 1),
        Offset(markerX, trackY + trackHeight + 1),
        [const Color(0xFFffd700), const Color(0xFFe6a800)],
      );
    canvas.drawPath(markerPath, markerPaint);

    // Marker outline
    final outlinePaint = Paint()
      ..color = const Color(0xFF8b6914)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(markerPath, outlinePaint);

    // Subtle distance markers along the track (every 500 tiles)
    final markerInterval = 500 * 16.0 * LexawayGame.pixelScale;
    final tickPaint = Paint()
      ..color = const Color(0x30ffffff)
      ..strokeWidth = 1;
    var tickX = markerInterval;
    while (tickX < totalPx) {
      final frac = tickX / totalPx;
      final sx = frac * size.width;
      canvas.drawLine(
        Offset(sx, trackY + 1),
        Offset(sx, trackY + trackHeight - 1),
        tickPaint,
      );
      tickX += markerInterval;
    }
  }

  @override
  bool shouldRepaint(_MiniMapPainter oldDelegate) =>
      oldDelegate.scrollOffset != scrollOffset ||
      oldDelegate.worldMap != worldMap;
}
