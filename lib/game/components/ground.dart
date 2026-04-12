import 'dart:ui';

import 'package:flame/components.dart';
import '../lexaway_game.dart';
import '../world/biome_registry.dart';
import '../world/world_map.dart';

class _TerrainSprites {
  final Sprite surface;
  final Sprite fill;

  _TerrainSprites({required this.surface, required this.fill});
}

class Ground extends Component with HasGameReference<LexawayGame> {
  final WorldMap worldMap;

  double scrollOffset = 0;
  double _scrollSpeed = 0;

  Ground({required this.worldMap});

  final Map<BiomeType, _TerrainSprites> _sprites = {};
  late Paint _pixelPaint;

  @override
  Future<void> onLoad() async {
    _pixelPaint = Paint()..filterQuality = FilterQuality.none;

    final biomes = worldMap.segments.map((s) => s.biome).toSet();
    for (final biome in biomes) {
      await _loadBiomeSprites(biome);
    }
  }

  Future<void> _loadBiomeSprites(BiomeType biome) async {
    if (_sprites.containsKey(biome)) return;
    final def = BiomeRegistry.get(biome);
    final image = await game.images.load(def.terrainAsset);

    _sprites[biome] = _TerrainSprites(
      surface: Sprite(
        image,
        srcPosition: Vector2(def.surfaceSrcPosition[0], def.surfaceSrcPosition[1]),
        srcSize: Vector2.all(16),
      ),
      fill: Sprite(
        image,
        srcPosition: Vector2(def.fillSrcPosition[0], def.fillSrcPosition[1]),
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
      final biome = worldMap.biomeAt(worldX);
      final terrain = _sprites[biome] ?? _sprites.values.first;

      terrain.surface.render(
        canvas,
        position: Vector2(x, groundTop),
        size: Vector2.all(tileSize),
        overridePaint: _pixelPaint,
      );

      var y = groundTop + tileSize;
      while (y < game.size.y) {
        terrain.fill.render(
          canvas,
          position: Vector2(x, y),
          size: Vector2.all(tileSize),
          overridePaint: _pixelPaint,
        );
        y += tileSize;
      }
    }
  }
}
