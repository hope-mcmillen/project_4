import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/app/theme.dart';
import 'package:project_4/features/game/screens/game_screen.dart';
import 'package:project_4/features/game/widgets/game_widgets.dart';

import 'player_view_test.dart' show createRepository;
import 'widget_test.dart' show tapText;

void main() {
  testWidgets(
    'another round repeats clues with the same roles and word before voting',
    (tester) async {
      final game = createRepository();
      expect(game.startAnotherClueRound, throwsStateError);
      for (var i = 0; i < 4; i++) {
        game.openPrivateView();
        game.finishReveal();
      }
      for (var i = 0; i < 4; i++) {
        game.openPrivateView();
        game.finishClue();
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: GameScreen(createGame: () => game),
        ),
      );
      for (var round = 0; round < 2; round++) {
        expect(find.text('Ready to vote'), findsOneWidget);
        await tapText(tester, 'Another Round');
        for (var player = 0; player < 4; player++) {
          expect(game.view.turn, player);
          expect(game.view.privateOpen, isFalse);
          expect(find.text('Sushi'), findsNothing);
          await tapText(tester, 'View my clue screen');
          expect(
            find.text(player == 0 ? 'Food & drink' : 'Sushi'),
            findsOneWidget,
          );
          expect(find.byType(TopicBoard), findsNothing);
          await tapText(
            tester,
            player == 3 ? 'Clue given · Discuss' : 'Clue given · Next player',
          );
        }
        expect(game.view.privateOpen, isFalse);
        expect(find.text('Another Round'), findsOneWidget);
      }
      await tapText(tester, 'Ready to vote');
      expect(find.text('Open my ballot'), findsOneWidget);
      expect(game.startAnotherClueRound, throwsStateError);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clue turns show only the player’s word or category privately', (
    tester,
  ) async {
    final game = createRepository();
    for (var i = 0; i < 4; i++) {
      game.openPrivateView();
      game.finishReveal();
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: GameScreen(createGame: () => game),
      ),
    );
    expect(game.finishClue, throwsStateError);
    expect(find.text('Sushi'), findsNothing);
    await tapText(tester, 'View my clue screen');
    expect(find.text('Food & drink'), findsOneWidget);
    expect(find.byType(TopicBoard), findsNothing);
    for (final word in game.view.topic.words) {
      expect(find.text(word), findsNothing);
    }
    await tapText(tester, 'Clue given · Next player');
    expect(game.view.roleWord, isNull);
    expect(find.text('Sushi'), findsNothing);
    await tapText(tester, 'View my clue screen');
    expect(find.text('Sushi'), findsOneWidget);
    expect(find.text('Food & drink'), findsNothing);
    expect(find.byType(TopicBoard), findsNothing);
    for (final word in game.view.topic.words.where((word) => word != 'Sushi')) {
      expect(find.text(word), findsNothing);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('Sushi'), findsNothing);
    expect(game.view.roleWord, isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tapText(tester, 'View my clue screen');
    await tapText(tester, 'Clue given · Next player');
    expect(find.text('Sushi'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
