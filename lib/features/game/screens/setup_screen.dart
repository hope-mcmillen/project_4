import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/local_word_repository.dart';
import '../data/word_repository.dart';
import '../logic/game_controller.dart';
import '../logic/local_game_repository.dart';
import '../models/topic_pack.dart';
import '../widgets/game_widgets.dart';
import 'game_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    this.wordRepository = const LocalWordRepository(),
  });

  final WordRepository wordRepository;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _form = GlobalKey<FormState>();
  final _names = List.generate(
    4,
    (index) => TextEditingController(text: 'Player ${index + 1}'),
  );
  List<TopicPack> _topics = const [];
  TopicPack? _topic;
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final topics = await widget.wordRepository.getTopics();
      if (!mounted) return;
      setState(() {
        _topics = topics;
        _topic = topics.firstOrNull;
        _loading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _previewTopic(TopicPack topic) async {
    FocusScope.of(context).unfocus();
    final choose = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Take a peek',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Know this topic? Preview all ${topic.words.length} words before choosing. The secret word is picked only when the round starts.',
                ),
                TopicBoard(topic: topic),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Choose this topic'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep browsing'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (choose == true && mounted) setState(() => _topic = topic);
  }

  @override
  void dispose() {
    for (final name in _names) {
      name.dispose();
    }
    super.dispose();
  }

  void _addPlayer() {
    var number = _names.length + 1;
    while (_names.any(
      (name) => name.text.trim().toLowerCase() == 'player $number',
    )) {
      number++;
    }
    setState(() => _names.add(TextEditingController(text: 'Player $number')));
  }

  void _removePlayer(int index) {
    final removed = _names[index];
    setState(() => _names.removeAt(index));
    // Wait for the old TextField to unmount before disposing its controller.
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Set up your game')),
    body: Form(
      key: _form,
      child: PageBody(
        children: [
          const Eyebrow('Gather the usual suspects'),
          Text(
            'Who’s playing?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('Add 3–8 players. Use names everyone recognizes.'),
          const SizedBox(height: 24),
          for (var i = 0; i < _names.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ObjectKey(_names[i]),
                      controller: _names[i],
                      maxLength: 20,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Player ${i + 1}',
                        counterText: '',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) {
                        final name = (value ?? '').trim();
                        if (name.isEmpty) return 'Enter a name.';
                        if (_names
                                .where(
                                  (entry) =>
                                      entry.text.trim().toLowerCase() ==
                                      name.toLowerCase(),
                                )
                                .length >
                            1) {
                          return 'Each player needs a different name.';
                        }
                        return null;
                      },
                    ),
                  ),
                  if (_names.length > 3)
                    IconButton(
                      tooltip: 'Remove player ${i + 1}',
                      onPressed: () => _removePlayer(i),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                ],
              ),
            ),
          if (_names.length < 8)
            OutlinedButton.icon(
              onPressed: _addPlayer,
              icon: const Icon(Icons.add),
              label: const Text('Add player'),
            ),
          const SizedBox(height: 32),
          const Eyebrow('Pick your topic'),
          const Text(
            'Tap a topic to preview its words, then choose what your group knows.',
          ),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator(semanticsLabel: 'Loading topics'),
          if (_loadFailed) ...[
            const Text('Couldn’t load topics. Please try again.'),
            TextButton(onPressed: _loadTopics, child: const Text('Try again')),
          ],
          if (!_loading && !_loadFailed && _topics.isEmpty)
            const Text('No topics are available yet.'),
          if (_topic != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                liveRegion: true,
                child: TopicBanner(title: 'Selected topic: ${_topic!.name}'),
              ),
            ),
          for (final topic in _topics)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Semantics(
                selected: _topic?.id == topic.id,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _topic?.id == topic.id
                        ? AppColors.mint
                        : AppColors.card,
                    padding: const EdgeInsets.all(18),
                  ),
                  onPressed: () => _previewTopic(topic),
                  child: Row(
                    children: [
                      Icon(
                        _topic?.id == topic.id
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(topic.name)),
                      Text(
                        '${topic.words.length} words',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.visibility_outlined,
                        semanticLabel: 'Preview topic',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading || _loadFailed || _topic == null
                ? null
                : () {
                    if (!_form.currentState!.validate()) return;
                    FocusScope.of(context).unfocus();
                    final players = _names
                        .map((name) => name.text.trim())
                        .toList();
                    final topic = _topic!;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GameScreen(
                          createGame: () => LocalGameRepository(
                            GameController(players: players, topic: topic),
                          ),
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.lock_outline),
            label: const Text('Deal secret roles'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pass-and-play • Keep the screen to yourself',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
