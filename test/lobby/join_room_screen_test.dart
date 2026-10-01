import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/app/theme.dart';
import 'package:project_4/features/lobby/logic/fake_room_repository.dart';
import 'package:project_4/features/lobby/screens/join_room_screen.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  FakeRoomRepository rooms, {
  String? initialCode,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildTheme(),
    home: JoinRoomScreen(rooms: rooms, initialCode: initialCode),
  ),
);

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> tapJoin(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Join room'));
  await tester.tap(find.text('Join room'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('code and name are both required', (tester) async {
    final rooms = FakeRoomRepository();
    addTearDown(rooms.dispose);
    await pumpScreen(tester, rooms);
    await tapJoin(tester);
    expect(find.text('Enter the room code.'), findsOneWidget);
    expect(find.text('Enter your name.'), findsOneWidget);
  });

  testWidgets('a wrong code shows the error and keeps the form', (
    tester,
  ) async {
    final rooms = FakeRoomRepository();
    addTearDown(rooms.dispose);
    await pumpScreen(tester, rooms);
    await tester.enterText(field('Room code'), 'zzzzz');
    await tester.enterText(field('Your name'), 'Blair');
    await tapJoin(tester);
    expect(find.text('No room with that code.'), findsOneWidget);
    expect(find.text('Join room'), findsOneWidget);

    await tester.enterText(field('Room code'), 'ab');
    await tapJoin(tester);
    expect(find.text('Room codes are 5 letters and numbers.'), findsOneWidget);
  });

  testWidgets('joining shows progress, then enters the room', (tester) async {
    final rooms = FakeRoomRepository(latency: const Duration(seconds: 1));
    addTearDown(rooms.dispose);
    final room = await tester.runAsync(
      () => rooms.createRoom(hostName: 'Alex', topicId: 'food'),
    );
    await pumpScreen(tester, rooms, initialCode: room!.code.toLowerCase());
    await tester.enterText(field('Your name'), 'Blair');
    await tester.ensureVisible(find.text('Join room'));
    await tester.tap(find.text('Join room'));
    await tester.pump();

    expect(find.text('Joining…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // The waiting spinner never settles, so pump instead of pumpAndSettle.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('You’re in, Blair!'), findsOneWidget);
    expect(find.text('ROOM ${room.code}'), findsOneWidget); // Eyebrow caps.
  });

  testWidgets('the guest waits in the lobby until the host starts', (
    tester,
  ) async {
    final rooms = FakeRoomRepository();
    addTearDown(rooms.dispose);
    final room = await rooms.createRoom(hostName: 'Alex', topicId: 'food');
    await pumpScreen(tester, rooms, initialCode: room.code);
    await tester.enterText(field('Your name'), 'Blair');
    await tester.ensureVisible(find.text('Join room'));
    await tester.tap(find.text('Join room'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Waiting for Alex to start…'), findsOneWidget);
    expect(find.text('2 / 8'), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Blair'),
        matching: find.text('You'),
      ),
      findsOneWidget,
    );

    await rooms.joinRoom(code: room.code, name: 'Casey');
    await tester.pump();
    await tester.pump();
    expect(find.text('Casey'), findsOneWidget);

    await rooms.startRound(code: room.code, playerId: room.hostId);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Round started!'), findsOneWidget);
    expect(find.textContaining('Waiting for'), findsNothing);
  });
}
