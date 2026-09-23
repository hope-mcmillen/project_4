import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../logic/game_controller.dart';
import '../models/topic_pack.dart';
import '../widgets/game_widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.players, required this.topic});
  final List<String> players;
  final TopicPack topic;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late GameController _game;
  int? _suspect;
  String? _guess;
  bool _allowExit = false;
  bool _exitDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _game = GameController(players: widget.players, topic: widget.topic);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _game.hidePrivateView();
      if (_suspect != null) setState(() => _suspect = null);
    }
  }

  Future<void> _requestExit() async {
    if (_exitDialogOpen) return;
    _game.hidePrivateView();
    setState(() => _suspect = null);
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
    final previous = _game;
    setState(() {
      _game = GameController(players: widget.players, topic: widget.topic);
      _suspect = null;
      _guess = null;
    });
    previous.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _game,
    builder: (context, _) => PopScope(
      canPop: _allowExit || _game.phase == GamePhase.result,
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
              if (_game.phase == GamePhase.result) {
                Navigator.of(context).pop();
              } else {
                _requestExit();
              }
            },
          ),
          title: const Text('Chameleon'),
        ),
        // A fresh scroll position for every handoff prevents roles sharing a frame.
        body: PageBody(
          key: ValueKey('${_game.phase}-${_game.turn}-${_game.privateOpen}'),
          children: switch (_game.phase) {
            GamePhase.reveal => _reveal(context),
            GamePhase.clues => _clues(context),
            GamePhase.discussion => _discussion(context),
            GamePhase.voting => _voting(context),
            GamePhase.guess => _lastGuess(context),
            GamePhase.result => _results(context),
          },
        ),
      ),
    ),
  );

  List<Widget> _handoff(BuildContext context, {required bool voting}) => [
    Eyebrow(
      '${voting ? 'Private vote' : 'Secret roles'} • ${_game.turn + 1} of ${_game.players.length}',
    ),
    Text('Pass the phone to', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 8),
    Text(_game.currentPlayer, style: Theme.of(context).textTheme.displaySmall),
    const InfoCard(
      color: AppColors.lime,
      child: Column(
        children: [
          Icon(Icons.lock_outline_rounded, size: 64, color: AppColors.ink),
          SizedBox(height: 16),
          Text(
            'For your eyes only.',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Make sure no one else can see the screen before you continue.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
    FilledButton.icon(
      onPressed: _game.openPrivateView,
      icon: const Icon(Icons.visibility_outlined),
      label: Text(voting ? 'Open my ballot' : 'Reveal my role'),
    ),
  ];

  List<Widget> _reveal(BuildContext context) {
    if (!_game.privateOpen) return _handoff(context, voting: false);
    final chameleon = _game.isRevealedChameleon;
    return [
      Eyebrow('${_game.currentPlayer} • Keep this secret'),
      Text(
        chameleon ? 'You’re the\nChameleon.' : 'You’re in\non the secret.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      InfoCard(
        color: chameleon ? const Color(0xFFE8E1FF) : AppColors.lime,
        child: Column(
          children: [
            Icon(
              chameleon ? Icons.visibility_off_outlined : Icons.key_rounded,
              size: 48,
              color: AppColors.ink,
            ),
            const SizedBox(height: 16),
            Text(
              chameleon ? 'Blend in. Listen closely.' : 'The secret word is',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (!chameleon)
              Text(
                _game.roleWord!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            if (chameleon)
              const Text(
                'You don’t know the word. Use the topic and everyone’s clues to bluff your way through.',
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 12),
            Text('Topic: ${_game.topic.name}', textAlign: TextAlign.center),
          ],
        ),
      ),
      FilledButton.icon(
        onPressed: _game.finishReveal,
        icon: const Icon(Icons.lock_outline),
        label: const Text('Hide & continue'),
      ),
      TopicBoard(topic: _game.topic),
    ];
  }

  List<Widget> _clues(BuildContext context) => [
    Eyebrow('Clue round • ${_game.turn + 1} of ${_game.players.length}'),
    Text(
      '${_game.currentPlayer},\nyour one word?',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 12),
    const Text(
      'Say your clue out loud. Make it convincing, but don’t make the secret too obvious.',
    ),
    TopicBoard(topic: _game.topic),
    FilledButton(
      onPressed: _game.finishClue,
      child: Text(
        _game.turn == _game.players.length - 1
            ? 'Clue given · Discuss'
            : 'Clue given · Next player',
      ),
    ),
  ];

  List<Widget> _discussion(BuildContext context) => [
    const Eyebrow('Connect the clues'),
    Text(
      'Someone’s\nblending in.',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const InfoCard(
      color: AppColors.lime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.forum_outlined, size: 40),
          SizedBox(height: 12),
          Text(
            'Whose clue felt a little off?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          SizedBox(height: 8),
          Text(
            'Discuss as a group. When everyone is ready, pass the phone for one private vote each. A tie lets the Chameleon escape.',
          ),
        ],
      ),
    ),
    FilledButton(
      onPressed: _game.startVoting,
      child: const Text('Ready to vote'),
    ),
    TopicBoard(topic: _game.topic),
  ];

  List<Widget> _voting(BuildContext context) {
    if (!_game.privateOpen) return _handoff(context, voting: true);
    return [
      Eyebrow('${_game.currentPlayer} • Private ballot'),
      Text(
        'Who’s the\nChameleon?',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      const Text(
        'Choose one other player. Your vote is final once you confirm.',
      ),
      const SizedBox(height: 24),
      for (var i = 0; i < _game.players.length; i++)
        if (i != _game.turn)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              selected: _suspect == i,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: _suspect == i
                      ? AppColors.lime
                      : Colors.white,
                ),
                onPressed: () => setState(() => _suspect = i),
                child: Row(
                  children: [
                    Icon(
                      _suspect == i ? Icons.check_circle : Icons.person_outline,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_game.players[i])),
                  ],
                ),
              ),
            ),
          ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _suspect == null
            ? null
            : () {
                final selected = _suspect!;
                _suspect = null;
                _game.castVote(selected);
              },
        child: const Text('Confirm & hide vote'),
      ),
    ];
  }

  List<Widget> _lastGuess(BuildContext context) => [
    const Eyebrow('Caught… or almost'),
    Text(
      '${_game.chameleonName} is\nthe Chameleon!',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 12),
    const Text(
      'Pass the phone to the Chameleon. You have one final guess. Choose the secret word to steal the win.',
    ),
    TopicBoard(
      topic: _game.topic,
      selected: _guess,
      onSelect: (word) => setState(() => _guess = word),
    ),
    FilledButton(
      onPressed: _guess == null ? null : () => _game.guessWord(_guess!),
      child: const Text('Lock in final guess'),
    ),
  ];

  List<Widget> _results(BuildContext context) => [
    const Eyebrow('The secret is out'),
    Text(
      _game.winner == RoundWinner.group
          ? 'Good instincts.\nThe group wins!'
          : 'Master of disguise.\nChameleon wins!',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 12),
    Text(_game.resultReason!),
    InfoCard(
      color: AppColors.lime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('The secret word'),
          Text(
            _game.secretWord!,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Chameleon: ${_game.chameleonName}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    ),
    InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('How the votes landed'),
          for (var i = 0; i < _game.players.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(_game.players[i])),
                  Text('${_game.voteCounts[i]} votes'),
                ],
              ),
            ),
        ],
      ),
    ),
    FilledButton.icon(
      onPressed: _replay,
      icon: const Icon(Icons.replay),
      label: const Text('Play again · Same crew'),
    ),
    const SizedBox(height: 12),
    OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Change players or topic'),
    ),
  ];
}
