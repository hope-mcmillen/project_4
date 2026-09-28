import 'dart:async';
import 'dart:math';

import '../models/room.dart';
import 'room_code.dart';
import 'room_repository.dart';

/// In-memory stand-in until the CHM-S1 backend exists. Rooms live only as long
/// as this object, so every "device" must share one instance.
class FakeRoomRepository implements RoomRepository {
  FakeRoomRepository({Random? random, this.latency = Duration.zero})
    : _random = random ?? Random.secure();

  final Random _random;

  /// Simulated network delay before each call completes.
  final Duration latency;

  final Map<String, Room> _rooms = {};
  final Map<String, StreamController<Room>> _changes = {};
  int _nextPlayerId = 0;

  @override
  Future<Room> createRoom({
    required String hostName,
    required String topicId,
  }) async {
    await Future<void>.delayed(latency);
    final host = LobbyPlayer(id: _newPlayerId(), name: _validName(hostName));
    var code = generateRoomCode(_random);
    while (_rooms.containsKey(code)) {
      code = generateRoomCode(_random);
    }
    final room = Room(
      code: code,
      hostId: host.id,
      topicId: topicId,
      players: [host],
    );
    _rooms[code] = room;
    _changes[code] = StreamController<Room>.broadcast();
    return room;
  }

  @override
  Stream<Room> watchRoom(String code) {
    code = normalizeRoomCode(code);
    final changes = _changes[code];
    if (changes == null) {
      return Stream.error(const RoomException(RoomError.notFound));
    }
    late final StreamController<Room> controller;
    StreamSubscription<Room>? subscription;
    controller = StreamController<Room>(
      onListen: () {
        controller.add(_rooms[code]!);
        subscription = changes.stream.listen(controller.add);
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<LobbyPlayer> joinRoom({
    required String code,
    required String name,
  }) async {
    await Future<void>.delayed(latency);
    final room = _room(code);
    if (room.status != RoomStatus.lobby) {
      throw const RoomException(RoomError.alreadyStarted);
    }
    if (room.isFull) throw const RoomException(RoomError.full);
    final trimmed = _validName(name);
    if (room.players.any(
      (p) => p.name.toLowerCase() == trimmed.toLowerCase(),
    )) {
      throw const RoomException(RoomError.nameTaken);
    }
    final player = LobbyPlayer(id: _newPlayerId(), name: trimmed);
    _update(room.copyWith(players: [...room.players, player]));
    return player;
  }

  @override
  Future<void> startRound({
    required String code,
    required String playerId,
  }) async {
    await Future<void>.delayed(latency);
    final room = _room(code);
    if (playerId != room.hostId) throw const RoomException(RoomError.notHost);
    if (room.status != RoomStatus.lobby) {
      throw const RoomException(RoomError.alreadyStarted);
    }
    if (!room.canStart) throw const RoomException(RoomError.notEnoughPlayers);
    _update(room.copyWith(status: RoomStatus.started));
  }

  @override
  void dispose() {
    for (final changes in _changes.values) {
      changes.close();
    }
    _changes.clear();
    _rooms.clear();
  }

  Room _room(String code) =>
      _rooms[normalizeRoomCode(code)] ??
      (throw const RoomException(RoomError.notFound));

  void _update(Room room) {
    _rooms[room.code] = room;
    _changes[room.code]!.add(room);
  }

  String _newPlayerId() => 'p${_nextPlayerId++}';

  /// Same name rule as local setup: trimmed, 1–20 characters.
  static String _validName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 20) {
      throw const RoomException(RoomError.invalidName);
    }
    return trimmed;
  }
}
