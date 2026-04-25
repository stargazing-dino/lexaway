import 'dart:math';

import 'package:flame_audio/flame_audio.dart';

enum Terrain { grass, dirt, snow }

class AudioManager {
  static final AudioManager _instance = AudioManager._();
  static AudioManager get instance => _instance;
  AudioManager._();

  final _rng = Random();

  double masterVolume = 1.0;
  double sfxVolume = 1.0;

  bool _ttsDucking = false;
  void setTtsDucking(bool ducking) => _ttsDucking = ducking;

  double get _feedbackVol =>
      (masterVolume * sfxVolume * (_ttsDucking ? 0.5 : 1.0)).clamp(0.0, 1.0);

  double get _footstepVol =>
      _ttsDucking ? 0.0 : (masterVolume * sfxVolume * 0.35).clamp(0.0, 1.0);

  Future<void> preload() async {
    await FlameAudio.audioCache.loadAll([
      'correct.wav',
      'wrong.wav',
      for (final t in Terrain.values)
        for (var i = 1; i <= 3; i++) 'step_${t.name}_$i.wav',
      'streak.wav',
      'coin.wav',
      'gem.wav',
      'crunch_crunchy.wav',
      'hatch_chime.wav',
    ]);
  }

  void playCorrect() => FlameAudio.play('correct.wav', volume: _feedbackVol);

  void playWrong() => FlameAudio.play('wrong.wav', volume: _feedbackVol);

  void playFootstep({Terrain terrain = Terrain.grass}) {
    final vol = _footstepVol;
    if (vol <= 0.0) return;
    final n = _rng.nextInt(3) + 1;
    FlameAudio.play('step_${terrain.name}_$n.wav', volume: vol);
  }

  void playStreak() => FlameAudio.play('streak.wav', volume: _feedbackVol);

  void playCoin() => FlameAudio.play('coin.wav', volume: _feedbackVol);

  void playGem() => FlameAudio.play('gem.wav', volume: _feedbackVol);

  void playEggCrack() =>
      FlameAudio.play('crunch_crunchy.wav', volume: _feedbackVol * 0.4);

  void playHatchChime() =>
      FlameAudio.play('hatch_chime.wav', volume: _feedbackVol);
}
