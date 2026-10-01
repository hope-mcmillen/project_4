import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../game/widgets/game_widgets.dart';
import '../logic/host_lobby_controller.dart';
import '../models/room.dart';
import 'lobby_widgets.dart';

/// What the host sees once the room exists: the code to share, who has
/// joined so far, and the button to start the round.
class HostLobbyView extends StatelessWidget {
  const HostLobbyView({super.key, required this.host});

  final HostLobbyController host;

  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Copied $code')));
  }

  @override
  Widget build(BuildContext context) {
    final room = host.room!;
    final started = host.phase == HostLobbyPhase.started;
    final starting = host.phase == HostLobbyPhase.starting;
    final needed = Room.minPlayers - room.players.length;

    return PageBody(
      children: [
        const Eyebrow('Your room code'),
        InfoCard(
          color: AppColors.teal,
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Room code ${room.code.split('').join(' ')}',
                  excludeSemantics: true,
                  child: Text(
                    room.code,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy code',
                onPressed: () => _copyCode(context, room.code),
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
        ),
        const Text('Friends open Chameleon, tap Join, and enter this code.'),
        const SizedBox(height: 24),
        LobbyPlayerList(room: room),
        if (host.error case final error?) ...[
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        if (started)
          const RoundStartedCard()
        else ...[
          FilledButton.icon(
            onPressed: host.canStart ? host.startRound : null,
            icon: starting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(starting ? 'Starting…' : 'Start round'),
          ),
          const SizedBox(height: 12),
          Text(
            needed > 0
                ? 'Waiting for $needed more ${needed == 1 ? 'player' : 'players'}…'
                : 'Everyone in? Start when you’re ready.',
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
