import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Takes no word by design: the Chameleon's card cannot display the secret.
class ChameleonCard extends StatelessWidget {
  const ChameleonCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 24),
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF273B31), Color(0xFF141E19)],
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: AppColors.lime.withValues(alpha: 0.35)),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.visibility_off_outlined,
          size: 64,
          color: AppColors.lime,
        ),
        const SizedBox(height: 24),
        Text(
          'You are the chameleon, try and stay hidden among the other players',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: Colors.white),
        ),
      ],
    ),
  );
}

class InsiderCard extends StatelessWidget {
  const InsiderCard({super.key, required this.topicName, required this.word});
  final String topicName;
  final String word;

  @override
  Widget build(BuildContext context) => _SecretCard(
    undercover: false,
    icon: Icons.key_rounded,
    label: 'THE SECRET WORD',
    focus: word,
    caption: 'Topic: $topicName',
    mission: 'You know. Don’t let it slip.',
    instruction: 'Give a clue that earns trust without giving the secret away.',
  );
}

class _SecretCard extends StatelessWidget {
  const _SecretCard({
    required this.undercover,
    required this.icon,
    required this.label,
    required this.focus,
    required this.caption,
    required this.mission,
    required this.instruction,
  });

  final bool undercover;
  final IconData icon;
  final String label;
  final String focus;
  final String caption;
  final String mission;
  final String instruction;

  @override
  Widget build(BuildContext context) {
    final accent = undercover ? AppColors.lime : const Color(0xFFD8CCFF);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: undercover
              ? const [Color(0xFF273B31), Color(0xFF141E19)]
              : const [Color(0xFF382655), Color(0xFF181522)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.1),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, size: 42, color: accent),
          ),
          const SizedBox(height: 24),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            focus,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: Colors.white, fontSize: 36),
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFD0D2D6)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Divider(height: 1, color: accent.withValues(alpha: 0.25)),
          ),
          Text(
            mission,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            instruction,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFD0D2D6), height: 1.5),
          ),
        ],
      ),
    );
  }
}
