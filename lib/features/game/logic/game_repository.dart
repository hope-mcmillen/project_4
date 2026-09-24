import 'package:flutter/foundation.dart';

import '../models/player_view.dart';

/// The only surface the game UI talks to: read a [PlayerView], invoke actions.
///
/// Notifies listeners whenever [view] changes. Implementations own the rules
/// and secrets; a networked one must send each device only its own view.
abstract interface class GameRepository implements Listenable {
  PlayerView get view;

  void openPrivateView();
  void hidePrivateView();
  void finishReveal();
  void finishClue();
  void startVoting();
  void castVote(int suspect);
  void guessWord(String word);
  void dispose();
}
