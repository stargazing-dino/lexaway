import '../../lexaway_game.dart';
import 'creature_behavior_component.dart';

/// Pins the creature's feet to the ground line. Runs in [onLoad] (awaited
/// by [Creature.onLoad]) so `position.y` is correct on the first frame.
class GroundAnchorBehavior extends CreatureBehaviorComponent {
  @override
  Future<void> onLoad() async {
    final groundTop = parent.game.size.y * LexawayGame.groundLevel;
    parent.position.y = groundTop - parent.size.y;
  }
}
