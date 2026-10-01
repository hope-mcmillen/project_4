import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/features/lobby/logic/room_code.dart';
import 'package:project_4/features/lobby/models/room.dart';

Room roomWith(int playerCount, {RoomStatus status = RoomStatus.lobby}) => Room(
  code: 'ABCDE',
  hostId: 'p0',
  topicId: 'food',
  players: [
    for (var i = 0; i < playerCount; i++) LobbyPlayer(id: 'p$i', name: 'P$i'),
  ],
  status: status,
);

void main() {
  test('generated codes are valid and use only unambiguous characters', () {
    final random = Random(42);
    for (var i = 0; i < 200; i++) {
      final code = generateRoomCode(random);
      expect(isValidRoomCode(code), isTrue, reason: code);
      expect(code, isNot(matches(RegExp('[01OIL]'))));
    }
  });

  test('codes are normalized before validation', () {
    expect(normalizeRoomCode(' abc-de '), 'ABCDE');
    expect(isValidRoomCode(normalizeRoomCode('abc de')), isTrue);
    expect(isValidRoomCode('ABCD'), isFalse);
    expect(isValidRoomCode('ABCD0'), isFalse);
  });

  test('a room can start with 3–8 players, only from the lobby', () {
    expect(roomWith(2).canStart, isFalse);
    expect(roomWith(3).canStart, isTrue);
    expect(roomWith(8).canStart, isTrue);
    expect(roomWith(8).isFull, isTrue);
    expect(roomWith(7).isFull, isFalse);
    expect(roomWith(4, status: RoomStatus.started).canStart, isFalse);
  });
}
