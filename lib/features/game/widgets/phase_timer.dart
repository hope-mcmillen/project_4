import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// An advisory countdown for a spoken phase (Trello CHM-14).
///
/// It only tells time. At zero it says so and stops; it never advances the
/// game and never disables a button, because clues and discussion are spoken
/// aloud and cutting someone off mid-sentence is worse than running long.
///
/// The countdown starts when this widget is first built and belongs to that
/// one placement: a widget with a new key, or at a new place in the tree,
/// starts from full again. That is how each clue turn gets its own timer —
/// `GameScreen` keys every clue turn separately.
class PhaseTimer extends StatefulWidget {
  const PhaseTimer({super.key, required this.label, required this.duration});

  /// What is being timed, e.g. "Clue time".
  final String label;

  /// The full countdown. Must be positive; `GameSettings` guarantees it.
  final Duration duration;

  @override
  State<PhaseTimer> createState() => _PhaseTimerState();
}

class _PhaseTimerState extends State<PhaseTimer> {
  static const _timeUp = 'Time’s up';

  late final Timer _timer;
  Duration _elapsed = Duration.zero;

  Duration get _left {
    final left = widget.duration - _elapsed;
    return left > Duration.zero ? left : Duration.zero;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer timer) {
    // Timer.tick counts every period since the start, including any the
    // platform delivered late, so a delayed callback catches up instead of
    // letting the countdown drift slow.
    setState(() => _elapsed = Duration(seconds: timer.tick));
    // Nothing left to show changing, so stop waking up.
    if (_left == Duration.zero) timer.cancel();
  }

  @override
  void dispose() {
    // A turn or phase often ends before zero. Without this the countdown
    // would keep firing into a widget that is no longer on screen.
    _timer.cancel();
    super.dispose();
  }

  // Whole seconds left, rounded up so the display reads 0:00 only at the
  // very end. The clock and the spoken label both use it, so they never
  // disagree by a second.
  static int _seconds(Duration left) => (left.inMilliseconds / 1000).ceil();

  static String _clock(Duration left) {
    final seconds = _seconds(left);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  // "1 minute 30 seconds", for a screen reader: "0:30" is read as digits.
  static String _inWords(Duration left) {
    final seconds = _seconds(left);
    String count(int n, String unit) => n == 1 ? '1 $unit' : '$n ${unit}s';
    return [
      if (seconds >= 60) count(seconds ~/ 60, 'minute'),
      if (seconds % 60 > 0) count(seconds % 60, 'second'),
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final done = _left == Duration.zero;
    // One spoken thing for the whole card, replacing the icon and the two
    // texts a reader would otherwise walk through, clock digits included.
    //
    // It is a live region only once time is up. A live region announces
    // whenever its label changes, so making it live while counting would
    // read out every second; made live at zero, the label change to "Time’s
    // up" is the single announcement, and the countdown stays silent for a
    // player who is busy listening to the person giving a clue.
    return Semantics(
      container: true,
      excludeSemantics: true,
      liveRegion: done,
      label: done
          ? '${widget.label}, $_timeUp'
          : '${widget.label}, ${_inWords(_left)} left',
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: done ? AppColors.mint : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              done ? Icons.timer_off_outlined : Icons.timer_outlined,
              color: AppColors.ink,
            ),
            const SizedBox(width: 12),
            // The label and the time share one Wrap inside the Expanded, so
            // at large text sizes the time drops under the label instead of
            // pushing the row wider than the card. Side by side, with the
            // time at the far end, whenever they fit.
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    done ? _timeUp : _clock(_left),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      // Fixed-width digits, so the text does not jiggle each
                      // second.
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
