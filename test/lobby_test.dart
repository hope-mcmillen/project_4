import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/features/lobby/online_screen.dart';
import 'package:project_4/features/lobby/room_repository.dart';

class FakeRooms implements RoomRepository {
  final updates = StreamController<RoomView>.broadcast();
  String? existing;
  String? joinedCode;
  String? createdName;
  bool left = false;
  bool? ready;
  String? selectedTopic;
  @override
  String get playerId => 'me';
  @override
  Future<String?> connect() async => existing;
  @override
  Future<String> createRoom(String name, String topicId) async {
    createdName = name;
    return 'room';
  }

  @override
  Future<String> joinRoom(String code, String name) async {
    joinedCode = code;
    if (code == 'AAAAAA') {
      throw const LobbyException('That code was not found.');
    }
    return 'room';
  }

  @override
  Stream<RoomView> watchRoom(String roomId) => updates.stream;
  @override
  Future<void> setReady(String roomId, bool value) async {
    ready = value;
  }

  @override
  Future<void> setTopic(String roomId, String topicId) async {
    selectedTopic = topicId;
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    left = true;
  }

  void emit({String host = 'me', bool ready = false, bool cached = false}) =>
      updates.add(
        RoomView(
          id: 'room',
          code: 'K7MXQ2',
          hostId: host,
          topicId: 'food',
          isFromCache: cached,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          players: [
            LobbyPlayer(id: 'me', name: 'Alex', ready: ready),
            LobbyPlayer(id: 'other', name: 'Blair', ready: ready),
            LobbyPlayer(id: 'third', name: 'Casey', ready: ready),
          ],
        ),
      );
}

Future<void> tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('create validates name, renders updates, readiness and leave', (
    tester,
  ) async {
    final rooms = FakeRooms();
    addTearDown(rooms.updates.close);
    await tester.pumpWidget(MaterialApp(home: OnlineScreen(repository: rooms)));
    await tester.pump();
    await tap(tester, 'Create lobby');
    expect(find.text('Enter your name.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, ' Alex ');
    await tap(tester, 'Create lobby');
    expect(rooms.createdName, 'Alex');
    rooms.emit();
    await tester.pump();
    expect(find.text('K7MXQ2'), findsOneWidget);
    await tap(tester, 'I’m ready');
    expect(rooms.ready, true);
    rooms.emit(ready: true);
    await tester.pump();
    expect(
      find.text('Everyone is ready! Online rounds are coming next.'),
      findsOneWidget,
    );
    await tap(tester, 'Out & about');
    expect(rooms.selectedTopic, 'places');
    await tap(tester, 'Leave lobby');
    expect(rooms.left, true);
    expect(find.text('Create lobby'), findsOneWidget);
  });

  testWidgets('join errors allow retry and joining keeps supplied code', (
    tester,
  ) async {
    final rooms = FakeRooms();
    addTearDown(rooms.updates.close);
    await tester.pumpWidget(MaterialApp(home: OnlineScreen(repository: rooms)));
    await tester.pump();
    await tap(tester, 'Join game');
    await tester.enterText(find.byType(TextFormField).first, 'Alex');
    await tester.enterText(find.byType(TextFormField).last, 'AAAAAA');
    await tap(tester, 'Join lobby');
    expect(find.text('That code was not found.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'K7MXQ2');
    await tap(tester, 'Join lobby');
    expect(rooms.joinedCode, 'K7MXQ2');
    rooms.emit(host: 'other', cached: true);
    await tester.pump();
    expect(find.text('Out & about'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'I’m ready'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('restores existing seat and fits small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final rooms = FakeRooms()..existing = 'room';
    addTearDown(rooms.updates.close);
    await tester.pumpWidget(MaterialApp(home: OnlineScreen(repository: rooms)));
    await tester.pump();
    rooms.emit();
    await tester.pump();
    expect(find.text('K7MXQ2'), findsOneWidget);
    await tap(tester, 'Leave lobby');
    expect(tester.takeException(), isNull);
  });
}
