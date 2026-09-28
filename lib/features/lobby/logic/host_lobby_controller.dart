import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/room.dart';
import 'room_repository.dart';

enum HostLobbyPhase { setup, creating, lobby, starting, started }

/// Drives the host's side of a room: create it, follow who joins, start it.
/// Screens render [phase], [room] and [error]; they never call the backend.
class HostLobbyController extends ChangeNotifier {
  HostLobbyController(this._rooms);

  final RoomRepository _rooms;
  StreamSubscription<Room>? _subscription;
  bool _disposed = false;

  HostLobbyPhase _phase = HostLobbyPhase.setup;
  Room? _room;
  String? _error;

  HostLobbyPhase get phase => _phase;
  Room? get room => _room;

  /// The last failure, cleared when the host tries again.
  String? get error => _error;

  bool get canStart =>
      _phase == HostLobbyPhase.lobby && (_room?.canStart ?? false);

  Future<void> createRoom({
    required String hostName,
    required String topicId,
  }) async {
    if (_phase != HostLobbyPhase.setup) return;
    _set(HostLobbyPhase.creating, error: null);
    try {
      final room = await _rooms.createRoom(
        hostName: hostName,
        topicId: topicId,
      );
      if (_disposed) return;
      _room = room;
      _subscription = _rooms
          .watchRoom(room.code)
          .listen(_onRoom, onError: _onWatchError);
      _set(HostLobbyPhase.lobby);
    } on RoomException catch (e) {
      _set(HostLobbyPhase.setup, error: e.message);
    }
  }

  Future<void> startRound() async {
    final room = _room;
    if (!canStart || room == null) return;
    _set(HostLobbyPhase.starting, error: null);
    try {
      await _rooms.startRound(code: room.code, playerId: room.hostId);
      // The watch stream also reports the start; this covers a slow stream.
      _room = _room?.copyWith(status: RoomStatus.started);
      _set(HostLobbyPhase.started);
    } on RoomException catch (e) {
      _set(HostLobbyPhase.lobby, error: e.message);
    }
  }

  void _onRoom(Room room) {
    _room = room;
    _set(room.status == RoomStatus.started ? HostLobbyPhase.started : _phase);
  }

  void _onWatchError(Object error) => _set(
    _phase,
    error: error is RoomException
        ? error.message
        : 'Lost connection to the room.',
  );

  // Sentinel so callers can clear [error] by passing null explicitly.
  static const _keep = Object();

  void _set(HostLobbyPhase phase, {Object? error = _keep}) {
    if (_disposed) return;
    _phase = phase;
    if (!identical(error, _keep)) _error = error as String?;
    notifyListeners();
  }

  /// Stops listening. The repository is owned by whoever created it.
  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
