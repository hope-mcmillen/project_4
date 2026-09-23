import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/topic_pack.dart';

enum GamePhase { reveal, clues, discussion, voting, guess, result }

enum RoundWinner { group, chameleon }

/// Owns one local round. Screens render state and invoke actions, never assign roles.
/// This is in-memory pass-and-play; a future online mode needs server-owned secrets.
class GameController extends ChangeNotifier {
  GameController({
    required List<String> players,
    required this.topic,
    Random? random,
  }) : players = List.unmodifiable(players.map((name) => name.trim())) {
    if (this.players.length < 3 || this.players.length > 8) {
      throw ArgumentError('Use 3–8 players.');
    }
    if (this.players.any((name) => name.isEmpty || name.length > 20) ||
        this.players.map((name) => name.toLowerCase()).toSet().length !=
            this.players.length) {
      throw ArgumentError(
        'Player names must be unique and 1–20 characters long.',
      );
    }
    if (topic.words.length < 2 ||
        topic.words.any((word) => word.trim().isEmpty) ||
        topic.words.map((word) => word.trim().toLowerCase()).toSet().length !=
            topic.words.length) {
      throw ArgumentError(
        'A topic needs at least two distinct, nonempty words.',
      );
    }
    final source = random ?? Random.secure();
    _chameleonIndex = source.nextInt(this.players.length);
    _secretWord = topic.words[source.nextInt(topic.words.length)];
  }

  final List<String> players;
  final TopicPack topic;
  late final int _chameleonIndex;
  late final String _secretWord;
  GamePhase _phase = GamePhase.reveal;
  int _turn = 0;
  bool _privateOpen = false;
  final Map<int, int> _votes = {};
  RoundWinner? _winner;
  String? _resultReason;

  GamePhase get phase => _phase;
  int get turn => _turn;
  String get currentPlayer => players[_turn];
  bool get privateOpen => _privateOpen;
  RoundWinner? get winner => _winner;
  String? get resultReason => _resultReason;
  String? get secretWord => _phase == GamePhase.result ? _secretWord : null;
  String? get chameleonName =>
      _phase == GamePhase.guess || _phase == GamePhase.result
      ? players[_chameleonIndex]
      : null;
  String? get roleWord =>
      _phase == GamePhase.reveal && _privateOpen && _turn != _chameleonIndex
      ? _secretWord
      : null;
  bool get isRevealedChameleon =>
      _phase == GamePhase.reveal && _privateOpen && _turn == _chameleonIndex;
  Map<int, int> get voteCounts {
    if (_phase != GamePhase.result) return const {};
    return Map.unmodifiable(_tally());
  }

  void _require(GamePhase expected) {
    if (_phase != expected) {
      throw StateError('This action is not available during $_phase.');
    }
  }

  void openPrivateView() {
    if (_phase != GamePhase.reveal && _phase != GamePhase.voting) {
      throw StateError('No private view in this phase.');
    }
    _privateOpen = true;
    notifyListeners();
  }

  void hidePrivateView() {
    if (!_privateOpen) return;
    _privateOpen = false;
    notifyListeners();
  }

  void finishReveal() {
    _require(GamePhase.reveal);
    if (!_privateOpen) throw StateError('Reveal your role first.');
    _privateOpen = false;
    _turn++;
    if (_turn == players.length) {
      _turn = 0;
      _phase = GamePhase.clues;
    }
    notifyListeners();
  }

  void finishClue() {
    _require(GamePhase.clues);
    _turn++;
    if (_turn == players.length) {
      _turn = 0;
      _phase = GamePhase.discussion;
    }
    notifyListeners();
  }

  void startVoting() {
    _require(GamePhase.discussion);
    _phase = GamePhase.voting;
    notifyListeners();
  }

  void castVote(int suspect) {
    _require(GamePhase.voting);
    if (!_privateOpen) throw StateError('Open your ballot first.');
    if (suspect < 0 || suspect >= players.length || suspect == _turn) {
      throw ArgumentError('Vote for another player.');
    }
    _votes[_turn] = suspect;
    _privateOpen = false;
    _turn++;
    if (_turn == players.length) {
      _turn = 0;
      final counts = _tally();
      final highest = counts.values.reduce(max);
      final leaders = counts.keys
          .where((index) => counts[index] == highest)
          .toList();
      if (leaders.length > 1) {
        _finish(
          RoundWinner.chameleon,
          'The vote was tied. The Chameleon slipped away.',
        );
      } else if (leaders.single != _chameleonIndex) {
        _finish(
          RoundWinner.chameleon,
          'The group accused ${players[leaders.single]}. The Chameleon escaped.',
        );
      } else {
        _phase = GamePhase.guess;
      }
    }
    notifyListeners();
  }

  Map<int, int> _tally() {
    final counts = {for (var i = 0; i < players.length; i++) i: 0};
    for (final suspect in _votes.values) {
      counts[suspect] = counts[suspect]! + 1;
    }
    return counts;
  }

  void guessWord(String word) {
    _require(GamePhase.guess);
    if (!topic.words.contains(word)) {
      throw ArgumentError('Choose a word from the board.');
    }
    if (word == _secretWord) {
      _finish(
        RoundWinner.chameleon,
        'Caught, but clever! The Chameleon guessed the secret word.',
      );
    } else {
      _finish(
        RoundWinner.group,
        'The Chameleon guessed “$word”. The group kept its secret.',
      );
    }
    notifyListeners();
  }

  void _finish(RoundWinner winner, String reason) {
    _winner = winner;
    _resultReason = reason;
    _phase = GamePhase.result;
  }
}
