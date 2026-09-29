import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/features/game/models/game_settings.dart';

import 'support/game_host.dart';

// Eyebrow upper-cases its text.
const gameOver = 'GAME OVER';
const playAgain = 'Play again · Same crew';
const changePlayers = 'Change players or topic';
const newGame = 'New game';

/// A result screen that lets the same crew carry on, as every result did
/// before round limits existed.
void expectRoundResult({required int rounds}) {
  expect(find.text(playAgain), findsOneWidget);
  expect(find.text(changePlayers), findsOneWidget);
  expect(find.text(gameOver), findsNothing);
  expect(find.text(newGame), findsNothing);
  expect(
    find.text(rounds == 1 ? 'After 1 round' : 'After $rounds rounds'),
    findsOneWidget,
  );
}

/// The last result of a limited game: a final winner and only "New game".
void expectFinalResult({required String headline, required String detail}) {
  expect(find.text(gameOver), findsOneWidget);
  expect(find.text(headline), findsOneWidget);
  expect(find.text(detail), findsOneWidget);
  expect(find.text(newGame), findsOneWidget);
  expect(find.text(playAgain), findsNothing);
  expect(find.text(changePlayers), findsNothing);
}

void main() {
  testWidgets('the final result comes on exactly the Nth round', (
    tester,
  ) async {
    // Player 1 is the Chameleon every round and wins every round: +2 each.
    final host = GameHost(settings: GameSettings(roundLimit: 3));
    await host.start(tester);

    await host.playToResult(tester, chameleonWins: true);
    expectRoundResult(rounds: 1);
    await tapText(tester, playAgain);

    await host.playToResult(tester, chameleonWins: true);
    expectRoundResult(rounds: 2);
    await tapText(tester, playAgain);

    await host.playToResult(tester, chameleonWins: true);
    expectFinalResult(
      headline: 'Player 1 wins!',
      detail: '6 pts after 3 rounds',
    );
    expect(host.roundsBuilt, 3);
  });

  testWidgets('the final winner is the top scorer, not the last round winner', (
    tester,
  ) async {
    // Round 1: Player 1 escapes as the Chameleon (+2). Round 2: the group
    // catches Player 2, so everyone else scores 1: Player 1 ends on 3.
    final host = GameHost(
      settings: GameSettings(roundLimit: 2),
      chameleonSeats: [0, 1],
    );
    await host.start(tester);
    await host.playToResult(tester, chameleonWins: true);
    expectRoundResult(rounds: 1);
    await tapText(tester, playAgain);
    await host.playToResult(tester, chameleonWins: false);

    expectFinalResult(
      headline: 'Player 1 wins!',
      detail: '3 pts after 2 rounds',
    );
  });

  testWidgets('co-winners share the win on a tie', (tester) async {
    // Player 1 then Player 2 escape as the Chameleon: 2 points each.
    final host = GameHost(
      settings: GameSettings(roundLimit: 2),
      chameleonSeats: [0, 1],
    );
    await host.start(tester);
    await host.playToResult(tester, chameleonWins: true);
    expectRoundResult(rounds: 1);
    await tapText(tester, playAgain);
    await host.playToResult(tester, chameleonWins: true);

    expectFinalResult(
      headline: 'Player 1 & Player 2 share the win!',
      detail: '2 pts after 2 rounds',
    );
  });

  testWidgets('a three-way tie names all three, in seat order', (tester) async {
    // One round: the group catches Player 1, so the other three score 1.
    final host = GameHost(settings: GameSettings(roundLimit: 1));
    await host.start(tester);
    await host.playToResult(tester, chameleonWins: false);

    expectFinalResult(
      headline: 'Player 2, Player 3 & Player 4 share the win!',
      detail: '1 pt after 1 round',
    );
  });

  testWidgets('New game goes back to setup and the next game starts at zero', (
    tester,
  ) async {
    final host = GameHost(settings: GameSettings(roundLimit: 2));
    await host.start(tester);
    await host.playToResult(tester, chameleonWins: true);
    expectRoundResult(rounds: 1);
    await tapText(tester, playAgain);
    await host.playToResult(tester, chameleonWins: true);
    expect(find.text(gameOver), findsOneWidget);

    await tapText(tester, newGame);
    expect(find.text(startLabel), findsOneWidget);
    expect(host.roundsBuilt, 2);

    // A fresh game: its first result is round 1 of 2 again, not a third
    // round of a game that is already over.
    await tapText(tester, startLabel);
    await host.playToResult(tester, chameleonWins: true);
    expectRoundResult(rounds: 1);
    expect(find.text('2 pts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a limit every result offers Play again', (tester) async {
    final host = GameHost(); // GameScreen built without settings.
    await host.start(tester);
    for (var round = 1; round <= 4; round++) {
      await host.playToResult(tester, chameleonWins: round.isEven);
      expectRoundResult(rounds: round);
      if (round < 4) await tapText(tester, playAgain);
    }
  });
}
