import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/topic_packs.dart';
import '../models/topic_pack.dart';
import '../widgets/game_widgets.dart';
import 'game_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _form = GlobalKey<FormState>();
  final _names = List.generate(
    4,
    (index) => TextEditingController(text: 'Player ${index + 1}'),
  );
  TopicPack _topic = topicPacks.first;

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
          for (final topic in topicPacks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Semantics(
                selected: _topic.id == topic.id,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _topic.id == topic.id
                        ? AppColors.lime
                        : Colors.white,
                    padding: const EdgeInsets.all(18),
                  ),
                  onPressed: () => setState(() => _topic = topic),
                  child: Row(
                    children: [
                      Icon(
                        _topic.id == topic.id
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(topic.name)),
                      Text(
                        '${topic.words.length} words',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              FocusScope.of(context).unfocus();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GameScreen(
                    players: _names.map((name) => name.text.trim()).toList(),
                    topic: _topic,
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
