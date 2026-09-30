import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/features/game/models/game_settings.dart';

import 'support/game_host.dart';

// CHM-17: on the last round the game's ending is the first thing on the
// results screen, above the round's own result. Each game is played to the
// round limit through the real GameScreen, as round_limit_test.dart does.

// Eyebrow upper-cases its text.
const gameOver = 'GAME OVER';
const secretIsOut = 'THE SECRET IS OUT';
const chameleonWinsHeadline = 'Master of disguise.\nChameleon wins!';
const playAgain = 'Play again · Same crew';

/// A phone: 360 x 640 logical pixels.
void usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

double top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('the final winner comes above the round result', (tester) async {
    usePhone(tester);
    final host = GameHost(settings: GameSettings(roundLimit: 2));
    await host.start(tester);
    await host.playToResult(tester, chameleonWins: true);
    await tapText(tester, playAgain);
    await host.playToResult(tester, chameleonWins: true);

    // Straight after the last round: nothing scrolled.
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).last,
    );
    expect(scrollable.position.pixels, 0);
    expect(find.text('Player 1 wins!'), findsOneWidget);
    expect(find.text('4 pts after 2 rounds'), findsOneWidget);

    // The whole final card, headline and score line included, sits above the
    // round's own result and above its first line.
    final finalCardBottom = tester
        .getBottomLeft(find.text('4 pts after 2 rounds'))
        .dy;
    expect(top(tester, gameOver), lessThan(top(tester, 'Player 1 wins!')));
    expect(finalCardBottom, lessThan(top(tester, secretIsOut)));
    expect(finalCardBottom, lessThan(top(tester, chameleonWinsHeadline)));

    // On a phone the ending is on screen without scrolling; the round
    // result is still there below it.
    const screen = Rect.fromLTWH(0, 0, 360, 640);
    expect(screen.contains(tester.getTopLeft(find.text(gameOver))), isTrue);
    expect(
      screen.contains(tester.getBottomLeft(find.text('Player 1 wins!'))),
      isTrue,
    );
    expect(
      screen.contains(tester.getBottomLeft(find.text('4 pts after 2 rounds'))),
      isTrue,
    );
    expect(find.text(chameleonWinsHeadline), findsOneWidget);

    // The rest follows in the order it always had.
    expect(
      top(tester, secretIsOut),
      lessThan(top(tester, 'HOW THE VOTES LANDED')),
    );
    expect(
      top(tester, 'HOW THE VOTES LANDED'),
      lessThan(top(tester, 'RUNNING SCORE')),
    );
    expect(find.text('New game'), findsOneWidget);
  });

  testWidgets('a round that is not the last starts with its own result', (
    tester,
  ) async {
    usePhone(tester);
    final host = GameHost(settings: GameSettings(roundLimit: 2));
    await host.start(tester);
    await host.playToResult(tester, chameleonWins: true);

    // No final card at all, and the screen opens on the round result, first.
    expect(find.text(gameOver), findsNothing);
    expect(find.text(playAgain), findsOneWidget);
    final first = top(tester, secretIsOut);
    for (final later in [
      chameleonWinsHeadline,
      'HOW THE VOTES LANDED',
      'RUNNING SCORE',
    ]) {
      expect(first, lessThan(top(tester, later)), reason: later);
    }
  });

  testWidgets('a game with no round limit never shows the final card', (
    tester,
  ) async {
    usePhone(tester);
    final host = GameHost();
    await host.start(tester);
    for (var round = 1; round <= 3; round++) {
      await host.playToResult(tester, chameleonWins: true);
      expect(find.text(gameOver), findsNothing);
      expect(find.text(playAgain), findsOneWidget);
      await tapText(tester, playAgain);
    }
  });
}
