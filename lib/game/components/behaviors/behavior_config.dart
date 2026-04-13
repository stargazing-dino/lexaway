import 'creature_behavior_component.dart';
import 'flee_behavior.dart';
import 'idle_hop_behavior.dart';

/// Const-constructible config that produces a [CreatureBehaviorComponent].
/// Lives on [CreatureSpriteDef] so biome registry entries stay fully const.
abstract class BehaviorConfig {
  const BehaviorConfig();
  CreatureBehaviorComponent create();
}

/// Config for [IdleHopBehavior].
class IdleHopConfig extends BehaviorConfig {
  final double minInterval;
  final double maxInterval;

  const IdleHopConfig({
    this.minInterval = 4.0,
    this.maxInterval = 9.0,
  });

  @override
  IdleHopBehavior create() =>
      IdleHopBehavior(minInterval: minInterval, maxInterval: maxInterval);
}

/// Config for [FleeBehavior].
class FleeConfig extends BehaviorConfig {
  final double speed;
  final double triggerTiles;

  const FleeConfig({
    this.speed = 260.0,
    this.triggerTiles = 2.0,
  });

  @override
  FleeBehavior create() => FleeBehavior(speed: speed, triggerTiles: triggerTiles);
}
