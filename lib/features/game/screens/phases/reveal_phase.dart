import 'package:flutter/material.dart';

import '../../models/player_view.dart';
import '../../widgets/game_widgets.dart';
import '../../widgets/role_cards.dart';
import 'handoff_page.dart';

class RevealPhase extends StatelessWidget {
  const RevealPhase({
    super.key,
    required this.view,
    required this.onReveal,
    required this.onContinue,
  });
  final PlayerView view;
  final VoidCallback onReveal;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (!view.privateOpen) {
      return HandoffPage(view: view, voting: false, onOpen: onReveal);
    }
    final chameleon = view.ownRole == PlayerRole.chameleon;
    return PageBody(
      children: [
        Eyebrow('${view.turnPlayer} • Keep this secret'),
        Text(
          chameleon ? 'You’re the\nChameleon.' : 'You’re in\non the secret.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (chameleon)
          ChameleonCard(topicName: view.topic.name)
        else
          InsiderCard(topicName: view.topic.name, word: view.roleWord!),
        FilledButton.icon(
          onPressed: onContinue,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Hide & continue'),
        ),
        TopicBoard(topic: view.topic),
      ],
    );
  }
}
