import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/features/lobby/logic/fake_room_repository.dart';
import 'package:project_4/features/lobby/logic/join_room_controller.dart';
import 'package:project_4/features/lobby/models/room.dart';

void main() {
  late FakeRoomRepository rooms;
  late JoinRoomController guest;
  late Room room;

  setUp(() async {
    rooms = FakeRoomRepository();
    guest = JoinRoomController(rooms);
    room = await rooms.createRoom(hostName: 'Alex', topicId: 'food');
  });
  tearDown(() {
    guest.dispose();
    rooms.dispose();
  });

  Future<void> join(String code, String name) async {
    await guest.join(code: code, name: name);
    await pumpEventQueue();
  }

  test('joining with a typed code lands in the lobby', () async {
    final phases = <JoinPhase>[];
    guest.addListener(() => phases.add(guest.phase));
    final typed = '${room.code.substring(0, 3)}-${room.code.substring(3)}';

    await join(typed.toLowerCase(), ' Blair ');

    expect(phases, [JoinPhase.joining, JoinPhase.lobby]);
    expect(guest.me!.name, 'Blair');
    expect(guest.room!.players.map((p) => p.name), ['Alex', 'Blair']);
    expect(guest.error, isNull);
  });

  test('a malformed code is rejected without calling the backend', () async {
    await join('AB', 'Blair');
    expect(guest.phase, JoinPhase.entry);
    expect(guest.error, contains('5 letters'));
    expect((await rooms.watchRoom(room.code).first).players, hasLength(1));
  });

  test('backend errors return to entry so the player can retry', () async {
    await join('ZZZZZ', 'Blair');
    expect(guest.phase, JoinPhase.entry);
    expect(guest.error, 'No room with that code.');

    await join(room.code, 'alex');
    expect(guest.error, 'Someone in the room already has that name.');

    await join(room.code, 'Blair');
    expect(guest.phase, JoinPhase.lobby);
    expect(guest.error, isNull);
  });

  test('full and started rooms are refused', () async {
    for (var i = 1; i < Room.maxPlayers; i++) {
      await rooms.joinRoom(code: room.code, name: 'P$i');
    }
    await join(room.code, 'Late');
    expect(guest.error, contains('full'));

    final other = await rooms.createRoom(hostName: 'Host', topicId: 'food');
    await rooms.joinRoom(code: other.code, name: 'B');
    await rooms.joinRoom(code: other.code, name: 'C');
    await rooms.startRound(code: other.code, playerId: other.hostId);
    await join(other.code, 'Late');
    expect(guest.error, contains('already started'));
  });

  test('the lobby updates live and follows the host starting', () async {
    await join(room.code, 'Blair');
    await rooms.joinRoom(code: room.code, name: 'Casey');
    await pumpEventQueue();
    expect(guest.room!.players, hasLength(3));

    await rooms.startRound(code: room.code, playerId: room.hostId);
    await pumpEventQueue();
    expect(guest.phase, JoinPhase.started);
  });
}
