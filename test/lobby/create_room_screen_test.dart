import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/app/theme.dart';
import 'package:project_4/features/lobby/logic/fake_room_repository.dart';
import 'package:project_4/features/lobby/logic/room_code.dart';
import 'package:project_4/features/lobby/screens/create_room_screen.dart';

void main() {
  late FakeRoomRepository rooms;

  setUp(() => rooms = FakeRoomRepository(latency: const Duration(seconds: 1)));
  tearDown(() => rooms.dispose());

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: CreateRoomScreen(rooms: rooms),
    ),
  );

  testWidgets('a name is required before creating', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Create room'));
    await tester.pump();
    expect(find.text('Enter your name.'), findsOneWidget);
  });

  testWidgets('creating shows progress, then the room code', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField), 'Alex');
    await tester.tap(find.text('Out & about'));
    await tester.pump();
    await tester.tap(find.text('Create room'));
    await tester.pump();

    expect(find.text('Creating room…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    final code = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .singleWhere(isValidRoomCode);
    final room = await tester.runAsync(() => rooms.watchRoom(code).first);
    expect(room!.topicId, 'places');
  });
}
