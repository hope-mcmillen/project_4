import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/features/lobby/logic/fake_room_repository.dart';
import 'package:project_4/features/lobby/logic/host_lobby_controller.dart';
import 'package:project_4/features/lobby/models/room.dart';

void main() {
  late FakeRoomRepository rooms;
  late HostLobbyController host;

  setUp(() {
    rooms = FakeRoomRepository();
    host = HostLobbyController(rooms);
  });
  tearDown(() {
    host.dispose();
    rooms.dispose();
  });

  Future<void> join(String name) async {
    await rooms.joinRoom(code: host.room!.code, name: name);
    await pumpEventQueue();
  }

  test('creating a room moves to the lobby with the host listed', () async {
    final phases = <HostLobbyPhase>[];
    host.addListener(() => phases.add(host.phase));

    await host.createRoom(hostName: 'Alex', topicId: 'food');

    expect(phases, [HostLobbyPhase.creating, HostLobbyPhase.lobby]);
    expect(host.room!.players.single.name, 'Alex');
    expect(host.error, isNull);
  });

  test('an invalid host name stays on setup with an error', () async {
    await host.createRoom(hostName: '   ', topicId: 'food');
    expect(host.phase, HostLobbyPhase.setup);
    expect(host.room, isNull);
    expect(host.error, contains('1–20'));
  });

  test('the lobby updates live and allows starting at three players', () async {
    await host.createRoom(hostName: 'Alex', topicId: 'food');
    await join('Blair');
    expect(host.room!.players.map((p) => p.name), ['Alex', 'Blair']);
    expect(host.canStart, isFalse);

    await host.startRound();
    expect(host.phase, HostLobbyPhase.lobby, reason: 'start is ignored');

    await join('Casey');
    expect(host.canStart, isTrue);
    await host.startRound();
    expect(host.phase, HostLobbyPhase.started);
    expect(host.room!.status, RoomStatus.started);
  });

  test('nothing is reported after dispose', () async {
    final pending = host.createRoom(hostName: 'Alex', topicId: 'food');
    host.dispose();
    await pending;
    // Recreate so tearDown's dispose has a live controller.
    host = HostLobbyController(rooms);
  });
}
