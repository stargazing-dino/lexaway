import 'dart:math';

import '../creature.dart';
import 'creature_behavior_component.dart';

/// Plays occasional one-shot hop animations while the creature is idle.
class IdleHopBehavior extends CreatureBehaviorComponent {
  final double minInterval;
  final double maxInterval;

  late final Random _rng;
  double _nextHopIn = 0;
  bool _playingHop = false;

  IdleHopBehavior({required this.minInterval, required this.maxInterval});

  @override
  void onMount() {
    super.onMount();
    _rng = Random(parent.rng.nextInt(1 << 32));
    _nextHopIn = _rollInterval();
  }

  double _rollInterval() {
    return minInterval + _rng.nextDouble() * (maxInterval - minInterval);
  }

  @override
  void update(double dt) {
    if (parent.isExcited || _playingHop) return;

    _nextHopIn -= dt;
    if (_nextHopIn > 0) return;

    _playingHop = true;
    parent.playAnim(CreatureAnim.hop, onComplete: () {
      _playingHop = false;
      parent.playAnim(CreatureAnim.idle);
      _nextHopIn = _rollInterval();
    });
  }
}
