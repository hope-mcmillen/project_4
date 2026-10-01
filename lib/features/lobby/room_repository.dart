class LobbyPlayer {
  const LobbyPlayer({
    required this.id,
    required this.name,
    required this.ready,
  });
  final String id;
  final String name;
  final bool ready;
}

class RoomView {
  const RoomView({
    required this.id,
    required this.code,
    required this.hostId,
    required this.topicId,
    required this.players,
    required this.expiresAt,
    this.isFromCache = false,
  });
  final String id;
  final String code;
  final String hostId;
  final String topicId;
  final List<LobbyPlayer> players;
  final DateTime expiresAt;
  final bool isFromCache;
  bool get everyoneReady =>
      players.length >= 3 && players.every((p) => p.ready);
}

abstract interface class RoomRepository {
  String get playerId;
  Future<String?> connect();
  Future<String> createRoom(String name, String topicId);
  Future<String> joinRoom(String code, String name);
  Stream<RoomView> watchRoom(String roomId);
  Future<void> setReady(String roomId, bool ready);
  Future<void> setTopic(String roomId, String topicId);
  Future<void> leaveRoom(String roomId);
}

class LobbyException implements Exception {
  const LobbyException(this.message);
  final String message;
  @override
  String toString() => message;
}
