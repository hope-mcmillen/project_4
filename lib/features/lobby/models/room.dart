enum RoomStatus { lobby, started }

/// Someone in a room. [id] is stable for the room's lifetime; [name] is a label.
class LobbyPlayer {
  const LobbyPlayer({required this.id, required this.name});

  final String id;
  final String name;
}

/// What every device in a room may see before a round starts. No secrets live
/// here: roles and the word are assigned when the round starts (CHM-11).
class Room {
  const Room({
    required this.code,
    required this.hostId,
    required this.topicId,
    required this.players,
    this.status = RoomStatus.lobby,
  });

  static const minPlayers = 3;
  static const maxPlayers = 8;

  final String code;
  final String hostId;
  final String topicId;

  /// Players in join order; the host is first.
  final List<LobbyPlayer> players;
  final RoomStatus status;

  bool get isFull => players.length >= maxPlayers;
  bool get canStart =>
      status == RoomStatus.lobby && players.length >= minPlayers;

  Room copyWith({List<LobbyPlayer>? players, RoomStatus? status}) => Room(
    code: code,
    hostId: hostId,
    topicId: topicId,
    players: players ?? this.players,
    status: status ?? this.status,
  );
}
