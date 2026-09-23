import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/app/chameleon_app.dart';

Future<void> tapText(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> startGame(WidgetTester tester) async {
  await tester.pumpWidget(const ChameleonApp());
  await tapText(tester, 'Start a game');
  await tapText(tester, 'Deal secret roles');
}

void main() {
  testWidgets('home and rules explain the local game', (tester) async {
    await tester.pumpWidget(const ChameleonApp());
    expect(find.text('chameleon'), findsOneWidget);
    expect(find.text('3–8 players'), findsOneWidget);
    await tapText(tester, 'How to play');
    expect(find.text('Everyone knows.\nExcept one of you.'), findsOneWidget);
  });

  testWidgets('setup rejects duplicate and empty names', (tester) async {
    await tester.pumpWidget(const ChameleonApp());
    await tapText(tester, 'Start a game');
    await tester.enterText(find.byType(TextFormField).at(0), 'Player 2');
    await tester.enterText(find.byType(TextFormField).at(2), '');
    await tapText(tester, 'Deal secret roles');
    expect(find.text('Each player needs a different name.'), findsNWidgets(2));
    expect(find.text('Enter a name.'), findsOneWidget);
    expect(find.text('Reveal my role'), findsNothing);
  });

  testWidgets('role hides on backgrounding and before leaving', (tester) async {
    await startGame(tester);
    await tapText(tester, 'Reveal my role');
    expect(find.text('Hide & continue'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('Hide & continue'), findsNothing);
    expect(find.text('Reveal my role'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tapText(tester, 'Reveal my role');
    await tester.tap(find.byTooltip('Leave round'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this round?'), findsOneWidget);
    expect(find.text('Hide & continue'), findsNothing);
    await tapText(tester, 'Keep playing');
    expect(find.text('Reveal my role'), findsOneWidget);
    await tester.tap(find.byTooltip('Leave round'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Leave round');
    expect(find.text('Who’s playing?'), findsOneWidget);
  });

  testWidgets('full round at phone width: reveal, clues, tie, replay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await startGame(tester);
    for (var i = 1; i <= 4; i++) {
      expect(find.text('Player $i'), findsOneWidget);
      await tapText(tester, 'Reveal my role');
      await tapText(tester, 'Hide & continue');
      expect(find.text('Hide & continue'), findsNothing);
    }
    for (var i = 0; i < 3; i++) {
      await tapText(tester, 'Clue given · Next player');
    }
    await tapText(tester, 'Clue given · Discuss');
    await tapText(tester, 'Ready to vote');
    for (final suspect in ['Player 2', 'Player 1', 'Player 2', 'Player 1']) {
      await tapText(tester, 'Open my ballot');
      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirm & hide vote'),
      );
      expect(confirm.onPressed, isNull);
      await tapText(tester, suspect);
      await tapText(tester, 'Confirm & hide vote');
    }
    expect(find.text('Master of disguise.\nChameleon wins!'), findsOneWidget);
    await tapText(tester, 'Play again · Same crew');
    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Reveal my role'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small phone and large text remain scrollable', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await startGame(tester);
    await tapText(tester, 'Reveal my role');
    expect(tester.takeException(), isNull);
  });
}
