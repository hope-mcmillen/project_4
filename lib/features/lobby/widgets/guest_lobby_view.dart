import 'package:flutter/material.dart';

import '../../game/widgets/game_widgets.dart';
import '../logic/join_room_controller.dart';
import 'lobby_widgets.dart';
import 'room_code_badge.dart';

/// What a guest sees after joining: the room, who is in it, and a wait
/// until the host starts.
class GuestLobbyView extends StatelessWidget {
  const GuestLobbyView({super.key, required this.guest});

  final JoinRoomController guest;

  @override
  Widget build(BuildContext context) {
    final room = guest.room!;
    final hostName = room.players
        .firstWhere((player) => player.id == room.hostId)
        .name;

    return PageBody(
      children: [
        Align(
          alignment: Alignment.topRight,
          child: RoomCodeBadge(code: room.code),
        ),
        Text(
          'You’re in, ${guest.me!.name}!',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        LobbyPlayerList(room: room, meId: guest.me!.id),
        if (guest.error case final error?) ...[
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        if (guest.phase == JoinPhase.started)
          const RoundStartedCard()
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Flexible(child: Text('Waiting for $hostName to start…')),
            ],
          ),
      ],
    );
  }
}
