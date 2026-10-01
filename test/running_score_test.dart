import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/app/chameleon_app.dart';
import 'package:project_4/features/game/data/topic_packs.dart';
import 'package:project_4/features/game/logic/game_repository.dart';
import 'package:project_4/features/game/models/game_phase.dart';
import 'package:project_4/features/game/models/player_view.dart';
import 'package:project_4/features/game/screens/game_screen.dart';
import 'package:project_4/features/game/widgets/game_widgets.dart';
import 'package:project_4/features/game/widgets/role_cards.dart';

// The setup screen's default crew.
const crew = ['Player 1', 'Player 2', 'Player 3', 'Player 4'];

// Eyebrow upper-cases its text.
const scoreHeading = 'RUNNING SCORE';

Future<void> tapText(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Plays one round through the real UI and returns the Chameleon's name.
///
/// Roles are random in the app, so the test learns them the way a player
/// would: by looking at each private reveal.
Future<String> playRound(
  WidgetTester tester, {
  required bool groupWins,
  int extraClueLaps = 0,
}) async {
  String? chameleon;
  String? secret;
  for (final name in crew) {
    expect(find.text(name), findsOneWidget);
    expect(find.text(scoreHeading), findsNothing);
    await tapText(tester, 'Reveal my role');
    expect(find.text(scoreHeading), findsNothing);
    if (find.byType(ChameleonCard).evaluate().isNotEmpty) {
      chameleon = name;
    } else {
      secret = tester.widget<InsiderCard>(find.byType(InsiderCard)).word;
    }
    await tapText(tester, 'Hide & continue');
  }
  // Since the UI rewrite each player opens a clue screen before giving a clue.
  // "Another Round" starts one more lap with the same roles; it must not score.
  for (var lap = 0; lap <= extraClueLaps; lap++) {
    if (lap > 0) {
      expect(find.text(scoreHeading), findsNothing);
      await tapText(tester, 'Another Round');
    }
    for (var i = 0; i < crew.length; i++) {
      expect(find.text(scoreHeading), findsNothing);
      await tapText(tester, 'View my clue screen');
      expect(find.text(scoreHeading), findsNothing);
      await tapText(
        tester,
        i == crew.length - 1
            ? 'Clue given · Discuss'
            : 'Clue given · Next player',
      );
    }
  }
  expect(find.text(scoreHeading), findsNothing);
  await tapText(tester, 'Ready to vote');

  // A tie always lets the Chameleon slip away. For a group win, everyone
  // else accuses the Chameleon, who then guesses a word that is not secret.
  final ballots = groupWins
      ? [
          for (final voter in crew)
            voter == chameleon
                ? crew.firstWhere((name) => name != voter)
                : chameleon!,
        ]
      : ['Player 2', 'Player 1', 'Player 2', 'Player 1'];
  for (final suspect in ballots) {
    expect(find.text(scoreHeading), findsNothing);
    await tapText(tester, 'Open my ballot');
    expect(find.text(scoreHeading), findsNothing);
    await tapText(tester, suspect);
    await tapText(tester, 'Confirm & hide vote');
  }
  if (groupWins) {
    expect(find.text(scoreHeading), findsNothing);
    final board = tester.widget<TopicBoard>(find.byType(TopicBoard));
    await tapText(tester, board.topic.words.firstWhere((w) => w != secret));
    await tapText(tester, 'Lock in final guess');
    expect(find.text('Good instincts.\nThe group wins!'), findsOneWidget);
  } else {
    expect(find.text('Master of disguise.\nChameleon wins!'), findsOneWidget);
  }
  expect(find.text('Chameleon: $chameleon'), findsOneWidget);
  return chameleon!;
}

String pointsLabel(int points) => points == 1 ? '1 pt' : '$points pts';

void expectStandings(Map<String, int> expected, {required int rounds}) {
  expect(find.text(scoreHeading), findsOneWidget);
  expect(
    find.text(rounds == 1 ? 'After 1 round' : 'After $rounds rounds'),
    findsOneWidget,
  );
  for (final MapEntry(key: name, value: points) in expected.entries) {
    expect(
      find.descendant(
        of: find.byKey(ValueKey('standing-$name')),
        matching: find.text(pointsLabel(points)),
      ),
      findsOneWidget,
      reason: '$name should show ${pointsLabel(points)}',
    );
  }
}

/// A round that is already decided and whose owner keeps re-announcing it,
/// as a server-backed repository may. The local one never re-notifies at
/// the result, so only a stand-in can show that a repeat is not rescored.
class _RepeatingRound extends ChangeNotifier implements GameRepository {
  bool _over = false;

  void finish() {
    _over = true;
    notifyListeners();
  }

  void announceAgain() => notifyListeners();

  @override
  PlayerView get view => PlayerView(
    players: crew,
    topic: topicPacks.first,
    phase: _over ? GamePhase.result : GamePhase.discussion,
    turn: 0,
    viewerIndex: 0,
    privateOpen: false,
    chameleonName: _over ? 'Player 3' : null,
    secretWord: _over ? topicPacks.first.words.first : null,
    winner: _over ? RoundWinner.chameleon : null,
    resultReason: _over ? 'The vote was tied.' : null,
    voteCounts: _over ? const {0: 2, 1: 2, 2: 0, 3: 0} : const {},
  );

  @override
  void openPrivateView() {}
  @override
  void hidePrivateView() {}
  @override
  void finishReveal() {}
  @override
  void finishClue() {}
  @override
  void startAnotherClueRound() {}
  @override
  void startVoting() {}
  @override
  void castVote(int suspect) {}
  @override
  void guessWord(String word) {}
}

void main() {
  testWidgets(
    'running score includes each result, survives replay, resets on leaving',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ChameleonApp());
      await tapText(tester, 'Start a game');
      await tapText(tester, 'Deal secret roles');

      // Round 1: the Chameleon wins. The result already counts it.
      final expected = {for (final name in crew) name: 0};
      final first = await playRound(tester, groupWins: false);
      expected[first] = expected[first]! + 2;
      expectStandings(expected, rounds: 1);

      // Round 2, same crew: the group wins. Replay must neither drop round 1
      // nor count it a second time.
      await tapText(tester, 'Play again · Same crew');
      // It also takes an extra clue lap, which must not count as a round.
      final second = await playRound(tester, groupWins: true, extraClueLaps: 1);
      for (final name in crew) {
        if (name != second) expected[name] = expected[name]! + 1;
      }
      expectStandings(expected, rounds: 2);

      // Leaving for setup ends the session, even with the same names.
      await tapText(tester, 'Change players or topic');
      expect(find.text('Who’s playing?'), findsOneWidget);
      await tapText(tester, 'Deal secret roles');
      final third = await playRound(tester, groupWins: false);
      expectStandings({
        for (final name in crew) name: name == third ? 2 : 0,
      }, rounds: 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a finished round is scored once however often it is announced', (
    tester,
  ) async {
    final round = _RepeatingRound();
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(createGame: () => round)),
    );
    expect(find.text(scoreHeading), findsNothing);

    round.finish();
    await tester.pumpAndSettle();
    expectStandings({
      'Player 1': 0,
      'Player 2': 0,
      'Player 3': 2,
      'Player 4': 0,
    }, rounds: 1);

    for (var i = 0; i < 3; i++) {
      round.announceAgain();
      await tester.pumpAndSettle();
    }
    expectStandings({
      'Player 1': 0,
      'Player 2': 0,
      'Player 3': 2,
      'Player 4': 0,
    }, rounds: 1);
  });
}
