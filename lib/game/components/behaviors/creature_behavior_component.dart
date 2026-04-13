import 'package:flame/components.dart';

import '../creature.dart';

/// Base class for composable creature behaviors. Each behavior is a child
/// component of [Creature] and can read/write parent state through Flame's
/// [ParentIsA] mixin.
abstract class CreatureBehaviorComponent extends Component
    with ParentIsA<Creature> {
  /// Whether this behavior has taken exclusive control of the creature
  /// (e.g. fleeing, charging). Other behaviors should yield when any
  /// sibling is exclusive, and the creature layer uses this to suppress
  /// respawning.
  bool get isExclusive => false;
}
