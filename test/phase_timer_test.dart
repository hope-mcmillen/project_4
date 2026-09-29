import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/features/game/data/topic_packs.dart';
import 'package:project_4/features/game/logic/game_repository.dart';
import 'package:project_4/features/game/models/game_phase.dart';
import 'package:project_4/features/game/models/game_settings.dart';
import 'package:project_4/features/game/models/player_view.dart';
import 'package:project_4/features/game/screens/game_screen.dart';

import 'support/game_host.dart';

// All countdowns are driven with flutter_test's fake clock: pump(duration)
// fires every timer due in that span, so nothing here waits in real time.

const second = Duration(seconds: 1);
const timeUp = 'Time’s up';

String cluePrompt(String name) => '$name,\nyour one word?';

FilledButton button(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

void expectNoTimer() {
  expect(find.text('Clue time'), findsNothing);
  expect(find.text('Discussion time'), findsNothing);
  expect(find.text(timeUp), findsNothing);
}

/// Holds one clue turn or the discussion and can announce it again unchanged.
class _Reannouncing extends ChangeNotifier implements GameRepository {
  _Reannouncing(this.phase);
  final GamePhase phase;

  void announceAgain() => notifyListeners();

  @override
  PlayerView get view => PlayerView(
    players: crew,
    topic: topicPacks.first,
    phase: phase,
    turn: 0,
    viewerIndex: 0,
    privateOpen: phase == GamePhase.clues,
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
  void startVoting() {}
  @override
  void startAnotherClueRound() {}
  @override
  void castVote(int suspect) {}
  @override
  void guessWord(String word) {}
}

void main() {
  testWidgets('the clue timer counts down by the second and says time is up', (
    tester,
  ) async {
    final host = GameHost(
      settings: GameSettings(clueTime: const Duration(seconds: 30)),
    );
    await host.start(tester);
    await host.revealAll(tester);

    expect(find.text(cluePrompt('Player 1')), findsOneWidget);
    expect(find.text('Clue time'), findsOneWidget);
    expect(find.text('0:30'), findsOneWidget);

    await tester.pump(second);
    expect(find.text('0:29'), findsOneWidget);

    await tester.pump(second * 28);
    expect(find.text('0:01'), findsOneWidget);
    expect(find.text(timeUp), findsNothing);

    await tester.pump(second);
    expect(find.text(timeUp), findsOneWidget);
    expect(find.text('0:00'), findsNothing);
  });

  testWidgets('time up neither advances the game nor blocks its button', (
    tester,
  ) async {
    final host = GameHost(
      settings: GameSettings(clueTime: const Duration(seconds: 30)),
    );
    await host.start(tester);
    await host.revealAll(tester);
    expect(button(tester, 'Clue given · Next player').onPressed, isNotNull);

    // At zero, and long past it, the same player still holds the floor.
    // Checked before "time's up" so a timer that moved the game on fails
    // here, on the thing it got wrong.
    await tester.pump(second * 30);
    expect(host.current.view.turn, 0);
    expect(find.text(cluePrompt('Player 1')), findsOneWidget);
    expect(find.text(timeUp), findsOneWidget);
    await tester.pump(const Duration(minutes: 10));
    expect(host.current.view.phase, GamePhase.clues);
    expect(host.current.view.turn, 0);
    expect(find.text(cluePrompt('Player 1')), findsOneWidget);
    expect(find.text(timeUp), findsOneWidget);

    // Moving on is still the players' call, and still works.
    expect(button(tester, 'Clue given · Next player').onPressed, isNotNull);
    await nextClue(tester);
    expect(find.text(cluePrompt('Player 2')), findsOneWidget);
  });

  testWidgets('every clue turn starts the clue timer again from full', (
    tester,
  ) async {
    final host = GameHost(
      settings: GameSettings(clueTime: const Duration(seconds: 30)),
    );
    await host.start(tester);
    await host.revealAll(tester);

    // Player 1 moves on with time left: Player 2 does not inherit the rest.
    await tester.pump(second * 20);
    expect(find.text('0:10'), findsOneWidget);
    await nextClue(tester);
    expect(find.text(cluePrompt('Player 2')), findsOneWidget);
    expect(find.text('0:30'), findsOneWidget);
    await tester.pump(second);
    expect(find.text('0:29'), findsOneWidget);

    // Player 2 runs out: Player 3 still gets the full time.
    await tester.pump(second * 29);
    expect(find.text(timeUp), findsOneWidget);
    await nextClue(tester);
    expect(find.text(cluePrompt('Player 3')), findsOneWidget);
    expect(find.text(timeUp), findsNothing);
    expect(find.text('0:30'), findsOneWidget);
  });

  testWidgets('discussion runs its own timer once, apart from the clues', (
    tester,
  ) async {
    // Clues off, discussion on: each is set independently.
    final host = GameHost(
      settings: GameSettings(discussionTime: const Duration(seconds: 90)),
    );
    await host.start(tester);
    await host.revealAll(tester);
    for (var i = 0; i < crew.length - 1; i++) {
      expectNoTimer();
      await nextClue(tester);
    }
    expectNoTimer();
    await tester.pump(const Duration(minutes: 5));
    await tapText(tester, 'Clue given · Discuss');

    expect(find.text('Discussion time'), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);
    await tester.pump(second * 30);
    expect(find.text('1:00'), findsOneWidget);
    await tester.pump(second * 59);
    expect(find.text('0:01'), findsOneWidget);

    // Advisory here too: at zero and after, still discussing, and voting
    // still opens when the players choose.
    await tester.pump(second);
    expect(host.current.view.phase, GamePhase.discussion);
    expect(find.text(timeUp), findsOneWidget);
    await tester.pump(const Duration(minutes: 10));
    expect(host.current.view.phase, GamePhase.discussion);
    expect(button(tester, 'Ready to vote').onPressed, isNotNull);
    await tapText(tester, 'Ready to vote');
    expect(host.current.view.phase, GamePhase.voting);
    expectNoTimer();
  });

  // A repository may announce the same state again (running_score_test
  // stands in for a server-backed one that does); the local one never does
  // mid-phase, so only a stand-in can show that a rebuild of the same turn
  // or phase does not restart its timer.
  for (final phase in [GamePhase.clues, GamePhase.discussion]) {
    testWidgets('re-announcing the same ${phase.name} keeps its countdown', (
      tester,
    ) async {
      final round = _Reannouncing(phase);
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            settings: GameSettings(
              clueTime: const Duration(seconds: 60),
              discussionTime: const Duration(seconds: 60),
            ),
            createGame: () => round,
          ),
        ),
      );
      await tester.pump(second * 10);
      expect(find.text('0:50'), findsOneWidget);

      round.announceAgain();
      await tester.pump();
      expect(find.text('0:50'), findsOneWidget);
      await tester.pump(second);
      expect(find.text('0:49'), findsOneWidget);
    });
  }

  testWidgets('a timer stops when its screen goes away', (tester) async {
    // Clues on, discussion off.
    final host = GameHost(
      settings: GameSettings(clueTime: const Duration(seconds: 30)),
    );
    await host.start(tester);
    await host.revealAll(tester);
    for (var i = 0; i < crew.length - 1; i++) {
      await tester.pump(second * 10);
      await nextClue(tester);
    }

    // The last clue ends with time left. That countdown must not carry on
    // into discussion, which has no timer of its own.
    await tester.pump(second * 10);
    expect(find.text('0:20'), findsOneWidget);
    await tapText(tester, 'Clue given · Discuss');
    expect(host.current.view.phase, GamePhase.discussion);
    expectNoTimer();
    await tester.pump(const Duration(minutes: 2));
    expectNoTimer();
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving mid-clue stops the clue timer', (tester) async {
    final host = GameHost(
      settings: GameSettings(clueTime: const Duration(seconds: 30)),
    );
    await host.start(tester);
    await host.revealAll(tester);
    await tester.pump(second * 5);
    expect(find.text('0:25'), findsOneWidget);

    await tester.tap(find.byTooltip('Leave round'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Leave round');
    expect(find.text(startLabel), findsOneWidget);

    // Well past when the abandoned countdown would have ticked and finished.
    await tester.pump(const Duration(minutes: 2));
    expect(find.text(startLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timers stay out of private screens and leave backgrounding be', (
    tester,
  ) async {
    final host = GameHost(
      settings: GameSettings(
        clueTime: const Duration(seconds: 30),
        discussionTime: const Duration(seconds: 30),
      ),
    );
    await host.start(tester);

    // Reveal: no timer, and backgrounding still hides an open role.
    expectNoTimer();
    await tapText(tester, 'Reveal my role');
    expectNoTimer();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('Hide & continue'), findsNothing);
    expect(find.text('Reveal my role'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // Clues: backgrounding hides the private clue screen like any other, so
    // the countdown leaves with it and starts fresh when it is reopened.
    await host.revealAll(tester);
    await tester.pump(second * 5);
    expect(find.text('0:25'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expectNoTimer();
    await tapText(tester, 'View my clue screen');
    expect(find.text('0:30'), findsOneWidget);

    // Voting: no timer on the ballot screens either.
    for (var i = 0; i < crew.length; i++) {
      if (i > 0) host.current.openPrivateView();
      host.current.finishClue();
    }
    host.current.startVoting();
    await tester.pumpAndSettle();
    expectNoTimer();
    await tapText(tester, 'Open my ballot');
    expectNoTimer();
  });

  testWidgets('default settings show no timer anywhere in the round', (
    tester,
  ) async {
    final host = GameHost(); // GameScreen built without settings.
    await host.start(tester);
    expectNoTimer();
    await host.revealAll(tester);
    for (var i = 0; i < crew.length; i++) {
      expectNoTimer();
      await tester.pump(const Duration(minutes: 5));
      expectNoTimer();
      host.current.finishClue();
      await tester.pumpAndSettle();
      if (i < crew.length - 1) {
        host.current.openPrivateView();
        await tester.pumpAndSettle();
      }
    }
    expect(host.current.view.phase, GamePhase.discussion);
    expectNoTimer();
    await tester.pump(const Duration(minutes: 5));
    expectNoTimer();
  });
}
