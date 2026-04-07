import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';

import '../models/character.dart';

enum EggPhase { wobble, crack, hatch, reveal }

class EggPreviewGame extends FlameGame {
  final CharacterInfo character;
  VoidCallback? onAllPhasesComplete;

  EggPhase _phase = EggPhase.wobble;
  bool _disposed = false;

  static const double _frameSize = 24;
  static const double _scale = 4.0;

  EggPreviewGame({required this.character});

  EggPhase get phase => _phase;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await _showPhase(EggPhase.wobble);
  }

  @override
  void onRemove() {
    _disposed = true;
    super.onRemove();
  }

  /// Start the crack → hatch → reveal sequence.
  void startHatchSequence() {
    _showPhase(EggPhase.crack);
  }

  Future<void> _showPhase(EggPhase phase) async {
    _phase = phase;

    final assetPath = switch (phase) {
      EggPhase.wobble => character.eggMoveAsset,
      EggPhase.crack => character.eggCrackAsset,
      EggPhase.hatch => character.eggHatchAsset,
      EggPhase.reveal => character.idleAsset,
    };

    final image = await images.load(assetPath);
    if (_disposed) return;

    final frameCount = image.width ~/ _frameSize.toInt();
    final sheet = SpriteSheet(
      image: image,
      srcSize: Vector2.all(_frameSize),
    );

    final loop = phase == EggPhase.wobble || phase == EggPhase.reveal;
    final stepTime = phase == EggPhase.wobble ? 0.18 : 0.25;
    final animation = sheet.createAnimation(
      row: 0,
      from: 0,
      to: frameCount,
      stepTime: stepTime,
      loop: loop,
    );

    if (children.isNotEmpty) {
      removeAll(children);
    }

    final sprite = SpriteAnimationComponent(
      animation: animation,
      size: Vector2.all(_frameSize * _scale),
      position: Vector2(
        (size.x - _frameSize * _scale) / 2,
        (size.y - _frameSize * _scale) / 2,
      ),
      paint: Paint()..filterQuality = FilterQuality.none,
    );
    add(sprite);

    if (!loop) {
      final durationMs = (frameCount * stepTime * 1000).toInt();
      Future.delayed(Duration(milliseconds: durationMs), () {
        if (_disposed) return;
        _advance();
      });
    } else if (phase == EggPhase.reveal) {
      onAllPhasesComplete?.call();
    }
  }

  void _advance() {
    switch (_phase) {
      case EggPhase.crack:
        _showPhase(EggPhase.hatch);
      case EggPhase.hatch:
        _showPhase(EggPhase.reveal);
      case EggPhase.wobble:
      case EggPhase.reveal:
        break;
    }
  }
}
