import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tts_cache.dart';
import '../data/tts_manager.dart';
import '../data/tts_service.dart';
import 'bootstrap.dart';

/// Singleton TtsManager backed by the Hive box.
final ttsManagerProvider = Provider<TtsManager>((ref) {
  return TtsManager(ref.watch(hiveBoxProvider), modelsDir: ref.watch(modelsDirProvider));
});

/// Singleton TtsService — lazily initialises per language.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService(tmpDir: ref.watch(tmpDirProvider));
  ref.onDispose(() => service.dispose());
  return service;
});

/// Singleton TtsCache — manages prefetch queue and in-memory audio cache.
final ttsCacheProvider = Provider<TtsCache>((ref) {
  return TtsCache(
    ttsService: ref.watch(ttsServiceProvider),
    ttsManager: ref.watch(ttsManagerProvider),
  );
});
