import 'package:flutter/material.dart';

import '../logic/game_repository.dart';
import '../logic/game_session.dart';
import '../models/game_phase.dart';
import '../models/player_view.dart';
import 'phases/clues_phase.dart';
import 'phases/discussion_phase.dart';
import 'phases/guess_phase.dart';
import 'phases/results_phase.dart';
import 'phases/reveal_phase.dart';
import 'phases/voting_phase.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.createGame});

  /// Builds a fresh round; called again for each replay.
  final GameRepository Function() createGame;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late GameRepository _game;

  // Outlives each round so the score carries across replays. It lives exactly
  // as long as this screen: leaving for setup ends the session.
  late final GameSession _session;
  bool _allowExit = false;
  bool _exitDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _game = widget.createGame();
    _session = GameSession(players: _game.view.players);
    _game.addListener(_recordRound);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.removeListener(_recordRound);
    _game.dispose();
    super.dispose();
  }

  // Scoring hangs off the round's own change notification, not off build()
  // (which runs many times per result) and not off Play again (which would
  // leave the round just finished out of the standings shown with it). The
  // session ignores unfinished rounds and rounds it has already counted.
  void _recordRound() => _session.recordRound(_game);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _game.hidePrivateView();
  }

  Future<void> _requestExit() async {
    if (_exitDialogOpen) return;
    _game.hidePrivateView();
    _exitDialogOpen = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this round?'),
        content: const Text(
          'This round will be lost. Your player setup will still be here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave round'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (leave != true || !mounted) return;
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _replay() {
    final previous = _game..removeListener(_recordRound);
    setState(() => _game = widget.createGame()..addListener(_recordRound));
    previous.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _game,
    builder: (context, _) {
      final view = _game.view;
      return PopScope(
        canPop: _allowExit || view.phase == GamePhase.result,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _requestExit();
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              tooltip: 'Leave round',
              icon: const Icon(Icons.close),
              onPressed: () {
                if (view.phase == GamePhase.result) {
                  Navigator.of(context).pop();
                } else {
                  _requestExit();
                }
              },
            ),
            title: const Text('Chameleon'),
          ),
          body: _phase(view),
        ),
      );
    },
  );

  Widget _phase(PlayerView view) {
    // A fresh key per handoff gives every private screen a new scroll position
    // and discards any tentative selection, so roles never share a frame.
    final key = ValueKey('${view.phase}-${view.turn}-${view.privateOpen}');
    return switch (view.phase) {
      GamePhase.reveal => RevealPhase(
        key: key,
        view: view,
        onReveal: _game.openPrivateView,
        onContinue: _game.finishReveal,
      ),
      GamePhase.clues => CluesPhase(
        key: key,
        view: view,
        onNext: _game.finishClue,
      ),
      GamePhase.discussion => DiscussionPhase(
        key: key,
        view: view,
        onReadyToVote: _game.startVoting,
      ),
      GamePhase.voting => VotingPhase(
        key: key,
        view: view,
        onOpenBallot: _game.openPrivateView,
        onConfirmVote: _game.castVote,
      ),
      GamePhase.guess => GuessPhase(
        key: key,
        view: view,
        onGuess: _game.guessWord,
      ),
      GamePhase.result => ResultsPhase(
        key: key,
        view: view,
        session: _session,
        onReplay: _replay,
        onLeave: () => Navigator.of(context).pop(),
      ),
    };
  }
}
