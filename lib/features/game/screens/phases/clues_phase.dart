import 'package:flutter/material.dart';

import '../../models/player_view.dart';
import '../../widgets/game_widgets.dart';
import 'handoff_page.dart';

class CluesPhase extends StatelessWidget {
  const CluesPhase({
    super.key,
    required this.view,
    required this.onOpen,
    required this.onNext,
  });
  final PlayerView view;
  final VoidCallback onOpen;
  final VoidCallback onNext;

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
            TopicBanner(
              title: view.roleWord ?? view.topic.name,
              label: view.roleWord == null ? 'TOPIC' : 'SECRET WORD',
              chameleon: view.ownRole == PlayerRole.chameleon,
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
