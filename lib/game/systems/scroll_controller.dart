import 'dart:async';

import 'package:flame/components.dart';

import '../components/biome_parallax.dart';
import '../components/ground.dart';
import '../events.dart';
import '../lexaway_game.dart';
import '../walk_state.dart';
import '../world/world_map.dart';

/// Owns anything that scrolls: parallax velocity, ground scroll speed, and
/// gentle cloud drift. Subscribes to walk events and translates them into
/// parallax base-velocity + ground scroll speed changes.
///
/// Also detects biome boundaries and triggers parallax crossfades via
/// [BiomeParallax.transitionTo].
class ScrollController extends Component with HasGameReference<LexawayGame> {
  StreamSubscription<GameEvent>? _sub;

  late final BiomeParallax _biomeParallax;
  late final Ground _ground;
  late BiomeType _currentBiome;

  @override
  void onMount() {
    super.onMount();
    _biomeParallax = game.biomeParallax;
    _ground = game.ground;
    _currentBiome = game.worldMap.biomeAt(
      _ground.scrollOffset + game.size.x / 2,
    );
    _sub = game.events.on<GameEvent>().listen(_handle);
  }

  void _handle(GameEvent event) {
    switch (event) {
      case WalkStarted(:final running):
        _applySpeed(running: running);
      case WalkSpeedChanged(:final running):
        _applySpeed(running: running);
      case WalkStopped(:final skipDistance):
        if (skipDistance > 0) _ground.scrollOffset += skipDistance;
        _biomeParallax.setBaseVelocity(Vector2.zero());
        _ground.stopScrolling();
      default:
        break;
    }
  }

  void _applySpeed({required bool running}) {
    final speed = running
        ? LexawayGame.walkSpeed * WalkState.runSpeedMultiplier
        : LexawayGame.walkSpeed;
    _biomeParallax.setBaseVelocity(Vector2(speed * 0.1, 0));
    _ground.startScrolling(speed);
  }

  @override
  void update(double dt) {
    _biomeParallax.applyCloudDrift(dt);

    // Detect biome boundary crossings at screen centre.
    final biome = game.worldMap.biomeAt(
      _ground.scrollOffset + game.size.x / 2,
    );
    if (biome != _currentBiome) {
      final previous = _currentBiome;
      _currentBiome = biome;
      _biomeParallax.transitionTo(biome);
      game.events.emit(BiomeChanged(previous: previous, current: biome));
    }
  }

  @override
  void onRemove() {
    _sub?.cancel();
    super.onRemove();
  }
}
