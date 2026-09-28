import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../game/data/topic_packs.dart';
import '../../game/widgets/game_widgets.dart';
import '../logic/host_lobby_controller.dart';
import '../logic/room_repository.dart';

/// The host's side of an online room. Owns the [HostLobbyController] for as
/// long as the host stays here; leaving this screen ends the host session.
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key, required this.rooms});

  final RoomRepository rooms;

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  late final _host = HostLobbyController(widget.rooms);
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  String _topicId = topicPacks.first.id;

  @override
  void dispose() {
    _host.dispose();
    _name.dispose();
    super.dispose();
  }

  void _create() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _host.createRoom(hostName: _name.text, topicId: _topicId);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _host,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Host a room')),
      body: switch (_host.phase) {
        HostLobbyPhase.setup || HostLobbyPhase.creating => _buildForm(context),
        _ => PageBody(
          children: [
            const Eyebrow('Your room code'),
            Text(
              _host.room!.code,
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ],
        ),
      },
    ),
  );

  Widget _buildForm(BuildContext context) {
    final creating = _host.phase == HostLobbyPhase.creating;
    return Form(
      key: _form,
      child: PageBody(
        children: [
          const Eyebrow('Everyone on their own phone'),
          Text(
            'Start a room',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'You’ll get a code to share. Friends join from their phones.',
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _name,
            enabled: !creating,
            maxLength: 20,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _create(),
            decoration: const InputDecoration(
              labelText: 'Your name',
              counterText: '',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Enter your name.' : null,
          ),
          const SizedBox(height: 24),
          const Eyebrow('Pick your topic'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final topic in topicPacks)
                ChoiceChip(
                  label: Text(topic.name),
                  selected: _topicId == topic.id,
                  selectedColor: AppColors.lime,
                  onSelected: creating
                      ? null
                      : (_) => setState(() => _topicId = topic.id),
                ),
            ],
          ),
          if (_host.error case final error?) ...[
            const SizedBox(height: 16),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: creating ? null : _create,
            icon: creating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering_rounded),
            label: Text(creating ? 'Creating room…' : 'Create room'),
          ),
        ],
      ),
    );
  }
}
