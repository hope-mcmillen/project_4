import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/app/theme.dart';
import 'package:project_4/features/game/models/game_settings.dart';
import 'package:project_4/features/game/widgets/game_widgets.dart';
import 'package:project_4/features/game/widgets/phase_timer.dart';

import 'support/game_host.dart';
import 'support/semantics_probe.dart';

// CHM-17: the timer for a screen reader, and at large text.
//
// Speech is judged from the accessibility tree (tester.ensureSemantics),
// never from widget fields. Countdowns run on flutter_test's fake clock.

const second = Duration(seconds: 1);
const timeUp = 'Time’s up';

/// The one node that speaks for the timer named [label], or fails.
Spoken timerNode(WidgetTester tester, String label) {
  final nodes = spokenNodes(tester)
      .where((n) => n.label.contains(label))
      .toList();
  expect(nodes, hasLength(1), reason: 'nodes naming "$label": $nodes');
  return nodes.single;
}

/// The timer alone on a phone-width page, padded as every game screen is.
Widget timerPage(Duration duration) => MaterialApp(
  theme: buildTheme(),
  home: Scaffold(
    body: PageBody(
      children: [PhaseTimer(label: 'Clue time', duration: duration)],
    ),
  ),
);

void useView(WidgetTester tester, {required double width, double scale = 1}) {
  tester.view.physicalSize = Size(width, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  group('a screen reader hears the timer', () {
    testWidgets('the remaining time is spoken in words, not as a clock', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(timerPage(const Duration(seconds: 61)));

      expect(
        timerNode(tester, 'Clue time').label,
        'Clue time, 1 minute 1 second left',
      );
      // The visible clock is not what is read out.
      expect(spokenNodes(tester).where((n) => n.label.contains(':')), isEmpty);

      await tester.pump(second);
      expect(timerNode(tester, 'Clue time').label, 'Clue time, 1 minute left');
      await tester.pump(second);
      expect(
        timerNode(tester, 'Clue time').label,
        'Clue time, 59 seconds left',
      );
      await tester.pump(second * 58);
      expect(timerNode(tester, 'Clue time').label, 'Clue time, 1 second left');
      semantics.dispose();
    });

    testWidgets('in a game, 30 seconds reads as "30 seconds left"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final host = GameHost(
        settings: GameSettings(clueTime: const Duration(seconds: 30)),
      );
      await host.start(tester);
      await host.revealAll(tester);

      expect(find.text('0:30'), findsOneWidget);
      expect(
        timerNode(tester, 'Clue time').label,
        'Clue time, 30 seconds left',
      );
      await tester.pump(second);
      expect(
        timerNode(tester, 'Clue time').label,
        'Clue time, 29 seconds left',
      );
      semantics.dispose();
    });

    testWidgets('time up is announced exactly once, and no tick is', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(timerPage(const Duration(seconds: 30)));
      final log = AnnouncementLog(tester);

      // Twenty-nine ticks, each a new label, none of them announced.
      await log.pumpSeconds(29);
      expect(timerNode(tester, 'Clue time').label, contains('1 second left'));
      expect(log.announced, isEmpty);
      expect(timerNode(tester, 'Clue time').isLiveRegion, isFalse);

      // Zero: the one announcement, and it says time is up.
      await log.pumpSeconds(1);
      expect(find.text(timeUp), findsOneWidget);
      expect(log.announced, hasLength(1));
      expect(log.announced.single, contains(timeUp));
      expect(timerNode(tester, 'Clue time').isLiveRegion, isTrue);

      // Long after, nothing more is said.
      await log.pumpSeconds(5);
      await tester.pump(const Duration(minutes: 10));
      log.sample();
      expect(log.announced, hasLength(1));
      semantics.dispose();
    });

    testWidgets('each new clue turn starts silent again', (tester) async {
      final semantics = tester.ensureSemantics();
      final host = GameHost(
        settings: GameSettings(clueTime: const Duration(seconds: 30)),
      );
      await host.start(tester);
      await host.revealAll(tester);
      final log = AnnouncementLog(tester);

      await log.pumpSeconds(30);
      expect(log.announced, hasLength(1));
      await nextClue(tester);
      log.sample();

      // A fresh turn: full time, not live, nothing further announced.
      expect(
        timerNode(tester, 'Clue time').label,
        'Clue time, 30 seconds left',
      );
      await log.pumpSeconds(5);
      expect(log.announced, hasLength(1));
      semantics.dispose();
    });
  });

  group('the timer row fits large text', () {
    for (final width in [320.0, 360.0]) {
      for (final upAt in [false, true]) {
        testWidgets('text scale 2.0 at ${width.toInt()} wide, '
            '${upAt ? 'time up' : 'counting'}', (tester) async {
          useView(tester, width: width, scale: 2);
          await tester.pumpWidget(timerPage(const Duration(seconds: 30)));
          if (upAt) await tester.pump(second * 30);
          expect(find.text(upAt ? timeUp : '0:30'), findsOneWidget);
          // A RenderFlex overflow is reported as a caught exception.
          expect(tester.takeException(), isNull);

          // Nothing painted beyond the timer's own card.
          final card = tester.getRect(
            find.ancestor(
              of: find.text('Clue time'),
              matching: find.byType(Container),
            ),
          );
          for (final text in ['Clue time', upAt ? timeUp : '0:30']) {
            final box = tester.getRect(find.text(text));
            expect(box.right, lessThanOrEqualTo(card.right), reason: text);
            expect(box.left, greaterThanOrEqualTo(card.left), reason: text);
          }
        });
      }
    }

    testWidgets('a game screen at 2.0 on 320 wide keeps the timer inside', (
      tester,
    ) async {
      useView(tester, width: 320, scale: 2);
      final host = GameHost(
        settings: GameSettings(clueTime: const Duration(seconds: 30)),
      );
      await host.start(tester);
      await host.revealAll(tester);
      final before = tester.takeException();
      await tester.pump(second * 30);
      expect(find.text(timeUp), findsOneWidget);
      expect(before, isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
