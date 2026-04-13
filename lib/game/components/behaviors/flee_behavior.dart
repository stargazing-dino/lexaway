import '../creature.dart';
import '../../lexaway_game.dart';
import 'creature_behavior_component.dart';

/// Flees leftward when the player gets within [triggerTiles] tiles.
class FleeBehavior extends CreatureBehaviorComponent {
  final double speed;
  final double triggerTiles;

  late final double _triggerPx;
  bool _activated = false;

  @override
  bool get isExclusive => _activated;

  FleeBehavior({required this.speed, required this.triggerTiles});

  @override
  void onMount() {
    super.onMount();
    _triggerPx = triggerTiles * 16 * LexawayGame.pixelScale;
  }

  @override
  void update(double dt) {
    if (_activated) {
      parent.moveWorldX(-speed * dt);
      return;
    }

    final game = parent.game;
    final scrollOffset = game.ground.scrollOffset;
    final playerScreenX = game.size.x * 0.25;
    final myScreenX = parent.worldX - scrollOffset;
    final gap = myScreenX - playerScreenX;

    if (gap > 0 && gap < _triggerPx) {
      _activate();
    }
  }

  void _activate() {
    _activated = true;
    // flipHorizontally negates scale.x, which shifts rendering by the sprite
    // width. Compensate so the creature doesn't visually teleport.
    parent.moveWorldX(parent.size.x);
    parent.setFlip(true);
    _loopHop();
  }

  void _loopHop() {
    parent.playAnim(CreatureAnim.hop, onComplete: () {
      if (_activated && parent.isMounted) _loopHop();
    });
  }
}
