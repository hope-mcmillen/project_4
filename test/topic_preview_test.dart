import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/app/theme.dart';
import 'package:project_4/features/game/data/topic_packs.dart';
import 'package:project_4/features/game/data/word_repository.dart';
import 'package:project_4/features/game/models/topic_pack.dart';
import 'package:project_4/features/game/screens/setup_screen.dart';
import 'package:project_4/features/game/screens/phases/clues_phase.dart';

class TestWordRepository implements WordRepository {
  TestWordRepository(this.load);
  final Future<List<TopicPack>> Function() load;
  @override
  Future<List<TopicPack>> getTopics() => load();
}

Future<void> openSetup(
  WidgetTester tester, {
  WordRepository? repository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: repository == null
          ? const SetupScreen()
          : SetupScreen(wordRepository: repository),
    ),
  );
  await tester.pump();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'preview shows all words and dismissal preserves the selected pack',
    (tester) async {
      await openSetup(tester);
      final animals = topicPacks.singleWhere((pack) => pack.id == 'animals');
      expect(find.text('Selected topic: Food & drink'), findsOneWidget);
      await tapText(tester, animals.name);
      expect(find.text('Take a peek'), findsOneWidget);
      for (final word in animals.words) {
        expect(find.text(word), findsOneWidget);
      }
      await tapText(tester, 'Keep browsing');
      expect(find.text('Selected topic: Food & drink'), findsOneWidget);
      expect(find.text('Take a peek'), findsNothing);
    },
  );

  testWidgets('choosing a previewed pack supplies that pack to the round', (
    tester,
  ) async {
    await openSetup(tester);
    await tapText(tester, 'Music room');
    await tapText(tester, 'Choose this topic');
    expect(find.text('Selected topic: Music room'), findsOneWidget);
    await tapText(tester, 'Deal secret roles');
    for (var i = 0; i < 4; i++) {
      await tapText(tester, 'Reveal my role');
      await tapText(tester, 'Hide & continue');
    }
    final clues = tester.widget<CluesPhase>(find.byType(CluesPhase));
    expect(clues.view.topic.name, 'Music room');
    expect(clues.view.topic.words, contains('Tambourine'));
    expect(find.text('View my clue screen'), findsOneWidget);
    expect(find.text('Pizza'), findsNothing);
  });

  testWidgets(
    'setup waits for an injected repository and handles an empty catalog',
    (tester) async {
      final pending = Completer<List<TopicPack>>();
      await openSetup(
        tester,
        repository: TestWordRepository(() => pending.future),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Deal secret roles'),
            )
            .onPressed,
        isNull,
      );
      pending.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('No topics are available yet.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Deal secret roles'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('repository failure can be retried without losing player names', (
    tester,
  ) async {
    var calls = 0;
    await openSetup(
      tester,
      repository: TestWordRepository(() async {
        if (calls++ == 0) throw Exception('Unavailable');
        return [topicPacks.last];
      }),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Jordan');
    expect(
      find.text('Couldn’t load topics. Please try again.'),
      findsOneWidget,
    );
    await tapText(tester, 'Try again');
    expect(find.text('Selected topic: Wild weather'), findsOneWidget);
    expect(find.text('Jordan'), findsOneWidget);
    expect(find.text('Food & drink'), findsNothing);
  });

  testWidgets('late repository completion after leaving setup is safe', (
    tester,
  ) async {
    final pending = Completer<List<TopicPack>>();
    await openSetup(
      tester,
      repository: TestWordRepository(() => pending.future),
    );
    await tester.pumpWidget(const SizedBox());
    pending.complete(topicPacks);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview and choose work on a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openSetup(tester);
    await tapText(tester, 'Getting around');
    await tapText(tester, 'Choose this topic');
    expect(find.text('Selected topic: Getting around'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
