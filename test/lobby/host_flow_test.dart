import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/app/chameleon_app.dart';
import 'package:project_4/features/lobby/logic/fake_room_repository.dart';
import 'package:project_4/features/lobby/logic/room_code.dart';

void main() {
  testWidgets('home → host online → lobby → players join → start', (
    tester,
  ) async {
    final rooms = FakeRoomRepository();
    addTearDown(rooms.dispose);
    await tester.pumpWidget(ChameleonApp(rooms: rooms));

    await tester.ensureVisible(find.text('Host online'));
    await tester.tap(find.text('Host online'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Alex');
    await tester.ensureVisible(find.text('Create room'));
    await tester.tap(find.text('Create room'));
    await tester.pumpAndSettle();

    final code = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .singleWhere(isValidRoomCode);
    for (final name in ['Blair', 'Casey']) {
      await rooms.joinRoom(code: code, name: name);
      await tester.pumpAndSettle();
    }
    expect(find.text('3 / 8'), findsOneWidget);

    await tester.ensureVisible(find.text('Start round'));
    await tester.tap(find.text('Start round'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Round started!'), findsOneWidget);

    // Leaving the lobby returns home.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Host online'), findsOneWidget);
  });
}
