import 'package:flutter/material.dart';

import '../../models/player_view.dart';
import '../../widgets/game_widgets.dart';
import '../../widgets/phase_timer.dart';
import 'handoff_page.dart';

class CluesPhase extends StatelessWidget {
  const CluesPhase({
    super.key,
    required this.view,
    required this.onOpen,
    required this.onNext,
    this.clueTime,
  });
  final PlayerView view;
  final VoidCallback onOpen;
  final VoidCallback onNext;

  /// Countdown for this player's clue, or null for none. It restarts for
  /// each player because GameScreen gives every clue turn its own key.
  final Duration? clueTime;

  @override
  Widget build(BuildContext context) => !view.privateOpen
      ? HandoffPage(view: view, voting: false, clues: true, onOpen: onOpen)
      : PageBody(
          children: [
            Eyebrow('Clue round • ${view.turn + 1} of ${view.players.length}'),
            Text(
              '${view.turnPlayer},\nyour one word?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Say your clue out loud. Make it convincing, but don’t make the secret too obvious.',
            ),
            if (clueTime case final time?)
              PhaseTimer(label: 'Clue time', duration: time),
            InfoCard(
              child: Text(
                view.roleWord ?? view.topic.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            FilledButton(
              onPressed: onNext,
              child: Text(
                view.turn == view.players.length - 1
                    ? 'Clue given · Discuss'
                    : 'Clue given · Next player',
              ),
            ),
          ],
        );
}
