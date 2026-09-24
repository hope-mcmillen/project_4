import 'package:flutter/material.dart';

import '../../models/player_view.dart';
import '../../widgets/game_widgets.dart';

class GuessPhase extends StatefulWidget {
  const GuessPhase({super.key, required this.view, required this.onGuess});
  final PlayerView view;
  final ValueChanged<String> onGuess;

  @override
  State<GuessPhase> createState() => _GuessPhaseState();
}

class _GuessPhaseState extends State<GuessPhase> {
  String? _guess;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    return PageBody(
      children: [
        const Eyebrow('Caught… or almost'),
        Text(
          '${view.chameleonName} is\nthe Chameleon!',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'Pass the phone to the Chameleon. You have one final guess. Choose the secret word to steal the win.',
        ),
        TopicBoard(
          topic: view.topic,
          selected: _guess,
          onSelect: (word) => setState(() => _guess = word),
        ),
        FilledButton(
          onPressed: _guess == null ? null : () => widget.onGuess(_guess!),
          child: const Text('Lock in final guess'),
        ),
      ],
    );
  }
}
