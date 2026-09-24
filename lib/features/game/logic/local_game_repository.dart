import 'package:flutter/foundation.dart';

import '../models/player_view.dart';
import 'game_controller.dart';
import 'game_repository.dart';

/// Single-device pass-and-play: adapts [GameController] to [GameRepository].
class LocalGameRepository implements GameRepository {
  LocalGameRepository(this._game);

  final GameController _game;

  @override
  PlayerView get view {
    final roleWord = _game.roleWord;
    return PlayerView(
      players: _game.players,
      topic: _game.topic,
      phase: _game.phase,
      turn: _game.turn,
      viewerIndex: _game.turn,
      privateOpen: _game.privateOpen,
      ownRole: _game.isRevealedChameleon
          ? PlayerRole.chameleon
          : roleWord != null
          ? PlayerRole.insider
          : null,
      roleWord: roleWord,
      chameleonName: _game.chameleonName,
      secretWord: _game.secretWord,
      winner: _game.winner,
      resultReason: _game.resultReason,
      voteCounts: _game.voteCounts,
    );
  }

  @override
  void addListener(VoidCallback listener) => _game.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _game.removeListener(listener);

  @override
  void openPrivateView() => _game.openPrivateView();

  @override
  void hidePrivateView() => _game.hidePrivateView();

  @override
  void finishReveal() => _game.finishReveal();

  @override
  void finishClue() => _game.finishClue();

  @override
  void startVoting() => _game.startVoting();

  @override
  void castVote(int suspect) => _game.castVote(suspect);

  @override
  void guessWord(String word) => _game.guessWord(word);

  @override
  void dispose() => _game.dispose();
}
