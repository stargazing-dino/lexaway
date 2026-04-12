import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import '../lexaway_game.dart';
import '../world/biome_registry.dart';
import '../world/world_map.dart';

class _TerrainSprites {
  final Sprite surface;
  final Sprite fill;
  final Sprite surfaceLeft;
  final Sprite surfaceRight;
  final Sprite fillLeft;
  final Sprite fillRight;

  _TerrainSprites({
    required this.surface,
    required this.fill,
    required this.surfaceLeft,
    required this.surfaceRight,
    required this.fillLeft,
    required this.fillRight,
  });
}

class _PierSprites {
  final Sprite leftCap;
  final Sprite centerA;
  final Sprite centerB;
  final Sprite centerC;
  final Sprite rightCap;
  final Sprite oceanSurface; // 16×6 wave detail at waterline
  final Sprite oceanFill; // 16×16 solid water for deep fill

  _PierSprites({
    required this.leftCap,
    required this.centerA,
    required this.centerB,
    required this.centerC,
    required this.rightCap,
    required this.oceanSurface,
    required this.oceanFill,
  });

  Sprite centerAt(int localTile) {
    switch (localTile % 3) {
      case 0:
        return centerA;
      case 1:
        return centerB;
      default:
        return centerC;
    }
  }
}

class Ground extends Component with HasGameReference<LexawayGame> {
  final WorldMap worldMap;

  final ValueNotifier<double> scrollNotifier = ValueNotifier(0.0);
  double get scrollOffset => scrollNotifier.value;
  set scrollOffset(double v) => scrollNotifier.value = v;

  double _scrollSpeed = 0;

  Ground({required this.worldMap});

  final Map<BiomeType, _TerrainSprites> _sprites = {};
  _PierSprites? _pierSprites;
  late Paint _pixelPaint;
  late Paint _waterPaint;
  late Paint _oceanBasePaint;

  @override
  Future<void> onLoad() async {
    _pixelPaint = Paint()..filterQuality = FilterQuality.none;
    _waterPaint = Paint()
      ..filterQuality = FilterQuality.none
      ..color = const Color.fromARGB(140, 255, 255, 255);
    _oceanBasePaint = Paint()
      ..color = const Color.fromARGB(255, 0, 133, 248);

    final biomes = worldMap.segments.map((s) => s.biome).toSet();
    for (final biome in biomes) {
      await _loadBiomeSprites(biome);
    }
  }

  Future<void> _loadBiomeSprites(BiomeType biome) async {
    if (_sprites.containsKey(biome)) return;
    final def = BiomeRegistry.get(biome);
    final image = await game.images.load(def.terrainAsset);

    final sx = def.surfaceSrcPosition[0];
    final sy = def.surfaceSrcPosition[1];
    Sprite tile(double x, double y) =>
        Sprite(image, srcPosition: Vector2(x, y), srcSize: Vector2.all(16));

    _sprites[biome] = _TerrainSprites(
      surface: tile(sx, sy),
      fill: tile(def.fillSrcPosition[0], def.fillSrcPosition[1]),
      surfaceLeft: tile(sx - 16, sy),
      surfaceRight: tile(sx + 16, sy),
      fillLeft: tile(sx - 16, sy + 16),
      fillRight: tile(sx + 16, sy + 16),
    );

    if (biome == BiomeType.tropics && _pierSprites == null) {
      await _loadPierSprites();
    }
  }

  Future<void> _loadPierSprites() async {
    final image = await game.images.load('entities/tropics.png');
    Sprite col(double srcX, double srcY) => Sprite(
          image,
          srcPosition: Vector2(srcX, srcY),
          srcSize: Vector2(16, 32),
        );
    _pierSprites = _PierSprites(
      // Caps are shifted 3px inward to remove built-in padding from the
      // original entity sprite — puts the post flush with the ground edge.
      leftCap: col(179, 32),
      centerA: col(192, 32),
      centerB: col(208, 32),
      centerC: col(224, 32),
      rightCap: col(237, 32),
      // Ocean surface: just the 6px wave rows, rendered at the waterline.
      oceanSurface: Sprite(
        image,
        srcPosition: Vector2(192, 90),
        srcSize: Vector2(16, 6),
      ),
      // Ocean fill: solid blue for deep water.
      oceanFill: Sprite(
        image,
        srcPosition: Vector2(192, 96),
        srcSize: Vector2.all(16),
      ),
    );
  }

  Future<void> ensureBiomeLoaded(BiomeType biome) => _loadBiomeSprites(biome);

  void startScrolling(double speed) => _scrollSpeed = speed;
  void stopScrolling() => _scrollSpeed = 0;

  @override
  void update(double dt) {
    scrollOffset += _scrollSpeed * dt;
  }

  @override
  void render(Canvas canvas) {
    final tileSize = 16.0 * LexawayGame.pixelScale;
    final groundTop = game.size.y * LexawayGame.groundLevel;
    final tilesAcross = (game.size.x / tileSize).ceil() + 2;
    final pixelOffset = scrollOffset % tileSize;

    for (int i = 0; i < tilesAcross; i++) {
      final x = i * tileSize - pixelOffset;
      final worldX = scrollOffset + x;
      final tileX = (worldX / tileSize).floor();
      final pierZone = worldMap.pierZoneAt(tileX);

      if (pierZone != null && _pierSprites != null) {
        _renderPierColumn(canvas, x, groundTop, tileSize, tileX, pierZone);
      } else {
        _renderTerrainColumn(canvas, x, groundTop, tileSize, worldX, tileX);
      }
    }
  }

  void _renderTerrainColumn(
    Canvas canvas,
    double x,
    double groundTop,
    double tileSize,
    double worldX,
    int tileX,
  ) {
    final biome = worldMap.biomeAt(worldX);
    final terrain = _sprites[biome] ?? _sprites.values.first;

    // Check if we're on the edge next to a pier.
    final pierRight = worldMap.pierZoneAt(tileX + 1);
    final pierLeft = worldMap.pierZoneAt(tileX - 1);

    final Sprite surfaceSprite;
    final Sprite fillSprite;
    if (pierRight != null && tileX + 1 == pierRight.startTile) {
      surfaceSprite = terrain.surfaceRight;
      fillSprite = terrain.fillRight;
    } else if (pierLeft != null && tileX - 1 == pierLeft.endTile - 1) {
      surfaceSprite = terrain.surfaceLeft;
      fillSprite = terrain.fillLeft;
    } else {
      surfaceSprite = terrain.surface;
      fillSprite = terrain.fill;
    }

    surfaceSprite.render(
      canvas,
      position: Vector2(x, groundTop),
      size: Vector2.all(tileSize),
      overridePaint: _pixelPaint,
    );

    var y = groundTop + tileSize;
    while (y < game.size.y) {
      fillSprite.render(
        canvas,
        position: Vector2(x, y),
        size: Vector2.all(tileSize),
        overridePaint: _pixelPaint,
      );
      y += tileSize;
    }
  }

  void _renderPierColumn(
    Canvas canvas,
    double x,
    double groundTop,
    double tileSize,
    int tileX,
    PierZone zone,
  ) {
    final pier = _pierSprites!;
    final localTile = tileX - zone.startTile;
    final tileHeight = tileSize * 2;

    // Pick the right pier column sprite.
    final Sprite pierSprite;
    if (localTile == 0) {
      pierSprite = pier.leftCap;
    } else if (localTile == zone.widthTiles - 1) {
      pierSprite = pier.rightCap;
    } else {
      pierSprite = pier.centerAt(localTile - 1);
    }

    final waterTop = groundTop + tileSize * 0.6;
    final waveHeight = 6.0 * LexawayGame.pixelScale;

    // 0) Solid ocean-color rect behind everything — extends the parallax
    //    water layer's bottom edge color to the screen bottom.
    canvas.drawRect(
      Rect.fromLTRB(x, groundTop, x + tileSize, game.size.y),
      _oceanBasePaint,
    );

    // 1) Pier structure (deck + legs).
    pierSprite.render(
      canvas,
      position: Vector2(x, groundTop),
      size: Vector2(tileSize, tileHeight),
      overridePaint: _pixelPaint,
    );

    // 2) Semi-transparent wave surface at waterline.
    pier.oceanSurface.render(
      canvas,
      position: Vector2(x, waterTop),
      size: Vector2(tileSize, waveHeight),
      overridePaint: _waterPaint,
    );

    // 3) Semi-transparent ocean fill (bottom 16×16 of the ocean tile)
    //    repeated from below the waves to screen bottom — legs show through.
    var y = waterTop + waveHeight;
    while (y < game.size.y) {
      pier.oceanFill.render(
        canvas,
        position: Vector2(x, y),
        size: Vector2.all(tileSize),
        overridePaint: _waterPaint,
      );
      y += tileSize;
    }
  }
}
