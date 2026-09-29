import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/features/game/data/topic_packs.dart';
import 'package:project_4/features/game/logic/game_controller.dart';
import 'package:project_4/features/game/logic/game_repository.dart';
import 'package:project_4/features/game/logic/game_session.dart';
import 'package:project_4/features/game/logic/local_game_repository.dart';
import 'package:project_4/features/game/models/game_phase.dart';
import 'package:project_4/features/game/models/player_view.dart';

const crew = ['Alex', 'Blair', 'Casey', 'Drew'];

/// Makes Casey (seat 2) the Chameleon and words[1] the secret. A middle seat
/// on purpose: with the Chameleon first or last, a rule that paid the first
/// or last player instead of the Chameleon would pass by coincidence.
class _CaseyIsChameleon implements Random {
  int _calls = 0;
  @override
  int nextInt(int max) => (_calls++ == 0 ? 2 : 1) % max;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

final secret = topicPacks.first.words[1];
final wrongGuess = topicPacks.first.words[0];

GameRepository newRound({List<String> players = crew}) => LocalGameRepository(
  GameController(
    players: players,
    topic: topicPacks.first,
    random: _CaseyIsChameleon(),
  ),
);

/// Offers [round] to [session] after every action, as GameScreen's listener
/// does in production, so the session sees every intermediate state.
void Function(void Function()) actor(
  GameSession session,
  GameRepository round,
) => (action) {
  action();
  session.recordRound(round);
};

/// Every player opens their role, then hides it (the reveal lap).
void revealRoles(GameSession session, GameRepository round) {
  final act = actor(session, round);
  for (var i = 0; i < crew.length; i++) {
    act(round.openPrivateView);
    act(round.finishReveal);
  }
}

/// One lap of clues. Since the UI rewrite each player must open their clue
/// screen before giving a clue; finishClue throws StateError otherwise.
void clueLap(GameSession session, GameRepository round) {
  final act = actor(session, round);
  for (var i = 0; i < crew.length; i++) {
    act(round.openPrivateView);
    act(round.finishClue);
  }
}

/// Plays a round through the same repository actions the UI calls.
/// [extraClueLaps] is how many times the group presses "Another Round" in
/// the discussion before voting.
void play(
  GameSession session,
  GameRepository round, {
  required List<int> votes,
  String? guess,
  int extraClueLaps = 0,
}) {
  final act = actor(session, round);
  revealRoles(session, round);
  clueLap(session, round);
  for (var i = 0; i < extraClueLaps; i++) {
    act(round.startAnotherClueRound);
    clueLap(session, round);
  }
  act(round.startVoting);
  for (final suspect in votes) {
    act(round.openPrivateView);
    act(() => round.castVote(suspect));
  }
  if (guess != null) act(() => round.guessWord(guess));
}

// Ballots in seat order. Casey, seat 2, is always the Chameleon here.
const tiedVote = [1, 0, 1, 0]; // Alex 2, Blair 2: tie, Chameleon wins
const wrongAccusation = [1, 2, 1, 1]; // Blair accused: Chameleon escapes
const caseyCaught = [2, 2, 1, 2]; // Casey accused: goes to the final guess

Map<String, int> scores(GameSession session) => {
  for (final standing in session.standings) standing.name: standing.points,
};

/// A stand-in rule, to prove the session defers to whatever rule it is given.
class _EveryoneScoresTen implements ScoringRule {
  const _EveryoneScoresTen();

  @override
  String get summary => 'Everyone scores ten.';

  @override
  Map<String, int> pointsFor(PlayerView result) => {
    for (final name in result.players) name: 10,
  };
}

void main() {
  late GameSession session;
  setUp(() => session = GameSession(players: crew));

  test('a group win gives one point to every player except the Chameleon', () {
    final round = newRound();
    addTearDown(round.dispose);
    play(session, round, votes: caseyCaught, guess: wrongGuess);

    expect(scores(session), {'Alex': 1, 'Blair': 1, 'Casey': 0, 'Drew': 1});
    expect(session.roundsPlayed, 1);
  });

  group(
    'a Chameleon win gives the Chameleon two points and nobody else any',
    () {
      for (final (route, votes, guess) in [
        ('tied vote', tiedVote, null),
        ('wrong accusation', wrongAccusation, null),
        ('caught, then guessed the word', caseyCaught, secret),
      ]) {
        test(route, () {
          final round = newRound();
          addTearDown(round.dispose);
          play(session, round, votes: votes, guess: guess);

          expect(scores(session), {
            'Alex': 0,
            'Blair': 0,
            'Casey': 2,
            'Drew': 0,
          });
          expect(session.roundsPlayed, 1);
        });
      }
    },
  );

  test('nothing is recorded before the round is over', () {
    // Rule (a) would crash on an unfinished round (no winner yet), which would
    // hide whether the session let it through. This rule reads only the
    // players, so a round counted too early shows up as a wrong count.
    session = GameSession(players: crew, rule: const _EveryoneScoresTen());
    final round = newRound();
    addTearDown(round.dispose);
    // Stop at the final guess: the Chameleon is named but the round is open.
    play(session, round, votes: caseyCaught);

    expect(round.view.chameleonName, 'Casey');
    expect(session.roundsPlayed, 0);
    expect(scores(session), {'Alex': 0, 'Blair': 0, 'Casey': 0, 'Drew': 0});
  });

  group('another clue round', () {
    // The stand-in rule reads only the crew, so a round recorded early shows
    // up as a wrong count rather than as a crash on a missing winner.
    test('records nothing and moves no score until the round finishes', () {
      session = GameSession(players: crew, rule: const _EveryoneScoresTen());
      final round = newRound();
      addTearDown(round.dispose);
      final act = actor(session, round);
      final zero = {for (final name in crew) name: 0};

      revealRoles(session, round);
      clueLap(session, round);
      expect(round.view.phase, GamePhase.discussion);
      expect(session.roundsPlayed, 0);

      // Press "Another Round": back to clues, same roles, nothing scored.
      act(round.startAnotherClueRound);
      expect(round.view.phase, GamePhase.clues);
      expect(round.view.turn, 0);
      expect(session.roundsPlayed, 0);
      expect(scores(session), zero);

      clueLap(session, round);
      act(round.startAnotherClueRound);
      clueLap(session, round);
      expect(round.view.phase, GamePhase.discussion);
      expect(session.roundsPlayed, 0);
      expect(scores(session), zero);

      act(round.startVoting);
      for (final suspect in tiedVote) {
        act(round.openPrivateView);
        act(() => round.castVote(suspect));
      }

      // Three clue laps, still one round, scored once.
      expect(round.view.phase, GamePhase.result);
      expect(session.roundsPlayed, 1);
      expect(scores(session), {
        'Alex': 10,
        'Blair': 10,
        'Casey': 10,
        'Drew': 10,
      });
    });

    test('a round with extra clue laps scores like any other', () {
      final round = newRound();
      addTearDown(round.dispose);
      play(session, round, votes: tiedVote, extraClueLaps: 2);

      expect(scores(session), {'Alex': 0, 'Blair': 0, 'Casey': 2, 'Drew': 0});
      expect(session.roundsPlayed, 1);
    });
  });

  test('offering the same finished round again does not count it twice', () {
    final round = newRound();
    addTearDown(round.dispose);
    play(session, round, votes: tiedVote);
    session
      ..recordRound(round)
      ..recordRound(round);

    expect(session.roundsPlayed, 1);
    expect(scores(session)['Casey'], 2);
  });

  test('scores accumulate across rounds', () {
    for (final (votes, guess) in [
      (tiedVote, null), // Casey +2
      (caseyCaught, wrongGuess), // Alex, Blair, Drew +1
      (wrongAccusation, null), // Casey +2
    ]) {
      final round = newRound();
      addTearDown(round.dispose);
      play(session, round, votes: votes, guess: guess);
    }

    expect(scores(session), {'Alex': 1, 'Blair': 1, 'Casey': 4, 'Drew': 1});
    expect(session.roundsPlayed, 3);
  });

  test('standings list the leader first and keep seat order on ties', () {
    final round = newRound();
    addTearDown(round.dispose);
    play(session, round, votes: caseyCaught, guess: wrongGuess);

    expect(
      [for (final standing in session.standings) standing.name],
      ['Alex', 'Blair', 'Drew', 'Casey'],
    );
  });

  test('a round played by a different crew is rejected', () {
    // Eve replaces Drew, not the Chameleon: the rule pays only Casey, a name
    // the session knows, so only the crew check can be what refuses this.
    final round = newRound(players: ['Alex', 'Blair', 'Casey', 'Eve']);
    addTearDown(round.dispose);

    expect(() => play(session, round, votes: tiedVote), throwsArgumentError);
    expect(session.roundsPlayed, 0);
  });

  test('the session scores with the rule it is given', () {
    session = GameSession(players: crew, rule: const _EveryoneScoresTen());
    final round = newRound();
    addTearDown(round.dispose);
    play(session, round, votes: tiedVote);

    expect(scores(session), {'Alex': 10, 'Blair': 10, 'Casey': 10, 'Drew': 10});
    expect(session.rule.summary, 'Everyone scores ten.');
  });

  test('the default rule is candidate (a)', () {
    expect(session.rule, isA<FlatWinRule>());
  });

  group('round limit (CHM-14)', () {
    void playTiedRound(GameSession session) {
      final round = newRound();
      addTearDown(round.dispose);
      play(session, round, votes: tiedVote);
    }

    test('a session is unlimited by default and never ends', () {
      expect(session.roundLimit, isNull);
      expect(session.isOver, isFalse);
      for (var i = 0; i < 5; i++) {
        playTiedRound(session);
        expect(session.isOver, isFalse);
      }
      expect(session.roundsPlayed, 5);
    });

    test('ends exactly when the Nth round is recorded', () {
      session = GameSession(players: crew, roundLimit: 3);
      expect(session.isOver, isFalse);
      playTiedRound(session);
      expect(session.isOver, isFalse);
      playTiedRound(session);
      expect(session.isOver, isFalse);
      playTiedRound(session);
      expect(session.isOver, isTrue);
      expect(session.roundsPlayed, 3);
    });

    test('an unfinished round does not bring the end closer', () {
      session = GameSession(players: crew, roundLimit: 1);
      final round = newRound();
      addTearDown(round.dispose);
      play(session, round, votes: caseyCaught); // stops at the final guess
      expect(session.isOver, isFalse);
      round.guessWord(wrongGuess);
      session.recordRound(round);
      expect(session.isOver, isTrue);
    });

    test('a finished game takes no further rounds', () {
      session = GameSession(players: crew, roundLimit: 1);
      playTiedRound(session);
      expect(() => playTiedRound(session), throwsStateError);
      expect(session.roundsPlayed, 1);
      expect(scores(session)['Casey'], 2);
    });

    test('a limit below one round is rejected', () {
      expect(
        () => GameSession(players: crew, roundLimit: 0),
        throwsArgumentError,
      );
    });
  });

  group('leaders', () {
    test('is the single top scorer', () {
      final round = newRound();
      addTearDown(round.dispose);
      play(session, round, votes: tiedVote); // Casey +2
      expect(session.leaders, ['Casey']);
    });

    test('names every player tied on top, in seat order', () {
      final round = newRound();
      addTearDown(round.dispose);
      play(session, round, votes: caseyCaught, guess: wrongGuess);
      expect(session.leaders, ['Alex', 'Blair', 'Drew']);
    });
  });
}
