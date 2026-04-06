import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';

import 'audio_manager.dart';
import 'components/coin_manager.dart';
import 'components/ground.dart';
import 'components/player.dart';
import 'components/speech_bubble.dart';
import 'components/speech_messages.dart';

class LexawayGame extends FlameGame {
  static const double pixelScale = 4.0;
  static const double groundLevel = 0.45;

  late Player player;
  late Ground ground;
  late ParallaxComponent parallaxComponent;
  late SpeechBubble speechBubble;
  late CoinManager coinManager;

  Function(int value)? onCoinCollected;

  bool _isWalking = false;
  double _walkProgress = 0;
  double _idleTimer = 0;
  static const double _idleTimeout = 60.0;
  double _stepTimer = 0;
  static const double _stepInterval = 0.3;

  // One tile at 4x scale = 64px. Walk it in ~0.8s.
  static const double walkSpeed = 80;
  static const double walkTarget = 16 * pixelScale;

  @override
  Color backgroundColor() => const Color(0xFF50BBFF); // Match sky color

  @override
  Future<void> onLoad() async {
    final parallaxHeight = size.y * groundLevel + 16 * pixelScale;
    parallaxComponent = await loadParallaxComponent(
      [
        ParallaxImageData('parallax/sky.png'),
        ParallaxImageData('parallax/clouds_far.png'),
        ParallaxImageData('parallax/clouds_near.png'),
        ParallaxImageData('parallax/hills.png'),
        ParallaxImageData('parallax/foreground.png'),
      ],
      baseVelocity: Vector2.zero(),
      velocityMultiplierDelta: Vector2(1.4, 0),
      fill: LayerFill.height,
      filterQuality: FilterQuality.none,
      size: Vector2(size.x, parallaxHeight),
    );
    add(parallaxComponent);

    ground = Ground()..priority = 1;
    add(ground);

    coinManager = CoinManager()
      ..priority = 1
      ..onCoinCollected = (value) => onCoinCollected?.call(value);
    add(coinManager);

    player = Player()..priority = 2;
    add(player);

    speechBubble = SpeechBubble()..priority = 3;
    add(speechBubble);

    await AudioManager.instance.preload();
  }

  void correctAnswer({required int streak, required String answer}) {
    if (_isWalking) return;
    _isWalking = true;
    _walkProgress = 0;
    _idleTimer = 0;
    player.walk();
    parallaxComponent.parallax!.baseVelocity = Vector2(walkSpeed * 0.1, 0);
    ground.startScrolling(walkSpeed);

    if (streak == 5 || streak == 10 || streak == 25) {
      AudioManager.instance.playStreak();
    } else {
      AudioManager.instance.playCorrect();
    }
    _stepTimer = _stepInterval; // triggers first step immediately in update

    final msg = pickCorrectMessage(streak, answer);
    if (msg != null) speechBubble.show(msg);
  }

  void wrongAnswer() {
    _idleTimer = 0;
    AudioManager.instance.playWrong();
    final msg = pickWrongMessage();
    if (msg != null) speechBubble.show(msg);
  }

  void _stopWalking() {
    _isWalking = false;
    _stepTimer = 0;
    player.idle();
    parallaxComponent.parallax!.baseVelocity = Vector2.zero();
    ground.stopScrolling();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isWalking) {
      _walkProgress += walkSpeed * dt;
      _stepTimer += dt;
      if (_stepTimer >= _stepInterval) {
        _stepTimer -= _stepInterval;
        AudioManager.instance.playFootstep();
      }
      if (_walkProgress >= walkTarget) {
        _stopWalking();
      }
    }

    // Idle chatter (clamp dt to prevent spam after backgrounding)
    _idleTimer += dt.clamp(0, 1);
    if (_idleTimer >= _idleTimeout) {
      _idleTimer = 0;
      speechBubble.show(pickIdleMessage());
    }

    // Position bubble above the player, nudged right so the tail
    // sits under the dino's head.
    speechBubble.position = Vector2(
      player.position.x + player.size.x * 0.3,
      player.position.y - speechBubble.size.y - 4,
    );
  }

}
