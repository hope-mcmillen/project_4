import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/app/theme.dart';
import 'package:project_4/features/game/data/topic_packs.dart';
import 'package:project_4/features/game/logic/game_controller.dart';
import 'package:project_4/features/game/logic/game_repository.dart';
import 'package:project_4/features/game/logic/local_game_repository.dart';
import 'package:project_4/features/game/models/game_settings.dart';
import 'package:project_4/features/game/screens/game_screen.dart';

const crew = ['Player 1', 'Player 2', 'Player 3', 'Player 4'];

/// The button on the stand-in setup screen. Seeing it again means GameScreen
/// was popped, which is what "New game" and "Leave round" must do.
const startLabel = 'Start test game';

/// Puts the Chameleon in a chosen seat and makes words[1] the secret.
class ChameleonAt implements Random {
  ChameleonAt(this.seat);
  final int seat;
  int _calls = 0;
  @override
  int nextInt(int max) => (_calls++ == 0 ? seat : 1) % max;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

/// Hosts GameScreen the way the setup screen will once it can pass settings:
/// pushed as a route over a screen it returns to, building real local rounds
/// through the same `createGame` factory the app uses.
///
/// Round k's Chameleon sits in `chameleonSeats[k]` (the last entry repeats),
/// counted across every game this host starts, so a test can arrange who
/// scores and therefore who wins.
class GameHost {
  GameHost({this.settings, this.chameleonSeats = const [0]});

  /// Null builds GameScreen without passing settings at all, which is how
  /// the setup screen calls it today: that path must be the old game.
  final GameSettings? settings;
  final List<int> chameleonSeats;

  final _rounds = <GameRepository>[];
  final _seats = <int>[];

  /// The round GameScreen is showing now.
  GameRepository get current => _rounds.last;

  /// How many rounds GameScreen has built, across every game started.
  int get roundsBuilt => _rounds.length;

  GameRepository _newRound() {
    final seat = chameleonSeats[min(_rounds.length, chameleonSeats.length - 1)];
    final round = LocalGameRepository(
      GameController(
        players: crew,
        topic: topicPacks.first,
        random: ChameleonAt(seat),
      ),
    );
    _rounds.add(round);
    _seats.add(seat);
    return round;
  }

  Widget get app => MaterialApp(
    theme: buildTheme(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => settings == null
                    ? GameScreen(createGame: _newRound)
                    : GameScreen(settings: settings!, createGame: _newRound),
              ),
            ),
            child: const Text(startLabel),
          ),
        ),
      ),
    ),
  );

  /// Opens the app and starts a game; its first round is at the reveal.
  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(app);
    await tapText(tester, startLabel);
  }

  /// Takes the current round through every private reveal with the actions
  /// the reveal buttons call, so a test can begin at the clues.
  Future<void> revealAll(WidgetTester tester) async {
    for (var i = 0; i < crew.length; i++) {
      current
        ..openPrivateView()
        ..finishReveal();
    }
    await tester.pumpAndSettle();
  }

  /// Plays the current round to its result with the actions the phase
  /// buttons call. GameScreen's own listener sees every step, exactly as in
  /// the app; only the taps are skipped.
  ///
  /// The Chameleon wins through a tied vote; the group wins by accusing the
  /// Chameleon, who then guesses a word that is not the secret.
  Future<void> playToResult(
    WidgetTester tester, {
    required bool chameleonWins,
  }) async {
    final round = current;
    final chameleon = _seats.last;
    await revealAll(tester);
    for (var i = 0; i < crew.length; i++) {
      round.finishClue();
    }
    round.startVoting();
    final ballots = chameleonWins
        ? const [1, 0, 1, 0]
        : [
            for (var voter = 0; voter < crew.length; voter++)
              voter == chameleon ? (chameleon + 1) % crew.length : chameleon,
          ];
    for (final suspect in ballots) {
      round
        ..openPrivateView()
        ..castVote(suspect);
    }
    if (!chameleonWins) round.guessWord(topicPacks.first.words[0]);
    await tester.pumpAndSettle();
  }
}

Future<void> tapText(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}
