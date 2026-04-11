import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../data/hive_keys.dart';
import 'bootstrap.dart';

/// Base class for simple Hive-backed int notifiers.
abstract class HiveIntNotifier extends Notifier<int> {
  String get key;
  int get defaultValue => 0;

  Box get _box => ref.read(hiveBoxProvider);

  @override
  int build() => _box.get(key, defaultValue: defaultValue) as int;

  void _save() => _box.put(key, state);
}

final streakProvider = NotifierProvider<StreakNotifier, int>(
  StreakNotifier.new,
);

class StreakNotifier extends HiveIntNotifier {
  @override
  String get key => HiveKeys.streak;

  void increment() {
    state++;
    _save();
    final best = _box.get(HiveKeys.bestStreak, defaultValue: 0) as int;
    if (state > best) {
      _box.put(HiveKeys.bestStreak, state);
      ref.read(bestStreakProvider.notifier)._sync();
    }
  }

  void reset() {
    state = 0;
    _save();
  }
}

final bestStreakProvider = NotifierProvider<BestStreakNotifier, int>(
  BestStreakNotifier.new,
);

class BestStreakNotifier extends HiveIntNotifier {
  @override
  String get key => HiveKeys.bestStreak;

  void _sync() => state = _box.get(key, defaultValue: defaultValue) as int;
}

final coinProvider = NotifierProvider<CoinNotifier, int>(CoinNotifier.new);

class CoinNotifier extends HiveIntNotifier {
  @override
  String get key => HiveKeys.coins;

  void add(int amount) {
    state += amount;
    _save();
  }
}

final stepsProvider = NotifierProvider<StepsNotifier, int>(StepsNotifier.new);

class StepsNotifier extends HiveIntNotifier {
  @override
  String get key => HiveKeys.steps;

  void add(int count) {
    state += count;
    _save();
  }
}
