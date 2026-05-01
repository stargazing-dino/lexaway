import '../../lexaway_game.dart';
import 'creature_behavior_component.dart';

/// Pins the creature's feet to the ground line. Runs in [onLoad] (awaited
/// by [Creature.onLoad]) so `position.y` is correct on the first frame.
///
/// [footPadding] is the number of transparent source pixels below the
/// creature's feet in its sprite frame. Multiplied by the parent's sprite
/// scale and subtracted so the visible feet sit on the ground instead of
/// hovering.
class GroundAnchorBehavior extends CreatureBehaviorComponent {
  final double footPadding;

  GroundAnchorBehavior({this.footPadding = 0});

  @override
  Future<void> onLoad() async {
    final groundTop = parent.game.size.y * LexawayGame.groundLevel;
    final padPx = footPadding * parent.spriteScale;
    parent.position.y = groundTop - parent.size.y + padPx;
  }
}
