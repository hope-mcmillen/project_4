import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/features/game/data/topic_packs.dart';
import 'package:project_4/features/game/logic/game_controller.dart';
import 'package:project_4/features/game/models/game_phase.dart';
import 'package:project_4/features/game/models/topic_pack.dart';

import 'support/fixed_random.dart';

GameController createGame() => GameController(
  players: ['Alex', 'Blair', 'Casey', 'Drew'],
  topic: topicPacks.first,
  random: FixedRandom(),
);

void goToVoting(GameController game) {
  for (var i = 0; i < game.players.length; i++) {
    game.openPrivateView();
    game.finishReveal();
  }
  for (var i = 0; i < game.players.length; i++) {
    game.finishClue();
  }
  game.startVoting();
}

void vote(GameController game, List<int> suspects) {
  for (final suspect in suspects) {
    game.openPrivateView();
    game.castVote(suspect);
  }
}

void main() {
  test('exactly one Chameleon; shared word stays hidden during handoffs', () {
    final game = createGame();
    addTearDown(game.dispose);
    var chameleons = 0;
    final words = <String>[];
    for (var i = 0; i < 4; i++) {
      expect(game.roleWord, isNull);
      expect(game.isRevealedChameleon, isFalse);
      game.openPrivateView();
      if (game.isRevealedChameleon) {
        chameleons++;
      } else {
        words.add(game.roleWord!);
      }
      game.hidePrivateView();
      expect(game.roleWord, isNull);
      game.openPrivateView();
      game.finishReveal();
    }
    expect(chameleons, 1);
    expect(words, ['Sushi', 'Sushi', 'Sushi']);
    expect(game.phase, GamePhase.clues);
    expect(game.secretWord, isNull);
    expect(game.chameleonName, isNull);
  });

  test(
    'caught Chameleon wins with the right guess, without early disclosure',
    () {
      final game = createGame();
      addTearDown(game.dispose);
      goToVoting(game);
      vote(game, [1, 0, 0, 0]);
      expect(game.phase, GamePhase.guess);
      expect(game.chameleonName, 'Alex');
      expect(game.secretWord, isNull);
      expect(game.voteCounts, isEmpty);
      game.guessWord('Sushi');
      expect(game.winner, RoundWinner.chameleon);
      expect(game.secretWord, 'Sushi');
      expect(game.voteCounts, {0: 3, 1: 1, 2: 0, 3: 0});
    },
  );

  test('group wins after a wrong final guess', () {
    final game = createGame();
    addTearDown(game.dispose);
    goToVoting(game);
    vote(game, [1, 0, 0, 0]);
    game.guessWord('Pizza');
    expect(game.phase, GamePhase.result);
    expect(game.winner, RoundWinner.group);
  });

  test('tied votes let the Chameleon escape', () {
    final game = createGame();
    addTearDown(game.dispose);
    goToVoting(game);
    vote(game, [1, 0, 1, 0]);
    expect(game.phase, GamePhase.result);
    expect(game.winner, RoundWinner.chameleon);
    expect(game.resultReason, contains('tied'));
  });

  test('accusing the wrong player lets the Chameleon escape', () {
    final game = createGame();
    addTearDown(game.dispose);
    goToVoting(game);
    vote(game, [1, 2, 1, 1]);
    expect(game.winner, RoundWinner.chameleon);
    expect(game.resultReason, contains('Blair'));
  });

  test('rejects invalid phase changes, private skips and invalid votes', () {
    final game = createGame();
    addTearDown(game.dispose);
    expect(game.finishReveal, throwsStateError);
    expect(game.finishClue, throwsStateError);
    expect(game.startVoting, throwsStateError);
    expect(() => game.guessWord('Sushi'), throwsStateError);
    goToVoting(game);
    expect(() => game.castVote(1), throwsStateError);
    game.openPrivateView();
    expect(() => game.castVote(0), throwsArgumentError);
    expect(() => game.castVote(4), throwsArgumentError);
    expect(() => game.castVote(-1), throwsArgumentError);
    game.castVote(1);
    expect(() => game.castVote(0), throwsStateError);
    vote(game, [0, 0, 0]);
    expect(() => game.guessWord('Not a word'), throwsArgumentError);
    game.guessWord('Pizza');
    expect(() => game.guessWord('Sushi'), throwsStateError);
  });

  test('validates player counts, normalized names, and topic contents', () {
    for (final names in [
      <String>[],
      ['A', 'B'],
      ['A', ' a ', 'B'],
      ['A', '', 'B'],
      List.generate(9, (i) => 'P$i'),
    ]) {
      expect(
        () => GameController(players: names, topic: topicPacks.first),
        throwsArgumentError,
      );
    }
    expect(
      () => GameController(
        players: ['A', 'B', 'C'],
        topic: const TopicPack(id: 'bad', name: 'Bad', words: ['Word']),
      ),
      throwsArgumentError,
    );
    final game = GameController(
      players: [' A ', 'B', 'C'],
      topic: topicPacks.first,
    );
    addTearDown(game.dispose);
    expect(game.players.first, 'A');
    expect(() => game.players.add('D'), throwsUnsupportedError);
  });

  test('minimum and maximum player counts both finish a round', () {
    for (final count in [3, 8]) {
      final game = GameController(
        players: List.generate(count, (i) => 'P$i'),
        topic: topicPacks.last,
        random: FixedRandom(),
      );
      addTearDown(game.dispose);
      goToVoting(game);
      vote(game, [1, ...List.filled(count - 1, 0)]);
      game.guessWord(game.topic.words.first);
      expect(game.phase, GamePhase.result);
      expect(game.voteCounts.values.reduce((a, b) => a + b), count);
    }
  });
}
