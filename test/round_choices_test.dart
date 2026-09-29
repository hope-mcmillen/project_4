import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/features/game/models/game_settings.dart';

void main() {
  test('the round choices for setup are unlimited, 3, 5 and 10', () {
    expect(GameSettings.roundChoices, const [null, 3, 5, 10]);
  });

  test('every choice setup offers is one the model accepts', () {
    for (final time in GameSettings.timerChoices) {
      expect(
        () => GameSettings(clueTime: time, discussionTime: time),
        returnsNormally,
        reason: '$time',
      );
    }
    for (final rounds in GameSettings.roundChoices) {
      expect(
        () => GameSettings(roundLimit: rounds),
        returnsNormally,
        reason: '$rounds',
      );
    }
  });
}
