import 'dart:ui';

import '../audio_manager.dart';
import '../components/behaviors/behavior_config.dart';
import '../lexaway_game.dart';
import 'biome_definition.dart';
import 'world_map.dart';

class BiomeRegistry {
  static const _grassland = BiomeDefinition(
    type: BiomeType.grassland,
    terrainAsset: 'terrain/grassland.png',
    entitySheet: 'entities/grassland.png',
    entityManifest: 'assets/images/entities/grassland.json',
    parallaxLayers: [
      'parallax/sky.png',
      'parallax/clouds_far.png',
      'parallax/clouds_near.png',
      'parallax/hills.png',
      'parallax/foreground.png',
    ],
    footstepTerrain: Terrain.grass,
    entityLayers: [
      // Bushes — everywhere, the bread and butter of grassland foliage.
      SpawnLayer(
        entityName: 'bush',
        noiseScale: 0.04,
        threshold: 0.2,
        minGapTiles: 5,
        maxGapTiles: 14,
        noiseSeedOffset: 0,
      ),
      // Mushrooms — frequent little accents, tight patchy clusters.
      SpawnLayer(
        entityName: 'mushroom',
        noiseScale: 0.06,
        threshold: 0.25,
        minGapTiles: 6,
        maxGapTiles: 16,
        noiseSeedOffset: 50,
      ),
      // Round trees — clumpy groves with broad noise.
      SpawnLayer(
        entityName: 'round_tree',
        noiseScale: 0.02,
        threshold: 0.25,
        minGapTiles: 7,
        maxGapTiles: 20,
        noiseSeedOffset: 100,
      ),
      // Pine trees — similar to round trees but offset noise = different groves.
      SpawnLayer(
        entityName: 'pine_tree',
        noiseScale: 0.02,
        threshold: 0.25,
        minGapTiles: 7,
        maxGapTiles: 20,
        noiseSeedOffset: 150,
      ),
      // Flower trees — less rare now, nice scattered blooms.
      SpawnLayer(
        entityName: 'flower_tree',
        noiseScale: 0.03,
        threshold: 0.35,
        minGapTiles: 8,
        maxGapTiles: 24,
        noiseSeedOffset: 200,
      ),
      // Fences — sparse, isolated stretches.
      SpawnLayer(
        entityName: 'fence',
        noiseScale: 0.015,
        threshold: 0.55,
        minGapTiles: 18,
        maxGapTiles: 40,
        noiseSeedOffset: 250,
      ),
      // Flower fences — rare pops of color.
      SpawnLayer(
        entityName: 'flower_fence',
        noiseScale: 0.02,
        threshold: 0.6,
        minGapTiles: 20,
        maxGapTiles: 45,
        noiseSeedOffset: 300,
      ),
    ],
    minCoinGapTiles: 5,
    maxCoinGapTiles: 10,
    diamondChance: 0.15, // 15% diamond, 25% cluster, 60% single coin
    clusterChance: 0.25,
    creatureWeights: [
      WeightedEntity('minibunny', 2),
      WeightedEntity('butterfly', 3),
    ],
    minCreatureGapTiles: 40,
    maxCreatureGapTiles: 80,
    creatureDefs: {
      'minibunny': CreatureSpriteDef(
        sheetPath: 'creatures/minibunny.png',
        frameWidth: 32,
        frameHeight: 32,
        scale: LexawayGame.pixelScale,
        animConfig: CreatureAnimConfig(),
        behaviors: [
          GroundAnchorConfig(),
          FleeConfig(),
          IdleHopConfig(),
        ],
      ),
      'butterfly': CreatureSpriteDef(
        sheetPath: 'creatures/butterfly.png',
        frameWidth: 52,
        frameHeight: 52,
        scale: LexawayGame.pixelScale * 0.20,
        sourceDownsample: 4,
        animConfig: CreatureAnimConfig(
          idleFrames: 8,
          idleStepTime: 0.07,
          hopRow: 0,
          hopFrames: 1,
          hitRow: 0,
          hitFrames: 1,
          deathRow: 0,
          deathFrames: 1,
        ),
        behaviors: [
          FlightConfig(
            minAltitude: 40,
            maxAltitude: 240,
            bobAmplitude: 10,
            bobFrequency: 1.4,
            driftSpeed: -25,
            swayAmplitude: 14,
            swayFrequency: 2.2,
          ),
        ],
        tintPalette: [
          Color(0xFFFF7A3D), // monarch orange
          Color(0xFF5DA9FF), // morpho blue
          Color(0xFFFF8FD1), // pink
          Color(0xFFBDF26B), // lime
          Color(0xFFC79BFF), // lavender
          Color(0xFFFFE45E), // sulphur yellow
        ],
      ),
    },
  );

  static const _tropics = BiomeDefinition(
    type: BiomeType.tropics,
    terrainAsset: 'terrain/tropics.png',
    entitySheet: 'entities/tropics.png',
    entityManifest: 'assets/images/entities/tropics.json',
    parallaxLayers: [
      'parallax/sky.png',
      'parallax/tropics_clouds_far.png',
      'parallax/tropics_clouds_near.png',
      'parallax/tropics_water.png',
    ],
    footstepTerrain: Terrain.dirt,
    entityLayers: [
      // Palm trees — dominant, dense groves rolling across the coast.
      SpawnLayer(
        entityName: 'palm_tree',
        noiseScale: 0.025,
        threshold: 0.2,
        minGapTiles: 5,
        maxGapTiles: 16,
        noiseSeedOffset: 0,
      ),
      // Wooden fences — medium frequency, independent rhythm.
      SpawnLayer(
        entityName: 'wooden_fence',
        noiseScale: 0.04,
        threshold: 0.35,
        minGapTiles: 12,
        maxGapTiles: 28,
        noiseSeedOffset: 100,
      ),
      // Rocks — scattered boulders, fairly sparse.
      SpawnLayer(
        entityName: 'rock',
        noiseScale: 0.05,
        threshold: 0.35,
        minGapTiles: 12,
        maxGapTiles: 28,
        noiseSeedOffset: 200,
      ),
    ],
    minCoinGapTiles: 5,
    maxCoinGapTiles: 10,
    diamondChance: 0.15,
    clusterChance: 0.25,
  );

  static BiomeDefinition get(BiomeType type) {
    switch (type) {
      case BiomeType.grassland:
        return _grassland;
      case BiomeType.tropics:
        return _tropics;
    }
  }
}
