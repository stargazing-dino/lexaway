import 'dart:ui';

import 'package:flame/components.dart';
import '../lexaway_game.dart';
import '../world/scrolling_item_layer.dart';

/// A static scenery sprite (tree, bush, fence, etc.) that scrolls with the ground.
class Entity extends PositionComponent
    with HasGameReference<LexawayGame>, ScrollingWorldItem {
  final Sprite sprite;
  final Vector2 spriteSize;
  @override
  double worldX;

  /// Index into the WorldMap's item list, used for tracking active entities.
  @override
  final int itemIndex;

  /// Purely visual horizontal mirror. Sprite must be gameplay-symmetric — if
  /// asymmetric anchors are ever added (e.g. collectible fruit on one side),
  /// flipping would silently desync them.
  final bool flipX;

  @override
  double get layerWidth => spriteSize.x;

  Entity({
    required this.sprite,
    required this.spriteSize,
    required this.worldX,
    this.itemIndex = -1,
    this.flipX = false,
  });

  static final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  @override
  void render(Canvas canvas) {
    if (flipX) {
      canvas.save();
      canvas.translate(spriteSize.x, 0);
      canvas.scale(-1, 1);
      sprite.render(canvas, size: spriteSize, overridePaint: _paint);
      canvas.restore();
    } else {
      sprite.render(canvas, size: spriteSize, overridePaint: _paint);
    }
  }
}
