import 'dart:math';

import '../../lexaway_game.dart';
import 'creature_behavior_component.dart';

/// Floats the creature at a fixed altitude with a sinusoidal bob (y) and
/// optional horizontal sway + constant drift (x). Runs in [onLoad] (awaited
/// by [Creature.onLoad]) so `position.y` is correct on the first frame.
class FlightBehavior extends CreatureBehaviorComponent {
  final double minAltitude;
  final double maxAltitude;
  final double bobAmplitude;
  final double bobFrequency;
  final double driftSpeed;
  final double swayAmplitude;
  final double swayFrequency;

  double _baseY = 0;
  double _bobT = 0;
  double _swayT = 0;
  double _lastSwayOffset = 0;

  FlightBehavior({
    required this.minAltitude,
    required this.maxAltitude,
    required this.bobAmplitude,
    required this.bobFrequency,
    required this.driftSpeed,
    required this.swayAmplitude,
    required this.swayFrequency,
  });

  @override
  Future<void> onLoad() async {
    final groundTop = parent.game.size.y * LexawayGame.groundLevel;
    final altitude =
        minAltitude + parent.rng.nextDouble() * (maxAltitude - minAltitude);
    _baseY = groundTop - parent.size.y - altitude;
    _bobT = parent.rng.nextDouble() * 2 * pi;
    _swayT = parent.rng.nextDouble() * 2 * pi;
    _lastSwayOffset = sin(_swayT) * swayAmplitude;
    parent.position.y = _baseY + sin(_bobT) * bobAmplitude;
    if (driftSpeed < 0) parent.setFlip(true);
  }

  @override
  void update(double dt) {
    _bobT += dt * bobFrequency;
    _swayT += dt * swayFrequency;
    parent.position.y = _baseY + sin(_bobT) * bobAmplitude;

    final swayOffset = sin(_swayT) * swayAmplitude;
    final swayDelta = swayOffset - _lastSwayOffset;
    _lastSwayOffset = swayOffset;
    parent.moveWorldX(driftSpeed * dt + swayDelta);
  }
}
