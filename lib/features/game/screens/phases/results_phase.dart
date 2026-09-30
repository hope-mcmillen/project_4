import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../logic/game_session.dart';
import '../../models/game_phase.dart';
import '../../models/player_view.dart';
import '../../widgets/game_widgets.dart';

class ResultsPhase extends StatelessWidget {
  const ResultsPhase({
    super.key,
    required this.view,
    required this.session,
    required this.onReplay,
    required this.onLeave,
  });
  final PlayerView view;

  /// Read-only here. GameScreen records a round the moment it ends, before
  /// this builds, so the standings already include the result shown above.
  /// Only this screen shows standings: a round's points reveal its Chameleon.
  final GameSession session;
  final VoidCallback onReplay;

  /// Back to setup. Offered as "New game" once a round-limited game is over.
  final VoidCallback onLeave;

  static String _points(int points) => points == 1 ? '1 pt' : '$points pts';

  // "A wins!", "A & B share the win!", "A, B & C share the win!"
  static String _winnerLine(List<String> winners) => winners.length == 1
      ? '${winners.single} wins!'
      : '${winners.sublist(0, winners.length - 1).join(', ')} '
            '& ${winners.last} share the win!';

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      // Only on the last round of a limited game. Before that, and in every
      // unlimited game, this screen is exactly as it was before CHM-14.
      // First on the page, above the round's own result: on a phone the top
      // of the screen is all a player sees, and the end of the game is the
      // news (CHM-17). The round result, votes and score follow below.
      if (session.isOver)
        InfoCard(
          color: AppColors.lime,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Game over'),
              Text(
                _winnerLine(session.leaders),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${_points(session.standings.first.points)} after '
                '${session.roundsPlayed == 1 ? '1 round' : '${session.roundsPlayed} rounds'}',
                style: const TextStyle(color: AppColors.ink),
              ),
            ],
          ),
        ),
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
      InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Running score'),
            Text(
              session.roundsPlayed == 1
                  ? 'After 1 round'
                  : 'After ${session.roundsPlayed} rounds',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final standing in session.standings)
              Padding(
                key: ValueKey('standing-${standing.name}'),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(standing.name)),
                    Text(_points(standing.points)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              session.rule.summary,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      // A finished game cannot be replayed: the session would refuse the
      // next round. "New game" goes to setup, which starts a fresh session.
      if (session.isOver)
        FilledButton.icon(
          onPressed: onLeave,
          icon: const Icon(Icons.flag_outlined),
          label: const Text('New game'),
        )
      else ...[
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
    ],
  );
}
