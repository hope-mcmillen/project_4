import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../game/widgets/game_widgets.dart';
import '../models/room.dart';

/// Who is in the room, shared by the host and guest lobbies.
class LobbyPlayerList extends StatelessWidget {
  const LobbyPlayerList({super.key, required this.room, this.meId});

  final Room room;

  /// This device's player, tagged "You" when set.
  final String? meId;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(child: Eyebrow('In the room')),
          Text(
            '${room.players.length} / ${Room.maxPlayers}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      for (final player in room.players)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline_rounded),
          title: Text(player.name),
          trailing: Wrap(
            spacing: 6,
            children: [
              if (player.id == meId) const Chip(label: Text('You')),
              if (player.id == room.hostId) const Chip(label: Text('Host')),
            ],
          ),
        ),
    ],
  );
}

/// Placeholder once the host starts, until CHM-11 deals roles per device.
class RoundStartedCard extends StatelessWidget {
  const RoundStartedCard({super.key});

  @override
  Widget build(BuildContext context) => const InfoCard(
    color: AppColors.purple,
    child: Text(
      'Round started! Online roles are on their way; for now, '
      'everyone keeps the room open.',
      style: TextStyle(color: Colors.white),
    ),
  );
}
