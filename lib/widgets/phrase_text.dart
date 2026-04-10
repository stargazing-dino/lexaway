import 'package:flutter/material.dart';

import '../models/question.dart';

/// Renders a phrase with one of its words displayed as a fill-in-the-blank.
///
/// The blank span is located using [blankIndex] (a character offset into
/// [phrase]) and [answer] (whose length defines the blank width). Any
/// punctuation attached to the same whitespace-delimited word as the
/// answer is preserved around the blank — e.g. `¿Crees que es viejo?`
/// with `answer: 'Crees'` renders as `¿____ que es viejo?` before the
/// answer is revealed, and `¿Crees que es viejo?` after.
///
/// Each word is tappable: taps invoke [onTapWord] with the containing
/// word's text — the same token shape `Question.words` produces, so the
/// TTS prefetcher and the tap handler hit the same cache key.
/// Tapping an unrevealed blank does not fire [onTapWord].
class PhraseText extends StatelessWidget {
  final String phrase;
  final int blankIndex;
  final String answer;

  /// When true, the blank span shows [answer]; otherwise it shows `____`.
  final bool revealed;

  /// Color of the blank span (or revealed answer).
  final Color blankColor;

  /// Base text color for the non-blank portions of the phrase.
  final Color textColor;

  /// Called when a word (or the revealed blank) is tapped. Not called for
  /// taps on the unrevealed blank.
  final void Function(String text)? onTapWord;

  const PhraseText({
    super.key,
    required this.phrase,
    required this.blankIndex,
    required this.answer,
    required this.revealed,
    required this.blankColor,
    required this.textColor,
    this.onTapWord,
  });

  @override
  Widget build(BuildContext context) {
    final words = splitPhraseWords(phrase);
    final blankWordIdx = findBlankWordIndex(words, blankIndex);

    final baseStyle = TextStyle(
      color: textColor,
      fontSize: 20,
      height: 1.1,
    );

    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < words.length; i++) ...[
            if (i > 0) const TextSpan(text: ' '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _buildWord(
                word: words[i],
                isBlank: i == blankWordIdx,
                baseStyle: baseStyle,
              ),
            ),
          ],
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildWord({
    required PhraseWord word,
    required bool isBlank,
    required TextStyle baseStyle,
  }) {
    if (!isBlank) {
      return GestureDetector(
        onTap: onTapWord == null ? null : () => onTapWord!(word.text),
        child: Text(word.text, style: baseStyle),
      );
    }

    final blankStart = blankIndex - word.start;
    final blankEnd = blankStart + answer.length;

    // Defensive: if the stored range escapes the word boundaries, fall
    // back to blanking the whole word so we still show *something*.
    final safe = blankStart >= 0 && blankEnd <= word.text.length;
    final prefix = safe ? word.text.substring(0, blankStart) : '';
    final suffix = safe ? word.text.substring(blankEnd) : '';
    final blankText = revealed ? answer : '____';

    return GestureDetector(
      onTap: () {
        if (!revealed) return;
        onTapWord?.call(word.text);
      },
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            if (prefix.isNotEmpty) TextSpan(text: prefix),
            TextSpan(
              text: blankText,
              style: TextStyle(
                color: blankColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (suffix.isNotEmpty) TextSpan(text: suffix),
          ],
        ),
      ),
    );
  }
}
