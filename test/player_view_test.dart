import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/features/game/data/topic_packs.dart';
import 'package:project_4/features/game/logic/game_controller.dart';
import 'package:project_4/features/game/logic/game_repository.dart';
import 'package:project_4/features/game/logic/local_game_repository.dart';
import 'package:project_4/features/game/models/game_phase.dart';
import 'package:project_4/features/game/models/player_view.dart';

import 'support/fixed_random.dart';

const secret = 'Sushi';

// FixedRandom makes Alex (index 0) the Chameleon and 'Sushi' the secret word.
GameRepository createRepository() => LocalGameRepository(
  GameController(
    players: ['Alex', 'Blair', 'Casey', 'Drew'],
    topic: topicPacks.first,
    random: FixedRandom(),
  ),
);

/// Nothing that names the word may reach a Chameleon before the round ends.
void expectNoSecret(PlayerView view) {
  expect(view.roleWord, isNull, reason: 'phase ${view.phase}');
  expect(view.secretWord, isNull, reason: 'phase ${view.phase}');
  expect(view.resultReason, isNull, reason: 'phase ${view.phase}');
  expect(view.voteCounts, isEmpty, reason: 'phase ${view.phase}');
}

void main() {
  test('the Chameleon\'s view never contains the word before the result', () {
    final game = createRepository();
    addTearDown(game.dispose);

    // Alex is first in line: closed, then open, then closed again.
    expect(game.view.ownRole, isNull);
    expectNoSecret(game.view);
    game.openPrivateView();
    expect(game.view.viewerName, 'Alex');
    expect(game.view.ownRole, PlayerRole.chameleon);
    expectNoSecret(game.view);
    game.hidePrivateView();
    expectNoSecret(game.view);
    game.openPrivateView();
    game.finishReveal();

    // The other three reveal in turn; none of it changes Alex's guarantees.
    for (var i = 1; i < 4; i++) {
      game.openPrivateView();
      game.finishReveal();
    }
    expect(game.view.phase, GamePhase.clues);
    expectNoSecret(game.view);
    for (var i = 0; i < 4; i++) {
      game.finishClue();
    }
    expect(game.view.phase, GamePhase.discussion);
    expectNoSecret(game.view);
    game.startVoting();
    expectNoSecret(game.view);

    // Alex is caught and reaches the guess screen: identity is public, word is not.
    for (final suspect in [1, 0, 0, 0]) {
      game.openPrivateView();
      expectNoSecret(game.view);
      game.castVote(suspect);
    }
    expect(game.view.phase, GamePhase.guess);
    expect(game.view.chameleonName, 'Alex');
    expectNoSecret(game.view);

    game.guessWord('Pizza');
    expect(game.view.phase, GamePhase.result);
    expect(game.view.secretWord, secret);
  });

  test('an insider sees the word only while their reveal is open', () {
    final game = createRepository();
    addTearDown(game.dispose);
    game.openPrivateView();
    game.finishReveal();

    expect(game.view.viewerName, 'Blair');
    expect(game.view.roleWord, isNull);
    expect(game.view.ownRole, isNull);
    game.openPrivateView();
    expect(game.view.ownRole, PlayerRole.insider);
    expect(game.view.roleWord, secret);
    expect(game.view.secretWord, isNull);
    game.hidePrivateView();
    expect(game.view.roleWord, isNull);
    game.openPrivateView();
    game.finishReveal();
    expect(game.view.roleWord, isNull);
  });

  test('tally and result appear only once the round is over', () {
    final game = createRepository();
    addTearDown(game.dispose);
    for (var i = 0; i < 4; i++) {
      game.openPrivateView();
      game.finishReveal();
    }
    for (var i = 0; i < 4; i++) {
      game.finishClue();
    }
    game.startVoting();
    for (final suspect in [1, 0, 1, 0]) {
      expect(game.view.voteCounts, isEmpty);
      game.openPrivateView();
      game.castVote(suspect);
    }
    expect(game.view.phase, GamePhase.result);
    expect(game.view.winner, RoundWinner.chameleon);
    expect(game.view.voteCounts, {0: 2, 1: 2, 2: 0, 3: 0});
    expect(game.view.secretWord, secret);
    expect(game.view.resultReason, contains('tied'));
  });

  test('the repository notifies listeners when the view changes', () {
    final game = createRepository();
    addTearDown(game.dispose);
    var notifications = 0;
    game.addListener(() => notifications++);
    game.openPrivateView();
    game.finishReveal();
    expect(notifications, 2);
  });
}
