import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/features/lobby/logic/fake_room_repository.dart';
import 'package:project_4/features/lobby/logic/room_code.dart';
import 'package:project_4/features/lobby/logic/room_repository.dart';
import 'package:project_4/features/lobby/models/room.dart';

Matcher throwsRoomError(RoomError error) =>
    throwsA(isA<RoomException>().having((e) => e.error, 'error', error));

void main() {
  late FakeRoomRepository rooms;

  setUp(() => rooms = FakeRoomRepository());
  tearDown(() => rooms.dispose());

  test('creating a room makes the host its first player', () async {
    final room = await rooms.createRoom(hostName: ' Alex ', topicId: 'food');
    expect(isValidRoomCode(room.code), isTrue);
    expect(room.players.single.name, 'Alex');
    expect(room.hostId, room.players.single.id);
    expect(room.status, RoomStatus.lobby);
  });

  test('two rooms never share a code', () async {
    final codes = {
      for (var i = 0; i < 50; i++)
        (await rooms.createRoom(hostName: 'Host', topicId: 'food')).code,
    };
    expect(codes, hasLength(50));
  });

  test('watching emits the current room, then each join', () async {
    final room = await rooms.createRoom(hostName: 'Alex', topicId: 'food');
    final names = rooms
        .watchRoom(room.code)
        .map((r) => r.players.map((p) => p.name).toList())
        .take(3)
        .toList();
    await rooms.joinRoom(code: room.code, name: 'Blair');
    await rooms.joinRoom(code: room.code.toLowerCase(), name: 'Casey');
    expect(await names, [
      ['Alex'],
      ['Alex', 'Blair'],
      ['Alex', 'Blair', 'Casey'],
    ]);
  });

  test('joining rejects unknown rooms, bad names and duplicates', () async {
    final room = await rooms.createRoom(hostName: 'Alex', topicId: 'food');
    expect(
      rooms.joinRoom(code: 'ZZZZZ', name: 'Blair'),
      throwsRoomError(RoomError.notFound),
    );
    expect(
      rooms.joinRoom(code: room.code, name: '  '),
      throwsRoomError(RoomError.invalidName),
    );
    expect(
      rooms.joinRoom(code: room.code, name: 'alex'),
      throwsRoomError(RoomError.nameTaken),
    );
    expect(
      () => rooms.watchRoom('ZZZZZ').first,
      throwsRoomError(RoomError.notFound),
    );
  });

  test('a room holds at most eight players', () async {
    final room = await rooms.createRoom(hostName: 'P0', topicId: 'food');
    for (var i = 1; i < Room.maxPlayers; i++) {
      await rooms.joinRoom(code: room.code, name: 'P$i');
    }
    expect(
      rooms.joinRoom(code: room.code, name: 'Late'),
      throwsRoomError(RoomError.full),
    );
  });

  test('only the host can start, and only with three players', () async {
    final room = await rooms.createRoom(hostName: 'Alex', topicId: 'food');
    final blair = await rooms.joinRoom(code: room.code, name: 'Blair');
    await expectLater(
      rooms.startRound(code: room.code, playerId: room.hostId),
      throwsRoomError(RoomError.notEnoughPlayers),
    );
    await rooms.joinRoom(code: room.code, name: 'Casey');
    await expectLater(
      rooms.startRound(code: room.code, playerId: blair.id),
      throwsRoomError(RoomError.notHost),
    );

    await rooms.startRound(code: room.code, playerId: room.hostId);
    expect((await rooms.watchRoom(room.code).first).status, RoomStatus.started);
    expect(
      rooms.joinRoom(code: room.code, name: 'Drew'),
      throwsRoomError(RoomError.alreadyStarted),
    );
  });
}
