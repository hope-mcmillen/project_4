import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../models/player_view.dart';
import '../../widgets/game_widgets.dart';
import 'handoff_page.dart';

class VotingPhase extends StatefulWidget {
  const VotingPhase({
    super.key,
    required this.view,
    required this.onOpenBallot,
    required this.onConfirmVote,
  });
  final PlayerView view;
  final VoidCallback onOpenBallot;
  final ValueChanged<int> onConfirmVote;

  @override
  State<VotingPhase> createState() => _VotingPhaseState();
}

class _VotingPhaseState extends State<VotingPhase> {
  // Tentative selection lives only as long as this ballot is open; the parent
  // re-keys this widget whenever a ballot closes, which discards it.
  int? _suspect;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    if (!view.privateOpen) {
      return HandoffPage(view: view, voting: true, onOpen: widget.onOpenBallot);
    }
    return PageBody(
      children: [
        Eyebrow('${view.turnPlayer} • Private ballot'),
        Text(
          'Who’s the\nChameleon?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'Choose one other player. Your vote is final once you confirm.',
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < view.players.length; i++)
          if (i != view.viewerIndex)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                selected: _suspect == i,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _suspect == i
                        ? AppColors.lime
                        : Colors.white,
                  ),
                  onPressed: () => setState(() => _suspect = i),
                  child: Row(
                    children: [
                      Icon(
                        _suspect == i
                            ? Icons.check_circle
                            : Icons.person_outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(view.players[i])),
                    ],
                  ),
                ),
              ),
            ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _suspect == null
              ? null
              : () => widget.onConfirmVote(_suspect!),
          child: const Text('Confirm & hide vote'),
        ),
      ],
    );
  }
}
