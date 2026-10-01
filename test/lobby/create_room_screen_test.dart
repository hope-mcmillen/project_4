import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/app/theme.dart';
import 'package:project_4/features/lobby/logic/fake_room_repository.dart';
import 'package:project_4/features/lobby/logic/room_code.dart';
import 'package:project_4/features/lobby/models/room.dart';
import 'package:project_4/features/lobby/screens/create_room_screen.dart';

Future<void> pumpScreen(WidgetTester tester, FakeRoomRepository rooms) =>
    tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: CreateRoomScreen(rooms: rooms),
      ),
    );

/// The room code currently on screen.
String shownCode(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? '')
    .singleWhere(isValidRoomCode);

Future<void> tapText(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  testWidgets('a name is required before creating', (tester) async {
    final rooms = FakeRoomRepository();
    addTearDown(rooms.dispose);
    await pumpScreen(tester, rooms);
    await tapText(tester, 'Create room');
    expect(find.text('Enter your name.'), findsOneWidget);
  });

  testWidgets('creating shows progress, then the room code', (tester) async {
    final rooms = FakeRoomRepository(latency: const Duration(seconds: 1));
    addTearDown(rooms.dispose);
    await pumpScreen(tester, rooms);
    await tester.enterText(find.byType(TextFormField), 'Alex');
    await tapText(tester, 'Out & about');
    await tapText(tester, 'Create room');

    expect(find.text('Creating room…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    final code = shownCode(tester);
    // The fake's stream runs on real time, outside the test's fake clock.
    final room = await tester.runAsync(() => rooms.watchRoom(code).first);
    expect(room!.topicId, 'places');
  });

  testWidgets('the lobby lists players live and starts at three', (
    tester,
  ) async {
    final rooms = FakeRoomRepository();
    addTearDown(rooms.dispose);
    await pumpScreen(tester, rooms);
    await tester.enterText(find.byType(TextFormField), 'Alex');
    await tapText(tester, 'Create room');
    await tester.pump();

    final code = shownCode(tester);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('1 / ${Room.maxPlayers}'), findsOneWidget);
    expect(find.text('Waiting for 2 more players…'), findsOneWidget);

    Future<void> join(String name) async {
      await rooms.joinRoom(code: code, name: name);
      // The update hops through two streams before the screen rebuilds.
      await tester.pumpAndSettle();
    }

    await join('Blair');
    expect(find.text('Blair'), findsOneWidget);
    expect(find.text('Waiting for 1 more player…'), findsOneWidget);
    final start = find.widgetWithText(FilledButton, 'Start round');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);

    await join('Casey');
    expect(find.text('Casey'), findsOneWidget);
    expect(tester.widget<FilledButton>(start).onPressed, isNotNull);

    await tapText(tester, 'Start round');
    await tester.pump();
    expect(find.textContaining('Round started!'), findsOneWidget);
    expect(find.text('Start round'), findsNothing);
  });

  testWidgets('the code can be copied', (tester) async {
    final rooms = FakeRoomRepository();
    addTearDown(rooms.dispose);
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    await pumpScreen(tester, rooms);
    await tester.enterText(find.byType(TextFormField), 'Alex');
    await tapText(tester, 'Create room');
    await tester.pump();

    await tester.tap(find.byTooltip('Copy room code'));
    await tester.pump();
    expect(copied, [shownCode(tester)]);
    expect(find.text('Room code copied'), findsOneWidget);
  });
}
