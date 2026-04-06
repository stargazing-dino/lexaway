import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';

import 'audio_manager.dart';
import 'components/coin_manager.dart';
import 'components/ground.dart';
import 'components/player.dart';
import 'components/speech_bubble.dart';
import 'walk_controller.dart';

class LexawayGame extends FlameGame {
  static const double pixelScale = 4.0;
  static const double groundLevel = 0.45;

  // One tile at 4x scale = 64px. Walk it in ~0.8s.
  static const double walkSpeed = 80;
  static const double walkTarget = 16 * pixelScale;

  late Player player;
  late Ground ground;
  late ParallaxComponent parallaxComponent;
  late SpeechBubble speechBubble;
  late CoinManager coinManager;
  late WalkController walkController;

  Function(int value)? onCoinCollected;

  @override
  Color backgroundColor() => const Color(0xFF50BBFF);

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

    walkController = WalkController();
    add(walkController);

    await AudioManager.instance.preload();
  }

  void correctAnswer({required int streak, required String answer}) {
    walkController.correctAnswer(streak: streak, answer: answer);
  }

  void wrongAnswer() {
    walkController.wrongAnswer();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Position bubble above the player, nudged right so the tail
    // sits under the dino's head.
    speechBubble.position = Vector2(
      player.position.x + player.size.x * 0.3,
      player.position.y - speechBubble.size.y - 4,
    );
  }
}
