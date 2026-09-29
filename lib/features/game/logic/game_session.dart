import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/game_phase.dart';
import '../models/player_view.dart';
import 'game_repository.dart';

/// Decides what one finished round is worth to each player.
///
/// This is the seam for the scoring decision: a different rule can replace
/// [FlatWinRule] without touching [GameSession] or the results screen, which
/// only ever see this interface.
abstract interface class ScoringRule {
  /// Points earned this round, by player name. Players left out score 0.
  ///
  /// [result] is always a finished round: [PlayerView.winner] and
  /// [PlayerView.chameleonName] are set.
  Map<String, int> pointsFor(PlayerView result);

  /// One line shown under the standings so players know how points are won.
  String get summary;
}

/// The game's scoring rule: the winning side scores, however it won.
///
/// Chosen 2026-09-29 (Trello CHM-9) over a board-game-style rule where the
/// Chameleon scores differently for escaping the vote than for being caught
/// and guessing the word. That rule would need a finished round to record
/// *how* the Chameleon won, and it does not: [PlayerView.resultReason] is
/// display text, not data. To change the rule, implement [ScoringRule].
class FlatWinRule implements ScoringRule {
  const FlatWinRule();

  @override
  String get summary =>
      'Group win: +1 to everyone but the Chameleon. Chameleon win: +2.';

  @override
  Map<String, int> pointsFor(PlayerView result) {
    final chameleon = result.chameleonName!;
    return switch (result.winner!) {
      RoundWinner.group => {
        for (final name in result.players)
          if (name != chameleon) name: 1,
      },
      RoundWinner.chameleon => {chameleon: 2},
    };
  }
}

/// One row of the standings.
typedef Standing = ({String name, int points});

/// The running score for one crew across replays. In memory only.
///
/// Scoring spans rounds, and replay builds each round from scratch, so the
/// score cannot live in a round's controller or repository. `GameScreen`
/// holds one session for as long as the same crew keeps replaying; leaving
/// for setup discards the screen, and with it the session.
///
/// Players are identified by name. That is safe because a round's names are
/// unique, and a session only ever accepts rounds played by its own crew.
///
/// A session is also one game, so the round limit (CHM-14) lives here and not
/// in a round: it counts rounds across replays, the way the score does.
class GameSession {
  /// Throws [ArgumentError] if [roundLimit] is below one: a game that is over
  /// before its first round could never show its result.
  GameSession({
    required List<String> players,
    this.rule = const FlatWinRule(),
    this.roundLimit,
  }) : players = List.unmodifiable(players),
       _points = {for (final name in players) name: 0} {
    if (roundLimit != null && roundLimit! < 1) {
      throw ArgumentError.value(
        roundLimit,
        'roundLimit',
        'A game needs at least one round',
      );
    }
  }

  /// The crew in seating order.
  final List<String> players;
  final ScoringRule rule;

  /// Rounds in this game. Null means the crew can replay without end.
  final int? roundLimit;

  final Map<String, int> _points;
  int _roundsPlayed = 0;

  // Rounds finish one after another, so remembering the last one counted is
  // enough to never count a round twice.
  GameRepository? _lastRecorded;

  int get roundsPlayed => _roundsPlayed;

  /// True once the last allowed round has been recorded: the result on
  /// screen is the final one. Never true without a [roundLimit].
  ///
  /// Counts recorded rounds, so it turns true on the Nth result itself, not
  /// when an (N+1)th round would begin.
  bool get isOver => roundLimit != null && _roundsPlayed >= roundLimit!;

  /// Everyone on the top score, in seat order. More than one is a tie, and
  /// when [isOver] they are co-winners.
  List<String> get leaders {
    if (players.isEmpty) return const [];
    final top = _points.values.reduce(max);
    return List.unmodifiable(players.where((name) => _points[name] == top));
  }

  /// Highest score first, ties in seat order. `List.sort` does not promise to
  /// keep equal items in order (today's SDK happens to for short lists), so
  /// the seat tie-break is written out rather than left to that accident.
  List<Standing> get standings {
    final seats = [for (var i = 0; i < players.length; i++) i]
      ..sort((a, b) {
        final byPoints = _points[players[b]]!.compareTo(_points[players[a]]!);
        return byPoints != 0 ? byPoints : a.compareTo(b);
      });
    return List.unmodifiable([
      for (final seat in seats)
        (name: players[seat], points: _points[players[seat]]!),
    ]);
  }

  /// Adds [round]'s points to the standings once, when it has finished.
  ///
  /// Safe to call on every change notification from [round]: it does nothing
  /// until the round reaches its result, and nothing when offered a round it
  /// has already counted. That is what lets the caller hook it to the round's
  /// listener rather than to a rebuild or a button.
  void recordRound(GameRepository round) {
    final result = round.view;
    if (result.phase != GamePhase.result || identical(round, _lastRecorded)) {
      return;
    }
    // Checked after the repeat test, so the final round may keep announcing
    // itself; only a new round after the last one is refused.
    if (isOver) {
      throw StateError('This game is over; start a new game to play on');
    }
    if (!listEquals(result.players, players)) {
      throw ArgumentError.value(
        result.players,
        'round',
        'A session keeps one crew; this round was played by another',
      );
    }
    rule.pointsFor(result).forEach((name, points) {
      // update() throws on a name outside the crew instead of inventing one.
      _points.update(name, (total) => total + points);
    });
    _roundsPlayed++;
    _lastRecorded = round;
  }
}
