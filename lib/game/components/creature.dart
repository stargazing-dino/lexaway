import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../lexaway_game.dart';
import '../world/biome_definition.dart';
import '../world/scrolling_item_layer.dart';
import 'behaviors/behavior_config.dart';
import 'behaviors/creature_behavior_component.dart';

enum CreatureAnim { idle, hop, hit, death }

/// An ambient animated critter that rides world scroll. Behavior is driven
/// entirely by composable child components (see `behaviors/`). This class
/// is just the visual shell: sprite sheet, animation playback, and a small
/// API that behaviors call into.
class Creature extends SpriteAnimationGroupComponent<CreatureAnim>
    with HasGameReference<LexawayGame>, ScrollingWorldItem {
  final String sheetPath;
  final double frameWidth;
  final double frameHeight;
  final double spriteScale;
  final CreatureAnimConfig animConfig;
  final List<BehaviorConfig> behaviorConfigs;

  @override
  double worldX;

  @override
  final int itemIndex;

  /// Per-creature RNG seeded from the unique world item index. Behaviors
  /// derive their own RNGs from this so each critter acts independently.
  final Random rng;


  Creature({
    required this.sheetPath,
    required this.frameWidth,
    required this.frameHeight,
    required this.spriteScale,
    required this.animConfig,
    required this.behaviorConfigs,
    required this.worldX,
    required this.itemIndex,
  }) : rng = Random(itemIndex);

  /// True when any child behavior has taken exclusive control (fleeing, etc.).
  bool get isExcited => children
      .whereType<CreatureBehaviorComponent>()
      .any((b) => b.isExclusive);

  @override
  double get layerWidth => size.x;

  @override
  Future<void> onLoad() async {
    final image = await game.images.load(sheetPath);
    final sheet = SpriteSheet(
      image: image,
      srcSize: Vector2(frameWidth, frameHeight),
    );

    animations = {
      CreatureAnim.idle: sheet.createAnimation(
        row: animConfig.idleRow,
        from: 0,
        to: animConfig.idleFrames,
        stepTime: animConfig.idleStepTime,
      ),
      CreatureAnim.hop: sheet.createAnimation(
        row: animConfig.hopRow,
        from: 0,
        to: animConfig.hopFrames,
        stepTime: animConfig.hopStepTime,
        loop: false,
      ),
      CreatureAnim.hit: sheet.createAnimation(
        row: animConfig.hitRow,
        from: 0,
        to: animConfig.hitFrames,
        stepTime: animConfig.hitStepTime,
        loop: false,
      ),
      CreatureAnim.death: sheet.createAnimation(
        row: animConfig.deathRow,
        from: 0,
        to: animConfig.deathFrames,
        stepTime: animConfig.deathStepTime,
        loop: false,
      ),
    };

    current = CreatureAnim.idle;
    size = Vector2(frameWidth, frameHeight) * spriteScale;

    final groundTop = game.size.y * LexawayGame.groundLevel;
    position.y = groundTop - size.y;

    paint = Paint()..filterQuality = FilterQuality.none;

    for (final config in behaviorConfigs) {
      add(config.create());
    }
  }

  // -- API for behaviors --

  void playAnim(CreatureAnim anim, {VoidCallback? onComplete}) {
    current = anim;
    animationTicker!
      ..reset()
      ..onComplete = onComplete;
  }

  void setFlip(bool facingLeft) {
    if (isFlippedHorizontally != facingLeft) flipHorizontally();
  }

  void moveWorldX(double delta) {
    worldX += delta;
  }

}
