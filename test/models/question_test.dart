import 'package:flutter_test/flutter_test.dart';
import 'package:lexaway/models/question.dart';

void main() {
  group('splitPhraseWords', () {
    test('splits a simple ASCII phrase into words with char ranges', () {
      final words = splitPhraseWords('the quick fox');
      expect(words.length, 3);

      expect(words[0].text, 'the');
      expect(words[0].start, 0);
      expect(words[0].end, 3);

      expect(words[1].text, 'quick');
      expect(words[1].start, 4);
      expect(words[1].end, 9);

      expect(words[2].text, 'fox');
      expect(words[2].start, 10);
      expect(words[2].end, 13);
    });

    test('keeps leading Spanish punctuation attached to the first word', () {
      final words = splitPhraseWords('¿Crees que es viejo?');
      expect(
        words.map((w) => w.text).toList(),
        ['¿Crees', 'que', 'es', 'viejo?'],
      );
      expect(words[0].start, 0);
      expect(words[0].end, 6);
      expect(words[1].start, 7);
      expect(words[2].start, 11);
      expect(words[3].start, 14);
    });

    test('collapses multiple consecutive spaces', () {
      final words = splitPhraseWords('foo   bar');
      expect(words.length, 2);
      expect(words[0].start, 0);
      expect(words[0].end, 3);
      expect(words[1].start, 6);
      expect(words[1].end, 9);
    });

    test('ignores leading and trailing whitespace', () {
      final words = splitPhraseWords('  hello  ');
      expect(words.length, 1);
      expect(words[0].text, 'hello');
      expect(words[0].start, 2);
      expect(words[0].end, 7);
    });

    test('treats tabs and newlines as whitespace', () {
      final words = splitPhraseWords('foo\tbar\nbaz');
      expect(words.map((w) => w.text).toList(), ['foo', 'bar', 'baz']);
      expect(words[0].start, 0);
      expect(words[1].start, 4);
      expect(words[2].start, 8);
    });

    test('treats non-breaking space as whitespace', () {
      final words = splitPhraseWords('foo\u00A0bar');
      expect(words.length, 2);
      expect(words[0].text, 'foo');
      expect(words[1].text, 'bar');
      expect(words[1].start, 4);
    });

    test('empty phrase returns empty list', () {
      expect(splitPhraseWords(''), isEmpty);
    });

    test('whitespace-only phrase returns empty list', () {
      expect(splitPhraseWords('   \t\n  '), isEmpty);
    });
  });

  group('findBlankWordIndex', () {
    test('matches on the exact start offset of a word', () {
      final words = splitPhraseWords('the quick fox');
      expect(findBlankWordIndex(words, 0), 0);
      expect(findBlankWordIndex(words, 4), 1);
      expect(findBlankWordIndex(words, 10), 2);
    });

    test('matches on any offset inside a word', () {
      final words = splitPhraseWords('the quick fox');
      expect(findBlankWordIndex(words, 1), 0); // h in 'the'
      expect(findBlankWordIndex(words, 2), 0); // e in 'the'
      expect(findBlankWordIndex(words, 5), 1); // u in 'quick'
      expect(findBlankWordIndex(words, 12), 2); // x in 'fox'
    });

    test('finds Spanish verb after leading ¿ (regression for the bug report)', () {
      // spaCy tokenizes '¿Crees que es viejo?' as:
      //   ¿ @ idx=0, Crees @ idx=1, que @ idx=7, es @ idx=11, viejo @ idx=14, ? @ idx=19
      // So the packs pipeline stores blank_index=1, answer='Crees'.
      // The old algorithm walked cumulative offsets 0, 7, 11, 14 and
      // only matched on exact equality, so it never resolved blankIndex=1
      // and no word was rendered as a blank.
      const phrase = '¿Crees que es viejo?';
      final words = splitPhraseWords(phrase);
      expect(phrase.substring(1, 6), 'Crees');
      expect(findBlankWordIndex(words, 1), 0); // '¿Crees'
    });

    test('still finds words that happen to land on a cumulative boundary', () {
      // 'viejo' has idx=14 in the phrase above — a position the old
      // algorithm also computed correctly by coincidence. Make sure
      // the new algorithm still finds it.
      const phrase = '¿Crees que es viejo?';
      final words = splitPhraseWords(phrase);
      expect(findBlankWordIndex(words, 14), 3); // 'viejo?'
    });

    test('returns -1 for offsets in whitespace between words', () {
      final words = splitPhraseWords('the quick fox');
      expect(findBlankWordIndex(words, 3), -1); // space after 'the'
      expect(findBlankWordIndex(words, 9), -1); // space after 'quick'
    });

    test('returns -1 for out-of-bounds offsets', () {
      final words = splitPhraseWords('foo bar');
      expect(findBlankWordIndex(words, -1), -1);
      expect(findBlankWordIndex(words, 100), -1);
    });

    test('picks the correct occurrence when a word is repeated', () {
      // 'fox' appears twice — containment should resolve by position,
      // not by string identity.
      const phrase = 'fox and fox';
      final words = splitPhraseWords(phrase);
      expect(findBlankWordIndex(words, 0), 0); // first 'fox'
      expect(findBlankWordIndex(words, 8), 2); // second 'fox'
    });

    test('survives double-space phrases', () {
      // Very unlikely in real data (spaCy emits the extra space as its own
      // token, which pick_blank skips), but the renderer should still
      // handle it if it ever shows up.
      const phrase = 'foo  bar';
      final words = splitPhraseWords(phrase);
      expect(phrase.substring(5, 8), 'bar');
      expect(findBlankWordIndex(words, 5), 1);
      expect(findBlankWordIndex(words, 4), -1); // in the double space
    });

    test('empty word list returns -1', () {
      expect(findBlankWordIndex(const [], 0), -1);
    });
  });

  group('Question.words', () {
    Question q(String phrase) => Question(
          phrase: phrase,
          translation: '',
          blankIndex: 0,
          answer: '',
          options: const [],
        );

    test('matches splitPhraseWords output for a Spanish question', () {
      // Must stay aligned with splitPhraseWords so the TTS prefetcher
      // and PhraseText's tap callback produce identical cache keys.
      expect(q('¿Crees que es viejo?').words,
          ['¿Crees', 'que', 'es', 'viejo?']);
    });

    test('collapses multiple whitespace runs without leaving empty tokens', () {
      // Old implementation returned '' tokens on leading whitespace; the
      // new one skips them.
      expect(q('  foo   bar  ').words, ['foo', 'bar']);
    });
  });
}
