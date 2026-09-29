import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/app/chameleon_app.dart';

// Trello CHM-14, second half: the host picks timers and a round limit on the
// setup screen, and the game dealt from there plays by them.
//
// Every test here starts from the app itself (home, "Start a game", the real
// setup screen with its default local topics) and reads the effect off the
// game that "Deal secret roles" opens. Nothing builds GameSettings or
// GameScreen by hand: that would re-test the first half, not the wiring.
//
// Countdowns run on flutter_test's fake clock: pump(duration) fires every
// timer due in that span, so nothing waits in real time.

const crew = ['Ana', 'Ben', 'Cal', 'Dee'];
const topic = 'Music room';

const gameOptions = 'Game options';
const clueGroup = 'Clue timer';
const discussionGroup = 'Discussion timer';
const roundsGroup = 'Rounds';
const defaultSummary = 'Clue off · Discussion off · Unlimited rounds';

const deal = 'Deal secret roles';
const second = Duration(seconds: 1);
const timeUp = 'Time’s up';
// Eyebrow upper-cases its text.
const gameOver = 'GAME OVER';
const playAgain = 'Play again · Same crew';
const changePlayers = 'Change players or topic';
const newGame = 'New game';

Future<void> tapText(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Home, then "Start a game": the setup screen as a player reaches it.
Future<void> openSetup(WidgetTester tester) async {
  await tester.pumpWidget(const ChameleonApp());
  await tapText(tester, 'Start a game');
  expect(find.text('Who’s playing?'), findsOneWidget);
}

/// Types the crew's names and chooses the topic, as a host would.
Future<void> fillPlayersAndTopic(WidgetTester tester) async {
  for (var i = 0; i < crew.length; i++) {
    await tester.enterText(find.byType(TextFormField).at(i), crew[i]);
  }
  await tapText(tester, topic);
  await tapText(tester, 'Choose this topic');
  expect(find.text('Selected topic: $topic'), findsOneWidget);
}

/// Unfolds the Game options section. Asserts it is there first, so a setup
/// screen without it fails here, on that, rather than somewhere downstream.
Future<void> openGameOptions(WidgetTester tester) async {
  expect(find.text(gameOptions), findsOneWidget);
  await tapText(tester, gameOptions);
}

/// The chip labelled [label] inside the control headed [group]. Both timers
/// offer the same labels, so a chip is only unambiguous within its group.
Finder optionChip(String group, String label) => find.descendant(
  // The nearest Column above a group's heading is that group's own.
  of: find.ancestor(of: find.text(group), matching: find.byType(Column)).first,
  matching: find.widgetWithText(ChoiceChip, label),
);

Future<void> choose(WidgetTester tester, String group, String label) async {
  final chip = optionChip(group, label);
  expect(chip, findsOneWidget);
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

bool isChosen(WidgetTester tester, String group, String label) =>
    tester.widget<ChoiceChip>(optionChip(group, label)).selected;

Future<void> revealRoles(WidgetTester tester) async {
  for (var i = 0; i < crew.length; i++) {
    await tapText(tester, 'Reveal my role');
    await tapText(tester, 'Hide & continue');
  }
}

String cluePrompt(String name) => '$name,\nyour one word?';

/// From the first clue turn to the discussion.
Future<void> giveClues(WidgetTester tester) async {
  for (var i = 0; i < crew.length - 1; i++) {
    await tapText(tester, 'Clue given · Next player');
  }
  await tapText(tester, 'Clue given · Discuss');
}

/// From the discussion to the result. Ana and Ben take two votes each: a tie,
/// so the Chameleon escapes whoever it is and no final guess is asked. The
/// Chameleon is random here, as in the app; nothing below depends on who.
Future<void> voteToTie(WidgetTester tester) async {
  await tapText(tester, 'Ready to vote');
  for (final suspect in ['Ben', 'Ana', 'Ben', 'Ana']) {
    await tapText(tester, 'Open my ballot');
    await tapText(tester, suspect);
    await tapText(tester, 'Confirm & hide vote');
  }
  expect(find.text('Master of disguise.\nChameleon wins!'), findsOneWidget);
}

Future<void> playRound(WidgetTester tester) async {
  await revealRoles(tester);
  await giveClues(tester);
  await voteToTie(tester);
}

void expectNoTimer() {
  expect(find.text('Clue time'), findsNothing);
  expect(find.text('Discussion time'), findsNothing);
  expect(find.text(timeUp), findsNothing);
}

/// A result the same crew can carry on from, as every result was before
/// round limits existed.
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

void main() {
  testWidgets('game options start folded above Deal, summarising defaults', (
    tester,
  ) async {
    await openSetup(tester);

    // Folded: the header and its summary show, none of the choices do.
    expect(find.text(gameOptions), findsOneWidget);
    expect(find.text(defaultSummary), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(
      tester.getTopLeft(find.text(gameOptions)).dy,
      lessThan(tester.getTopLeft(find.text(deal)).dy),
    );

    // Unfolded: three controls, four choices each, the defaults selected.
    await openGameOptions(tester);
    for (final (group, labels) in [
      (clueGroup, ['Off', '30 s', '60 s', '90 s']),
      (discussionGroup, ['Off', '30 s', '60 s', '90 s']),
      (roundsGroup, ['Unlimited', '3', '5', '10']),
    ]) {
      for (final label in labels) {
        expect(optionChip(group, label), findsOneWidget, reason: group);
        expect(
          isChosen(tester, group, label),
          label == 'Off' || label == 'Unlimited',
          reason: '$group: $label',
        );
      }
    }
    expect(find.byType(ChoiceChip), findsNWidgets(12));
  });

  testWidgets('the summary follows every choice, unfolded and folded', (
    tester,
  ) async {
    await openSetup(tester);
    await openGameOptions(tester);

    await choose(tester, clueGroup, '60 s');
    expect(
      find.text('Clue 60 s · Discussion off · Unlimited rounds'),
      findsOneWidget,
    );
    await choose(tester, discussionGroup, '90 s');
    expect(
      find.text('Clue 60 s · Discussion 90 s · Unlimited rounds'),
      findsOneWidget,
    );
    await choose(tester, roundsGroup, '5');
    expect(find.text('Clue 60 s · Discussion 90 s · 5 rounds'), findsOneWidget);

    // Folding hides the choices but keeps them, and says what they are.
    await tapText(tester, gameOptions);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Clue 60 s · Discussion 90 s · 5 rounds'), findsOneWidget);

    // And back to off, from the other direction.
    await openGameOptions(tester);
    expect(isChosen(tester, clueGroup, '60 s'), isTrue);
    await choose(tester, clueGroup, 'Off');
    await choose(tester, roundsGroup, 'Unlimited');
    expect(
      find.text('Clue off · Discussion 90 s · Unlimited rounds'),
      findsOneWidget,
    );
  });

  testWidgets('the timers chosen on setup run in the game it deals', (
    tester,
  ) async {
    await openSetup(tester);
    await fillPlayersAndTopic(tester);
    await openGameOptions(tester);
    // Different values, so a control that set the other timer shows up.
    await choose(tester, clueGroup, '30 s');
    await choose(tester, discussionGroup, '90 s');
    await tapText(tester, deal);

    // The rest of setup still reaches the game: names and topic.
    await revealRoles(tester);
    expect(find.text(cluePrompt('Ana')), findsOneWidget);
    expect(find.text('MUSIC ROOM'), findsOneWidget);

    // Clue turn: the clue timer, counting down, and nothing else.
    expect(find.text('Clue time'), findsOneWidget);
    expect(find.text('Discussion time'), findsNothing);
    expect(find.text('0:30'), findsOneWidget);
    await tester.pump(second);
    expect(find.text('0:29'), findsOneWidget);

    // Discussion: its own timer, from its own choice.
    await giveClues(tester);
    expect(find.text('Discussion time'), findsOneWidget);
    expect(find.text('Clue time'), findsNothing);
    expect(find.text('1:30'), findsOneWidget);
    await tester.pump(second);
    expect(find.text('1:29'), findsOneWidget);
  });

  testWidgets('the round limit chosen on setup ends the game it deals', (
    tester,
  ) async {
    await openSetup(tester);
    await fillPlayersAndTopic(tester);
    await openGameOptions(tester);
    await choose(tester, roundsGroup, '3');
    await tapText(tester, deal);

    await playRound(tester);
    expectRoundResult(rounds: 1);
    await tapText(tester, playAgain);
    await playRound(tester);
    expectRoundResult(rounds: 2);
    await tapText(tester, playAgain);

    // Exactly the third: a final winner, and only a new game from here.
    // Who wins depends on the random Chameleons, so only the shape is read.
    await playRound(tester);
    expect(find.text(gameOver), findsOneWidget);
    expect(find.textContaining('after 3 rounds'), findsOneWidget);
    expect(find.text(newGame), findsOneWidget);
    expect(find.text(playAgain), findsNothing);
    expect(find.text(changePlayers), findsNothing);

    // New game returns to setup with the limit still chosen.
    await tapText(tester, newGame);
    expect(find.text('Who’s playing?'), findsOneWidget);
    expect(find.text('Clue off · Discussion off · 3 rounds'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('untouched options deal the game as it was before them', (
    tester,
  ) async {
    await openSetup(tester);
    await fillPlayersAndTopic(tester);
    await tapText(tester, deal);

    // Three rounds, so a default that quietly set the shortest limit (3)
    // would end the game here instead of offering Play again.
    for (var round = 1; round <= 3; round++) {
      await revealRoles(tester);
      for (var i = 0; i < crew.length; i++) {
        expectNoTimer();
        await tester.pump(const Duration(minutes: 5));
        expectNoTimer();
        await tapText(
          tester,
          i == crew.length - 1
              ? 'Clue given · Discuss'
              : 'Clue given · Next player',
        );
      }
      expect(find.text('Ready to vote'), findsOneWidget);
      expectNoTimer();
      await tester.pump(const Duration(minutes: 5));
      expectNoTimer();
      await voteToTie(tester);
      expectRoundResult(rounds: round);
      if (round < 3) await tapText(tester, playAgain);
    }
  });

  testWidgets('choices survive a game and a return to setup', (tester) async {
    await openSetup(tester);
    await fillPlayersAndTopic(tester);
    await openGameOptions(tester);
    await choose(tester, clueGroup, '60 s');
    await choose(tester, roundsGroup, '5');
    await tapText(tester, deal);

    await revealRoles(tester);
    expect(find.text('1:00'), findsOneWidget);
    await giveClues(tester);
    await voteToTie(tester);
    await tapText(tester, changePlayers);

    // Back on setup: the choices are still the ones made, like the names
    // and the topic beside them.
    expect(find.text('Who’s playing?'), findsOneWidget);
    expect(find.text('Clue 60 s · Discussion off · 5 rounds'), findsOneWidget);
    expect(find.text('Selected topic: $topic'), findsOneWidget);

    // And the next game dealt from here plays by them again.
    await tapText(tester, deal);
    await revealRoles(tester);
    expect(find.text(cluePrompt('Ana')), findsOneWidget);
    expect(find.text('Clue time'), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
    await tester.pump(second);
    expect(find.text('0:59'), findsOneWidget);
  });

  testWidgets('game options fit a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openSetup(tester);
    await openGameOptions(tester);
    await choose(tester, clueGroup, '90 s');
    await choose(tester, discussionGroup, '60 s');
    await choose(tester, roundsGroup, '10');
    await tapText(tester, gameOptions);
    expect(
      find.text('Clue 90 s · Discussion 60 s · 10 rounds'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
