import '../models/room.dart';

enum RoomError {
  notFound,
  full,
  alreadyStarted,
  invalidName,
  nameTaken,
  notHost,
  notEnoughPlayers,
}

class RoomException implements Exception {
  const RoomException(this.error);

  final RoomError error;

  String get message => switch (error) {
    RoomError.notFound => 'No room with that code.',
    RoomError.full => 'That room is full (${Room.maxPlayers} players).',
    RoomError.alreadyStarted => 'That room has already started.',
    RoomError.invalidName => 'Names must be 1–20 characters long.',
    RoomError.nameTaken => 'Someone in the room already has that name.',
    RoomError.notHost => 'Only the host can do that.',
    RoomError.notEnoughPlayers =>
      'You need at least ${Room.minPlayers} players.',
  };

  @override
  String toString() => 'RoomException($error)';
}

/// The lobby's only surface to a backend: rooms, membership, and starting.
///
/// A round's own state lives behind `GameRepository` once it starts. Failures
/// are thrown as [RoomException]. Hosting and joining (CHM-4) both meet here.
abstract interface class RoomRepository {
  /// Creates a room with [hostName] as its first player and host.
  Future<Room> createRoom({required String hostName, required String topicId});

  /// Emits the room's current state on listen, then every change.
  Stream<Room> watchRoom(String code);

  Future<LobbyPlayer> joinRoom({required String code, required String name});

  /// Moves the room out of the lobby. Only the host may call this.
  Future<void> startRound({required String code, required String playerId});

  void dispose();
}
