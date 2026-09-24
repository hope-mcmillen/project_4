import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../models/game_phase.dart';
import '../../models/player_view.dart';
import '../../widgets/game_widgets.dart';

class ResultsPhase extends StatelessWidget {
  const ResultsPhase({
    super.key,
    required this.view,
    required this.onReplay,
    required this.onLeave,
  });
  final PlayerView view;
  final VoidCallback onReplay;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const Eyebrow('The secret is out'),
      Text(
        view.winner == RoundWinner.group
            ? 'Good instincts.\nThe group wins!'
            : 'Master of disguise.\nChameleon wins!',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      Text(view.resultReason!),
      InfoCard(
        color: AppColors.lime,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('The secret word'),
            Text(
              view.secretWord!,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Chameleon: ${view.chameleonName}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
      InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('How the votes landed'),
            for (var i = 0; i < view.players.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(view.players[i])),
                    Text('${view.voteCounts[i]} votes'),
                  ],
                ),
              ),
          ],
        ),
      ),
      FilledButton.icon(
        onPressed: onReplay,
        icon: const Icon(Icons.replay),
        label: const Text('Play again · Same crew'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: onLeave,
        child: const Text('Change players or topic'),
      ),
    ],
  );
}
