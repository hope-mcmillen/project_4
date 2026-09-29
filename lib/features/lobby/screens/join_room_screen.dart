import 'package:flutter/material.dart';

import '../../game/widgets/game_widgets.dart';
import '../logic/join_room_controller.dart';
import '../logic/room_repository.dart';

/// A guest's side of an online room. Owns the [JoinRoomController] for as
/// long as the player stays here; leaving this screen leaves the session.
class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key, required this.rooms, this.initialCode});

  final RoomRepository rooms;

  /// Prefills the code field, e.g. from a shared link later on.
  final String? initialCode;

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  late final _guest = JoinRoomController(widget.rooms);
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.initialCode);
  final _name = TextEditingController();

  @override
  void dispose() {
    _guest.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  void _join() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _guest.join(code: _code.text, name: _name.text);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _guest,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Join a room')),
      body: switch (_guest.phase) {
        JoinPhase.entry || JoinPhase.joining => _buildForm(context),
        _ => PageBody(
          children: [
            const Eyebrow('You’re in'),
            Text(
              _guest.room!.code,
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ],
        ),
      },
    ),
  );

  Widget _buildForm(BuildContext context) {
    final joining = _guest.phase == JoinPhase.joining;
    return Form(
      key: _form,
      child: PageBody(
        children: [
          const Eyebrow('Got a code?'),
          Text(
            'Join your friends',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('Ask the host for the room code on their screen.'),
          const SizedBox(height: 24),
          TextFormField(
            controller: _code,
            enabled: !joining,
            maxLength: 7,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              letterSpacing: 4,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              labelText: 'Room code',
              counterText: '',
              prefixIcon: Icon(Icons.tag_rounded),
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Enter the room code.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            enabled: !joining,
            maxLength: 20,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _join(),
            decoration: const InputDecoration(
              labelText: 'Your name',
              counterText: '',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Enter your name.' : null,
          ),
          if (_guest.error case final error?) ...[
            const SizedBox(height: 16),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: joining ? null : _join,
            icon: joining
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login_rounded),
            label: Text(joining ? 'Joining…' : 'Join room'),
          ),
        ],
      ),
    );
  }
}
