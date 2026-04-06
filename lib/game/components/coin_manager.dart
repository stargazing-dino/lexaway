import 'dart:math';

import 'package:flame/components.dart';
import '../audio_manager.dart';
import '../lexaway_game.dart';
import 'coin.dart';

class CoinManager extends Component with HasGameReference<LexawayGame> {
  final _rng = Random();

  double _nextSpawnAt = 0;
  double _lastOffset = 0;

  Function(int value)? onCoinCollected;

  @override
  void onMount() {
    super.onMount();
    // Pre-spawn first coin half a screen ahead
    _nextSpawnAt = game.ground.scrollOffset + game.size.x * 0.5;
    _lastOffset = game.ground.scrollOffset;
  }

  @override
  void update(double dt) {
    final offset = game.ground.scrollOffset;
    final moved = offset != _lastOffset;
    _lastOffset = offset;

    if (moved) {
      // Spawn coins ahead (max 5 per frame to prevent bursts)
      final spawnHorizon = offset + game.size.x + 64;
      var spawned = 0;
      while (_nextSpawnAt < spawnHorizon && spawned < 5) {
        _spawnAt(_nextSpawnAt);
        _nextSpawnAt += _randomGap();
        spawned++;
      }
    }

    // Position coins & check collection (always runs, even when idle)
    final playerCenterX = game.size.x * 0.25 + game.player.size.x * 0.5;

    for (final coin in children.query<Coin>()) {
      coin.position.x = coin.worldX - offset;

      // Collected when coin center reaches player center
      if (!coin.collected &&
          coin.position.x + coin.size.x * 0.5 <= playerCenterX) {
        coin.collected = true;
        final value = coin.type == CoinType.diamond ? 3 : 1;
        onCoinCollected?.call(value);
        if (coin.type == CoinType.diamond) {
          AudioManager.instance.playGem();
        } else {
          AudioManager.instance.playCoin();
        }
        coin.removeFromParent();
        continue;
      }

      // Clean up coins that scrolled off-screen left
      if (coin.position.x + coin.size.x < -64) {
        coin.removeFromParent();
      }
    }
  }

  void _spawnAt(double worldX) {
    final roll = _rng.nextDouble();
    if (roll < 0.15) {
      // Diamond
      add(Coin(type: CoinType.diamond, worldX: worldX));
    } else if (roll < 0.40) {
      // 2-coin cluster
      add(Coin(type: CoinType.coin, worldX: worldX));
      add(Coin(type: CoinType.coin, worldX: worldX + 16 * LexawayGame.pixelScale));
    } else {
      // Single coin
      add(Coin(type: CoinType.coin, worldX: worldX));
    }
  }

  /// Random gap of 2–5 tiles (128–320px) between spawn points.
  double _randomGap() => (2 + _rng.nextInt(4)) * 16 * LexawayGame.pixelScale;
}
