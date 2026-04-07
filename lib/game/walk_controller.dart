import 'package:flame/components.dart';

import 'audio_manager.dart';
import 'components/speech_messages.dart' show SpeechMessages;
import 'lexaway_game.dart';

/// Manages the walk state machine: animation, scrolling,
/// parallax, footstep audio, step counting, and idle chatter.
///
/// Walks now stack — answering while already walking extends the
/// journey instead of being ignored.
class WalkController extends Component with HasGameReference<LexawayGame> {
  double _walkRemaining = 0;
  bool _isWalking = false;
  double _stepTimer = 0;
  double _idleTimer = 0;

  static const double _stepInterval = 0.3;
  static const double _idleTimeout = 60.0;

  bool get isWalking => _isWalking;

  Function(int steps)? onStepTaken;

  void correctAnswer({required int streak, required String answer}) {
    _walkRemaining += LexawayGame.walkTarget;
    _idleTimer = 0;

    if (!_isWalking) {
      _isWalking = true;
      _stepTimer = _stepInterval; // first step fires immediately
      game.player.walk();
      game.parallaxComponent.parallax!.baseVelocity =
          Vector2(LexawayGame.walkSpeed * 0.1, 0);
      game.ground.startScrolling(LexawayGame.walkSpeed);
    }

    if (streak == 5 || streak == 10 || streak == 25) {
      AudioManager.instance.playStreak();
    } else {
      AudioManager.instance.playCorrect();
    }

    final msg = SpeechMessages.pickCorrectMessage(
      streak,
      answer,
      locale: game.locale,
    );
    if (msg != null) game.speechBubble.show(msg);
  }

  void wrongAnswer() {
    _idleTimer = 0;
    AudioManager.instance.playWrong();
    final msg = SpeechMessages.pickWrongMessage(locale: game.locale);
    if (msg != null) game.speechBubble.show(msg);
  }

  @override
  void update(double dt) {
    if (_isWalking) {
      _walkRemaining -= LexawayGame.walkSpeed * dt;
      _stepTimer += dt;
      if (_stepTimer >= _stepInterval) {
        _stepTimer -= _stepInterval;
        AudioManager.instance.playFootstep();
        onStepTaken?.call(1);
      }
      if (_walkRemaining <= 0) {
        _walkRemaining = 0;
        _stop();
      }
    }

    // Idle chatter (clamp dt to prevent spam after backgrounding)
    _idleTimer += dt.clamp(0, 1);
    if (_idleTimer >= _idleTimeout) {
      _idleTimer = 0;
      game.speechBubble.show(
        SpeechMessages.pickIdleMessage(locale: game.locale),
      );
    }
  }

  /// Finish any in-progress walk immediately (no animation).
  void finishWalk() {
    if (!_isWalking) return;
    game.ground.scrollOffset += _walkRemaining;
    // Count the steps we're skipping
    final skippedSteps =
        (_walkRemaining / (LexawayGame.walkSpeed * _stepInterval)).ceil();
    if (skippedSteps > 0) onStepTaken?.call(skippedSteps);
    _walkRemaining = 0;
    _stop();
  }

  void _stop() {
    _isWalking = false;
    _stepTimer = 0;
    game.player.idle();
    game.parallaxComponent.parallax!.baseVelocity = Vector2.zero();
    game.ground.stopScrolling();
    game.saveWorldState();
  }
}
