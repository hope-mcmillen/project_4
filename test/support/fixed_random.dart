import 'dart:math';

/// A deterministic source makes outcome tests independent of production randomness.
/// First call picks index 0 (the Chameleon); later calls pick index 1 (the word).
class FixedRandom implements Random {
  int _calls = 0;
  @override
  int nextInt(int max) => (_calls++ == 0 ? 0 : 1) % max;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}
