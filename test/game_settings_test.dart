import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/features/game/models/game_settings.dart';

void main() {
  test('the default is the game as it was: no timers, no round limit', () {
    for (final settings in [GameSettings.off, GameSettings()]) {
      expect(settings.clueTime, isNull);
      expect(settings.discussionTime, isNull);
      expect(settings.roundLimit, isNull);
    }
  });

  test('the timer choices for setup are off, 30, 60 and 90 seconds', () {
    expect(GameSettings.timerChoices, const [
      null,
      Duration(seconds: 30),
      Duration(seconds: 60),
      Duration(seconds: 90),
    ]);
  });

  test('keeps each choice it is given, independently', () {
    final settings = GameSettings(
      clueTime: const Duration(seconds: 30),
      discussionTime: const Duration(seconds: 90),
      roundLimit: 5,
    );
    expect(settings.clueTime, const Duration(seconds: 30));
    expect(settings.discussionTime, const Duration(seconds: 90));
    expect(settings.roundLimit, 5);
  });

  group('rejects a setting that cannot be played', () {
    for (final (name, build) in <(String, GameSettings Function())>[
      ('zero clue time', () => GameSettings(clueTime: Duration.zero)),
      (
        'negative clue time',
        () => GameSettings(clueTime: const Duration(seconds: -30)),
      ),
      (
        'zero discussion time',
        () => GameSettings(discussionTime: Duration.zero),
      ),
      ('zero rounds', () => GameSettings(roundLimit: 0)),
      ('negative rounds', () => GameSettings(roundLimit: -1)),
    ]) {
      test(name, () => expect(build, throwsArgumentError));
    }
  });

  test('accepts the smallest playable values', () {
    expect(
      () => GameSettings(
        clueTime: const Duration(seconds: 1),
        discussionTime: const Duration(seconds: 1),
        roundLimit: 1,
      ),
      returnsNormally,
    );
  });
}
