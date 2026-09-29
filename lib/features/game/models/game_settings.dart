/// The host's choices for one game (Trello CHM-14): optional timers for the
/// spoken phases, and an optional number of rounds.
///
/// Every setting is off by default, and [GameSettings.off] is exactly the
/// game as it played before these settings existed. A game is one
/// `GameScreen`: the settings are fixed for as long as the same crew keeps
/// replaying, and a new game from setup can pass new ones.
class GameSettings {
  /// No timers, no round limit.
  static const off = GameSettings._(null, null, null);

  /// What the setup screen offers for each timer, in order. `null` is off.
  ///
  /// The model accepts any positive duration; this list is the product
  /// decision about which ones to offer, kept here so setup does not
  /// invent its own.
  static const timerChoices = <Duration?>[
    null,
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 90),
  ];

  /// What the setup screen offers for the round limit, in order. `null` is
  /// unlimited. Same reasoning as [timerChoices]: one list, kept here, so
  /// every screen that asks (setup today, a room lobby later) offers the same.
  static const roundChoices = <int?>[null, 3, 5, 10];

  /// Throws [ArgumentError] for a timer that is not positive or a round
  /// limit below one: neither can be played, so neither is stored.
  factory GameSettings({
    Duration? clueTime,
    Duration? discussionTime,
    int? roundLimit,
  }) {
    for (final (name, time) in [
      ('clueTime', clueTime),
      ('discussionTime', discussionTime),
    ]) {
      if (time != null && time <= Duration.zero) {
        throw ArgumentError.value(time, name, 'A timer must be positive');
      }
    }
    if (roundLimit != null && roundLimit < 1) {
      throw ArgumentError.value(
        roundLimit,
        'roundLimit',
        'A game needs at least one round',
      );
    }
    return GameSettings._(clueTime, discussionTime, roundLimit);
  }

  // Private so every public way in is validated; `off` needs a const one.
  const GameSettings._(this.clueTime, this.discussionTime, this.roundLimit);

  /// Countdown for each player's clue, restarted for every player.
  /// Null means no clue timer.
  final Duration? clueTime;

  /// Countdown for the discussion, run once. Null means no discussion timer.
  final Duration? discussionTime;

  /// Rounds in a game. Null means the crew can replay without end.
  final int? roundLimit;
}
