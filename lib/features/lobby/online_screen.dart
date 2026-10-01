import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../game/data/topic_packs.dart';
import '../game/widgets/game_widgets.dart';
import 'firebase_room_repository.dart';
import 'room_repository.dart';

// The deployed lobby currently supports the original three boards.
// Keep the expanded offline catalog independent of that server contract.
final _lobbyTopics = topicPacks
    .where((topic) => const {'food', 'places', 'hobbies'}.contains(topic.id))
    .toList(growable: false);

class OnlineScreen extends StatefulWidget {
  const OnlineScreen({super.key, this.repository});
  final RoomRepository? repository;

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  late final RoomRepository _repository;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _connected = false;
  bool _busy = false;
  bool _joining = false;
  bool _allowExit = false;
  String _topic = _lobbyTopics.first.id;
  String? _error;
  String? _roomId;
  Stream<RoomView>? _room;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseRoomRepository();
    _connect();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _roomId != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is LobbyException
              ? error.message
              : 'Could not connect to the lobby. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _enter(String id) {
    _roomId = id;
    _room = _repository.watchRoom(id);
  }

  Future<void> _connect() => _perform(() async {
    final existing = await _repository.connect();
    if (!mounted) return;
    setState(() {
      _connected = true;
      if (existing != null) _enter(existing);
    });
  });

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await _perform(() async {
      final id = _joining
          ? await _repository.joinRoom(_code.text, _name.text.trim())
          : await _repository.createRoom(_name.text.trim(), _topic);
      if (mounted) setState(() => _enter(id));
    });
  }

  Future<void> _leave() => _perform(() async {
    await _repository.leaveRoom(_roomId!);
    if (!mounted) return;
    setState(() {
      _roomId = null;
      _room = null;
    });
  });

  void _closeScreen() {
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit || (!_busy && _roomId == null),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_busy) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(_roomId == null ? 'Play online' : 'Game lobby'),
      ),
      body: _roomId == null
          ? _entry()
          : StreamBuilder<RoomView>(
              stream: _room,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return PageBody(
                    children: [
                      const Text(
                        'This lobby is unavailable. It may have expired, or your connection was interrupted.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _room = _repository.watchRoom(_roomId!);
                              }),
                        child: const Text('Retry connection'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _leave,
                        child: const Text('Leave lobby'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _closeScreen,
                        child: const Text('Return home'),
                      ),
                      ..._feedback(),
                    ],
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _lobby(snapshot.data!);
              },
            ),
    ),
  );

  List<Widget> _feedback() => [
    if (_busy)
      const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      ),
    if (_error != null)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Semantics(
          liveRegion: true,
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
  ];

  Widget _entry() => PageBody(
    children: [
      const Eyebrow('Your friends. Your own phone.'),
      Text(
        'Meet in a lobby.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      const Text(
        'Create a game code or join your friends. Online lobbies are ready to try; online rounds are coming next.',
      ),
      ..._feedback(),
      if (!_connected && !_busy)
        FilledButton(
          onPressed: _connect,
          child: const Text('Retry connection'),
        ),
      if (_connected)
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Create game')),
                  ButtonSegment(value: true, label: Text('Join game')),
                ],
                selected: {_joining},
                onSelectionChanged: _busy
                    ? null
                    : (values) => setState(() {
                        _joining = values.single;
                        _error = null;
                      }),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                enabled: !_busy,
                maxLength: 20,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Your name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your name.'
                    : null,
              ),
              if (_joining)
                TextFormField(
                  controller: _code,
                  enabled: !_busy,
                  maxLength: 6,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Game code',
                    hintText: 'K7MXQ2',
                  ),
                  validator: (value) =>
                      RegExp(r'^[A-HJ-NP-Z2-9]{6}$')
                          .hasMatch((value ?? '').trim().toUpperCase())
                      ? null
                      : 'Enter the six-character code.',
                )
              else ...[
                const Eyebrow('Choose a topic'),
                for (final topic in _lobbyTopics)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _topic = topic.id),
                      child: Text(
                        '${_topic == topic.id ? '✓ ' : ''}${topic.name}',
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_joining ? 'Join lobby' : 'Create lobby'),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _lobby(RoomView room) {
    final mine = room.players
        .where((p) => p.id == _repository.playerId)
        .firstOrNull;
    final expired = !room.expiresAt.isAfter(DateTime.now());
    final enabled = !_busy && !room.isFromCache && !expired && mine != null;
    final host = room.hostId == _repository.playerId;
    return PageBody(
      children: [
        const Eyebrow('Invite your usual suspects'),
        Text(room.code, style: Theme.of(context).textTheme.displaySmall),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: room.code));
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Game code copied')));
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy game code'),
        ),
        if (room.isFromCache)
          const Text('Connecting… showing the last known lobby.'),
        if (expired)
          const Text('This lobby has expired. Leave and create a new one.'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Eyebrow('${room.players.length} of 8 players'),
              for (final player in room.players)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    player.ready ? Icons.check_circle : Icons.person_outline,
                    color: player.ready ? AppColors.teal : AppColors.muted,
                  ),
                  title: Text(
                    '${player.name}${player.id == _repository.playerId ? ' (you)' : ''}',
                  ),
                  subtitle: Text(
                    '${player.id == room.hostId ? 'Host · ' : ''}${player.ready ? 'Ready' : 'Not ready'}',
                  ),
                ),
            ],
          ),
        ),
        const Eyebrow('Topic'),
        for (final topic in _lobbyTopics)
          if (host || topic.id == room.topicId)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: topic.id == room.topicId
                      ? AppColors.sage
                      : null,
                ),
                onPressed: host && enabled
                    ? () => _perform(
                        () => _repository.setTopic(room.id, topic.id),
                      )
                    : null,
                child: Text(topic.name),
              ),
            ),
        if (host)
          const Text('Changing the topic resets everyone’s ready status.'),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: enabled
              ? () => _perform(() => _repository.setReady(room.id, !mine.ready))
              : null,
          child: Text(mine?.ready == true ? 'Not ready' : 'I’m ready'),
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            expired
                ? 'Lobby expired.'
                : room.isFromCache
                ? 'Waiting for connection…'
                : room.everyoneReady
                ? 'Everyone is ready! Online rounds are coming next.'
                : room.players.length < 3
                ? 'Invite at least ${3 - room.players.length} more player(s).'
                : 'Waiting for everyone to get ready.',
          ),
        ),
        ..._feedback(),
        TextButton(
          onPressed: _busy ? null : _leave,
          child: const Text('Leave lobby'),
        ),
      ],
    );
  }
}
