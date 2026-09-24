import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'game_widgets.dart';

/// Takes no word by design: the Chameleon's card cannot display the secret.
class ChameleonCard extends StatelessWidget {
  const ChameleonCard({super.key, required this.topicName});
  final String topicName;

  @override
  Widget build(BuildContext context) => InfoCard(
    color: const Color(0xFFE8E1FF),
    child: Column(
      children: [
        const Icon(
          Icons.visibility_off_outlined,
          size: 48,
          color: AppColors.ink,
        ),
        const SizedBox(height: 16),
        const Text('Blend in. Listen closely.', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'You don’t know the word. Use the topic and everyone’s clues to bluff your way through.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text('Topic: $topicName', textAlign: TextAlign.center),
      ],
    ),
  );
}

class InsiderCard extends StatelessWidget {
  const InsiderCard({super.key, required this.topicName, required this.word});
  final String topicName;
  final String word;

  @override
  Widget build(BuildContext context) => InfoCard(
    color: AppColors.lime,
    child: Column(
      children: [
        const Icon(Icons.key_rounded, size: 48, color: AppColors.ink),
        const SizedBox(height: 16),
        const Text('The secret word is', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          word,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text('Topic: $topicName', textAlign: TextAlign.center),
      ],
    ),
  );
}
