import 'dart:async';

import 'package:flame/components.dart';

import '../components/speech_bubble.dart';
import '../components/speech_messages.dart';
import '../events.dart';
import '../lexaway_game.dart';

/// Translates gameplay events into speech-bubble messages. Knows about
/// [SpeechMessages] so that emitters don't have to — a sibling can
/// fire `AnswerCorrect` or `IdleChatterTriggered` without understanding
/// localization or message pools.
class DialogueController extends Component
    with HasGameReference<LexawayGame> {
  StreamSubscription<GameEvent>? _sub;
  late final SpeechBubble _bubble;

  @override
  void onMount() {
    super.onMount();
    _bubble = game.speechBubble;
    _sub = game.events.on<GameEvent>().listen(_handle);
  }

  void _handle(GameEvent event) {
    switch (event) {
      case AnswerCorrect(:final streak, :final answer):
        final msg = SpeechMessages.pickCorrectMessage(
          streak,
          answer,
          locale: game.locale,
        );
        if (msg != null) _bubble.show(msg);
      case AnswerWrong():
        final msg = SpeechMessages.pickWrongMessage(locale: game.locale);
        if (msg != null) _bubble.show(msg);
      case IdleChatterTriggered():
        _bubble.show(SpeechMessages.pickIdleMessage(locale: game.locale));
      default:
        break;
    }
  }

  @override
  void onRemove() {
    _sub?.cancel();
    super.onRemove();
  }
}
