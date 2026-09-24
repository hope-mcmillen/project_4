import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../models/player_view.dart';
import '../../widgets/game_widgets.dart';

class DiscussionPhase extends StatelessWidget {
  const DiscussionPhase({
    super.key,
    required this.view,
    required this.onReadyToVote,
  });
  final PlayerView view;
  final VoidCallback onReadyToVote;

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const Eyebrow('Connect the clues'),
      Text(
        'Someone’s\nblending in.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const InfoCard(
        color: AppColors.lime,
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
              'Discuss as a group. When everyone is ready, pass the phone for one private vote each. A tie lets the Chameleon escape.',
            ),
          ],
        ),
      ),
      FilledButton(
        onPressed: onReadyToVote,
        child: const Text('Ready to vote'),
      ),
      TopicBoard(topic: view.topic),
    ],
  );
}
