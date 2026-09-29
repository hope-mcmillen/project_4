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

  // m:ss, rounded up so the display reads 0:00 only at the very end.
  static String _clock(Duration left) {
    final seconds = (left.inMilliseconds / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final done = _left == Duration.zero;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: done ? AppColors.lime : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.timer_off_outlined : Icons.timer_outlined,
            color: AppColors.ink,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          Text(
            done ? 'Time’s up' : _clock(_left),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              // Fixed-width digits, so the text does not jiggle each second.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
