import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../widgets/game_widgets.dart';
import 'setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.blur_on_rounded, color: AppColors.purple),
          SizedBox(width: 8),
          Text(
            'chameleon',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.8),
          ),
        ],
      ),
    ),
    body: PageBody(
      children: [
        const SizedBox(height: 16),
        const Eyebrow('A little suspicious. A lot of fun.'),
        Text(
          'Blend in.\nStand out.\nDon’t get caught.',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 16),
        const Text(
          'One secret word. One player in the dark.\nCan your friends spot the Chameleon?',
          style: TextStyle(fontSize: 16, height: 1.5, color: AppColors.muted),
        ),
        const InfoCard(
          color: AppColors.purple,
          child: Column(
            children: [
              ChameleonMascot(),
              SizedBox(height: 12),
              Text(
                'TRUST NO ONE. INCLUDING YOUR BESTIE.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        const Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _Detail(icon: Icons.group_outlined, label: '3–8 players'),
            _Detail(icon: Icons.phone_iphone_rounded, label: 'One phone'),
            _Detail(icon: Icons.wifi_off_rounded, label: 'Offline'),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const SetupScreen())),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Start a game'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const RulesScreen())),
          icon: const Icon(Icons.help_outline_rounded),
          label: const Text('How to play'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Made for good company & questionable clues.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: AppColors.muted),
      const SizedBox(width: 5),
      Text(label),
    ],
  );
}

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('How to play')),
    body: PageBody(
      children: [
        const Eyebrow('The art of blending in'),
        Text(
          'Everyone knows.\nExcept one of you.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        for (final rule in const [
          (
            '01',
            'Gather your people',
            'Add 3–8 unique names and choose a topic. You’ll share one phone, so sit together.',
          ),
          (
            '02',
            'Keep your role secret',
            'Pass the phone to each player. Everyone sees the same secret word except the randomly chosen Chameleon. Hide your role before passing.',
          ),
          (
            '03',
            'Give a one-word clue',
            'In the order shown, say one clue aloud. Be specific enough to prove you know the word, but don’t give it away. The Chameleon bluffs.',
          ),
          (
            '04',
            'Talk it out & vote',
            'Discuss the clues, then pass the phone for private votes. You cannot vote for yourself. The player with the most votes is accused.',
          ),
          (
            '05',
            'One last chance',
            'If caught, the Chameleon gets one guess from the topic board. A correct guess wins. A wrong guess means the group wins.',
          ),
        ])
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(rule.$1),
                Text(rule.$2, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(rule.$3),
              ],
            ),
          ),
        const InfoCard(
          color: AppColors.lime,
          child: Text(
            'Starter house rules: a tied vote or an incorrect accusation lets the Chameleon win. Each round stands alone; there is no running score yet.',
          ),
        ),
      ],
    ),
  );
}
