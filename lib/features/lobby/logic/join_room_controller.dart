import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/room.dart';
import 'room_code.dart';
import 'room_repository.dart';

enum JoinPhase { entry, joining, lobby, started }

/// Drives a guest's side of a room: join by code, then follow the lobby
/// until the host starts. Screens render [phase], [room] and [error].
class JoinRoomController extends ChangeNotifier {
  JoinRoomController(this._rooms);

  final RoomRepository _rooms;
  StreamSubscription<Room>? _subscription;
  bool _disposed = false;

  JoinPhase _phase = JoinPhase.entry;
  Room? _room;
  LobbyPlayer? _me;
  String? _error;

  JoinPhase get phase => _phase;
  Room? get room => _room;

  /// This device's player, once joined.
  LobbyPlayer? get me => _me;

  /// The last failure, cleared when the player tries again.
  String? get error => _error;

  Future<void> join({required String code, required String name}) async {
    if (_phase != JoinPhase.entry) return;
    final normalized = normalizeRoomCode(code);
    if (!isValidRoomCode(normalized)) {
      _set(
        JoinPhase.entry,
        error: 'Room codes are $roomCodeLength letters and numbers.',
      );
      return;
    }
    _set(JoinPhase.joining, error: null);
    try {
      final me = await _rooms.joinRoom(code: normalized, name: name);
      if (_disposed) return;
      _me = me;
      // Stay in joining until the first room snapshot arrives.
      _subscription = _rooms
          .watchRoom(normalized)
          .listen(_onRoom, onError: _onWatchError);
    } on RoomException catch (e) {
      _set(JoinPhase.entry, error: e.message);
    }
  }

  void _onRoom(Room room) {
    _room = room;
    _set(
      room.status == RoomStatus.started ? JoinPhase.started : JoinPhase.lobby,
    );
  }

  void _onWatchError(Object error) => _set(
    _phase,
    error: error is RoomException
        ? error.message
        : 'Lost connection to the room.',
  );

  // Sentinel so callers can clear [error] by passing null explicitly.
  static const _keep = Object();

  void _set(JoinPhase phase, {Object? error = _keep}) {
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
