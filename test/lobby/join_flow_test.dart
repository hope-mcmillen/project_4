import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/app/chameleon_app.dart';
import 'package:project_4/features/lobby/logic/fake_room_repository.dart';
import 'package:project_4/features/lobby/logic/room_code.dart';

void main() {
  testWidgets('two "phones" share a room: host creates, guest joins, start', (
    tester,
  ) async {
    // Two app instances side by side, sharing one fake backend.
    final rooms = FakeRoomRepository();
    addTearDown(rooms.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Expanded(
              child: ChameleonApp(key: const Key('host'), rooms: rooms),
            ),
            Expanded(
              child: ChameleonApp(key: const Key('guest'), rooms: rooms),
            ),
          ],
        ),
      ),
    );

    Finder on(String phone, Finder finder) =>
        find.descendant(of: find.byKey(Key(phone)), matching: finder);

    Future<void> tap(String phone, String label) async {
      await tester.ensureVisible(on(phone, find.text(label)));
      await tester.tap(on(phone, find.text(label)));
      // The guest's waiting spinner never settles, so pump a few frames.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    // Host creates a room.
    await tap('host', 'Host online');
    await tester.enterText(on('host', find.byType(TextFormField)), 'Alex');
    await tap('host', 'Create room');
    final code = tester
        .widgetList<Text>(on('host', find.byType(Text)))
        .map((text) => text.data ?? '')
        .singleWhere(isValidRoomCode);

    // Guest joins with the code typed in lowercase.
    await tap('guest', 'Join online');
    await tester.enterText(
      on('guest', find.widgetWithText(TextFormField, 'Room code')),
      code.toLowerCase(),
    );
    await tester.enterText(
      on('guest', find.widgetWithText(TextFormField, 'Your name')),
      'Blair',
    );
    await tap('guest', 'Join room');

    expect(
      on('guest', find.text('Waiting for Alex to start…')),
      findsOneWidget,
    );
    expect(on('host', find.text('Blair')), findsOneWidget);
    expect(on('host', find.text('2 / 8')), findsOneWidget);

    // A third player joins from elsewhere; the host can now start.
    await rooms.joinRoom(code: code, name: 'Casey');
    await tester.pump();
    await tester.pump();
    expect(on('guest', find.text('Casey')), findsOneWidget);

    await tap('host', 'Start round');
    expect(on('host', find.textContaining('Round started!')), findsOneWidget);
    expect(on('guest', find.textContaining('Round started!')), findsOneWidget);
  });
}
