import 'lexaway_game.dart';

/// Bundles the walk state machine's fields together so [MovementController]
/// isn't juggling a half-dozen loose doubles and bools. Also owns the
/// run-speed multiplier constant — lives here (instead of on
/// `MovementController`) to keep the dependency direction one-way.
class WalkState {
  static const double runSpeedMultiplier = 1.8;

  double remaining = 0;
  bool walking = false;
  bool running = false;
  double stepTimer = 0;

  double get currentSpeed => running
      ? LexawayGame.walkSpeed * runSpeedMultiplier
      : LexawayGame.walkSpeed;
}
