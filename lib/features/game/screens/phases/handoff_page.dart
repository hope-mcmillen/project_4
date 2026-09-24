import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../models/player_view.dart';
import '../../widgets/game_widgets.dart';

/// The "pass the phone" lock screen shown before a private reveal or ballot.
class HandoffPage extends StatelessWidget {
  const HandoffPage({
    super.key,
    required this.view,
    required this.voting,
    required this.onOpen,
  });
  final PlayerView view;
  final bool voting;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Eyebrow(
        '${voting ? 'Private vote' : 'Secret roles'} • ${view.turn + 1} of ${view.players.length}',
      ),
      Text('Pass the phone to', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(view.turnPlayer, style: Theme.of(context).textTheme.displaySmall),
      const InfoCard(
        color: AppColors.lime,
        child: Column(
          children: [
            Icon(Icons.lock_outline_rounded, size: 64, color: AppColors.ink),
            SizedBox(height: 16),
            Text(
              'For your eyes only.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Make sure no one else can see the screen before you continue.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      FilledButton.icon(
        onPressed: onOpen,
        icon: const Icon(Icons.visibility_outlined),
        label: Text(voting ? 'Open my ballot' : 'Reveal my role'),
      ),
    ],
  );
}
