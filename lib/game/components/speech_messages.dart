import 'dart:math';

final _rng = Random();

String? pickCorrectMessage(int streak, String answer) {
  // Always speak on streak milestones
  if (streak == 5) return 'On fire!';
  if (streak == 10) return 'Unstoppable!';
  if (streak == 25) return 'LEGENDARY';

  // ~1 in 4 chance to comment otherwise
  if (_rng.nextInt(4) != 0) return null;

  // Occasionally echo the correct word back
  if (_rng.nextInt(3) == 0 && answer.length <= 12) return '$answer!';

  const messages = [
    'Nice!',
    'Yes!',
    'Nailed it!',
    'Yep!',
    'Easy!',
    'Bravo!',
    'Oui oui!',
    'Got it!',
    'Magnifique!',
    'Smooth!',
  ];
  return messages[_rng.nextInt(messages.length)];
}

String? pickWrongMessage() {
  // ~1 in 3 chance to comment
  if (_rng.nextInt(3) != 0) return null;

  const messages = [
    'Ouch',
    'Hmm...',
    'Nope!',
    'Not quite',
    'Oof',
    'So close!',
    'Yikes',
    'Try again!',
  ];
  return messages[_rng.nextInt(messages.length)];
}

String pickIdleMessage() {
  const messages = [
    '...hello?',
    'zzz',
    '...',
    'Still there?',
    '*yawn*',
    'Tap tap?',
  ];
  return messages[_rng.nextInt(messages.length)];
}
