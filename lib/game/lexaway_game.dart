import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';

import '../data/world_state.dart';
import '../data/world_state_repository.dart';
import 'audio_manager.dart';
import 'components/coin_manager.dart';
import 'components/ground.dart';
import 'components/player.dart';
import 'components/speech_bubble.dart';
import 'components/speech_messages.dart';
import 'components/wind_lines.dart';
import 'events.dart';
import 'movement_controller.dart';
import 'systems/animation_controller.dart';
import 'systems/audio_cue_controller.dart';
import 'systems/dialogue_controller.dart';
import 'systems/scroll_controller.dart';
import 'systems/wind_controller.dart';
import 'world/biome_registry.dart';
import 'world/world_generator.dart';
import 'world/world_map.dart';
import 'world/world_renderer.dart';

class LexawayGame extends FlameGame with HasCollisionDetection {
  static const double pixelScale = 4.0;
  static const double groundLevel = 0.35;

  // Three tiles at 4x scale = 192px. Walk them in ~2.4s.
  static const double walkSpeed = 80;
  static const double walkTarget = 3 * 16 * pixelScale;
  static const double cloudDrift = 1.5;

  final WorldStateRepository worldStateRepository;
  final String characterPath;
  String _fontFamily;
  String _locale;

  /// The currently-rendered font family for in-game text. Updating this
  /// forwards the change to [speechBubble] so a Settings change is picked up
  /// while the game is running. If [onLoad] hasn't completed yet, the new
  /// value is stored and picked up when [speechBubble] is constructed there.
  String get fontFamily => _fontFamily;
  set fontFamily(String value) {
    if (value == _fontFamily) return;
    _fontFamily = value;
    if (isLoaded) speechBubble.fontFamily = value;
  }

  LexawayGame({
    required this.worldStateRepository,
    String locale = 'en',
    required this.characterPath,
    required String fontFamily,
  })  : _locale = locale,
        _fontFamily = fontFamily;

  String get locale => _locale;
  set locale(String value) {
    if (value == _locale) return;
    _locale = value;
    SpeechMessages.load(value);
  }

  /// Typed event bus for sibling systems. Constructed eagerly so any
  /// component can subscribe inside its own `onLoad` without boot-order
  /// surprises.
  final GameEvents events = GameEvents();

  late WorldMap worldMap;
  late WorldRenderer worldRenderer;
  late Player player;
  late Ground ground;
  late ParallaxComponent parallaxComponent;
  late SpeechBubble speechBubble;
  late CoinManager coinManager;
  late WindLines windLines;
  late MovementController movementController;

  /// Coin item indices the player has already collected.
  final Set<int> collectedCoins = {};

  /// How many extension batches have been appended.
  int _worldExtensions = 0;

  /// Set by components when the persistable world state has changed.
  /// Drained once per frame in [update] and on [flushWorldState].
  bool _worldDirty = false;

  Function(int value)? onCoinCollected;
  Function(int steps)? onStepTaken;

  @override
  Color backgroundColor() => const Color(0xFF50BBFF);

  @override
  Future<void> onLoad() async {
    final saved = worldStateRepository.load();
    final seed = saved?.seed ?? Random().nextInt(1 << 32);
    _worldExtensions = saved?.extensions ?? 0;

    worldMap = WorldGenerator().generate(seed);
    // Replay extensions with the same seeds used during original gameplay.
    final targetExtensions = _worldExtensions;
    _worldExtensions = 0;
    for (var i = 0; i < targetExtensions; i++) {
      _worldExtensions++;
      _extendWorld();
    }

    final initialBiome = BiomeRegistry.get(worldMap.segments.first.biome);
    final parallaxHeight = size.y * groundLevel + 16 * pixelScale - 40;
    parallaxComponent = await loadParallaxComponent(
      initialBiome.parallaxLayers.map(ParallaxImageData.new).toList(),
      baseVelocity: Vector2.zero(),
      velocityMultiplierDelta: Vector2(1.4, 0),
      fill: LayerFill.height,
      filterQuality: FilterQuality.none,
      size: Vector2(size.x, parallaxHeight),
    );
    add(parallaxComponent);

    ground = Ground(worldMap: worldMap)..priority = 1;
    if (saved != null) {
      ground.scrollOffset = saved.scrollOffset;
    }
    add(ground);

    if (saved != null) {
      collectedCoins.addAll(saved.collectedCoins);
    }

    worldRenderer = WorldRenderer(worldMap)..priority = 1;
    add(worldRenderer);

    coinManager = CoinManager(worldMap: worldMap, collectedCoins: collectedCoins)
      ..priority = 1
      ..onCoinCollected = (value) => onCoinCollected?.call(value);
    add(coinManager);

    player = Player(spritePath: characterPath)..priority = 2;
    await add(player);
    player.play(DinoAnim.scan);

    windLines = WindLines()..priority = 2;
    add(windLines);

    speechBubble = SpeechBubble(follow: player, fontFamily: _fontFamily)
      ..priority = 3;
    add(speechBubble);

    movementController = MovementController()
      ..onStepTaken = (steps) => onStepTaken?.call(steps);
    add(movementController);

    add(AudioCueController());
    add(ScrollController());
    add(WindController());
    add(AnimationController());
    add(DialogueController());

    await AudioManager.instance.preload();
    await SpeechMessages.load('en');
    if (locale != 'en') await SpeechMessages.load(locale);

    // Persist the seed on first run. Calls the private writer directly
    // because `isLoaded` is still false inside onLoad, so flushWorldState()
    // would no-op.
    if (saved == null) _writeWorldState();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Lazy world extension: if player is within 200 tiles of the end,
    // generate another batch.
    final tilePx = 16.0 * pixelScale;
    if (ground.scrollOffset + 200 * tilePx > worldMap.totalLengthPx) {
      _worldExtensions++;
      _extendWorld();
      _worldDirty = true;
    }

    // Coalesce saves to at most one per frame. Components flip the dirty
    // flag via [markWorldDirty]; the actual write happens here.
    if (_worldDirty) _writeWorldState();
  }

  void correctAnswer({required int streak, required String answer}) {
    movementController.correctAnswer(streak: streak, answer: answer);
  }

  void wrongAnswer() {
    movementController.wrongAnswer();
  }

  /// Append 1000 more tiles to the world using a derived seed.
  void _extendWorld() {
    final extensionSeed = worldMap.seed + _worldExtensions;
    final extension = WorldGenerator().generate(
      extensionSeed,
      totalTiles: 1000,
      startTile: worldMap.totalTiles,
      startIndex: worldMap.nextItemIndex,
    );
    worldMap.segments.addAll(extension.segments);
    worldMap.nextItemIndex = extension.nextItemIndex;
  }

  /// Mark the world state as changed. Components call this whenever they
  /// mutate persistable state (walk finish, coin pickup, world extension);
  /// the save itself is coalesced to one per frame inside [update].
  void markWorldDirty() {
    _worldDirty = true;
  }

  /// Force an immediate synchronous write, bypassing the per-frame coalesce.
  /// Use this from lifecycle hooks (pause/dispose) where [update] may never
  /// run again before the process is torn down.
  ///
  /// No-ops if [onLoad] hasn't finished yet, because [_snapshot] reads `late`
  /// fields that don't exist until mid-boot. This matters on the boot-failure
  /// dispose path, where `GameScreen.dispose` can fire after a partial
  /// `onLoad`.
  void flushWorldState() {
    if (!isLoaded) return;
    _writeWorldState();
  }

  void _writeWorldState() {
    _worldDirty = false;
    worldStateRepository.save(_snapshot());
  }

  @override
  void onRemove() {
    events.dispose();
    super.onRemove();
  }

  WorldState _snapshot() => WorldState(
        seed: worldMap.seed,
        extensions: _worldExtensions,
        scrollOffset: ground.scrollOffset,
        collectedCoins: collectedCoins.toList(),
      );
}
