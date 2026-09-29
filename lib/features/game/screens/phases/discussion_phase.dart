import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../models/player_view.dart';
import '../../widgets/game_widgets.dart';
import '../../widgets/phase_timer.dart';

class DiscussionPhase extends StatelessWidget {
  const DiscussionPhase({
    super.key,
    required this.view,
    required this.onReadyToVote,
    required this.onAnotherRound,
    this.discussionTime,
  });
  final PlayerView view;
  final VoidCallback onReadyToVote;
  final VoidCallback onAnotherRound;

  /// Countdown for the whole discussion, or null for none. Runs once:
  /// GameScreen keeps one key for the phase, so rebuilds do not restart it.
  final Duration? discussionTime;

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const Eyebrow('Connect the clues'),
      Text(
        'Someone’s\nblending in.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      if (discussionTime case final time?)
        PhaseTimer(label: 'Discussion time', duration: time),
      const InfoCard(
        color: AppColors.sage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.forum_outlined, size: 40),
            SizedBox(height: 12),
            Text(
              'Whose clue felt a little off?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
            SizedBox(height: 8),
            Text(
              'Discuss as a group. Need more clues? Play another round with the same roles and secret word. When everyone is ready, pass the phone for one private vote each. A tie lets the Chameleon escape.',
            ),
          ],
        ),
      ),
      FilledButton(
        onPressed: onReadyToVote,
        child: const Text('Ready to vote'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: onAnotherRound,
        child: const Text('Another Round'),
      ),
      TopicBoard(topic: view.topic),
    ],
  );
}
