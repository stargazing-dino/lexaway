import 'dart:math';

import '../models/question.dart';
import 'pack_database.dart';

class QuestionSource {
  final PackDatabase? _db;
  final Random _rng = Random();
  List<Question> _batch;
  int _index = 0;

  QuestionSource(PackDatabase db, List<Question> initialBatch)
      : _db = db,
        _batch = List.of(initialBatch) {
    _batch.shuffle(_rng);
  }

  /// For tests/fakes — no database, just cycles the given list forever.
  QuestionSource.static(List<Question> questions)
      : _db = null,
        _batch = List.of(questions) {
    _batch.shuffle(_rng);
  }

  bool get hasQuestions => _batch.isNotEmpty;

  Question get current => _batch[_index];

  /// Advance to the next question, reloading a fresh batch from the database
  /// when the current one is exhausted.
  Future<Question> advance() async {
    _index++;
    if (_index >= _batch.length) {
      if (_db != null) {
        try {
          final fresh = await _db.loadQuestions(limit: 200);
          if (fresh.isNotEmpty) _batch = fresh;
        } catch (_) {
          // DB read failed — reshuffle existing batch rather than getting stuck.
        }
      }
      _batch.shuffle(_rng);
      _index = 0;
    }
    return current;
  }

  /// Returns up to [count] upcoming questions after the current one,
  /// without advancing the index. Returns fewer near batch boundaries.
  List<Question> peek(int count) {
    final result = <Question>[];
    for (var i = 1; i <= count && _index + i < _batch.length; i++) {
      result.add(_batch[_index + i]);
    }
    return result;
  }

  /// Record the player's answer for a question.
  /// No-op for now — SM-2 will write back to the database here.
  void recordAnswer(Question q, {required bool correct}) {}
}
