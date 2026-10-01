import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../game/models/topic_pack.dart';
import '../../game/widgets/game_widgets.dart';
import '../supabase_online_repository.dart';

/// One device per player. The database owns all game transitions and secrets.
class SupabaseOnlineScreen extends StatefulWidget {
  const SupabaseOnlineScreen({
    super.key,
    required this.client,
    required this.joining,
  });
  final SupabaseClient client;
  final bool joining;

  @override
  State<SupabaseOnlineScreen> createState() => _SupabaseOnlineScreenState();
}

class _SupabaseOnlineScreenState extends State<SupabaseOnlineScreen>
    with WidgetsBindingObserver {
  late final SupabaseOnlineRepository repo = SupabaseOnlineRepository(
    widget.client,
  );
  final name = TextEditingController();
  final code = TextEditingController();
  final clue = TextEditingController();
  String? roomId;
  Map<String, dynamic>? room;
  List<Map<String, dynamic>> members = [];
  List<TopicPack> topics = [];
  String? selectedTopic;
  String? selectedVote;
  String? selectedGuess;
  Map<String, dynamic>? privateRole;
  bool roleVisible = false;
  bool busy = true;
  String? error;
  Timer? refreshTimer;
  RealtimeChannel? channel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      setState(() => roleVisible = false);
    }
  }

  Future<void> _initialize() async {
    try {
      await repo.signIn();
      // Online rooms must use the live catalog. An offline fallback may name a
      // topic that the server does not have.
      final rows = await repo.topics();
      final loaded = rows
          .map(
            (row) => TopicPack(
              id: row['id'] as String,
              name: row['name'] as String,
              words: (row['words'] as List).cast<String>(),
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        topics = loaded;
        selectedTopic = loaded.firstOrNull?.id;
        busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = _message(e);
          busy = false;
        });
      }
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (roomId != null) await _refresh();
    } catch (e) {
      if (mounted) setState(() => error = _message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _message(Object e) {
    if (e is PostgrestException) return e.message;
    if (e is AuthException) return e.message;
    return 'Connection failed. Check your internet and try again.';
  }

  Future<void> _enter() async {
    final player = name.text.trim();
    if (player.isEmpty || player.length > 20) {
      setState(() => error = 'Enter a name of 1–20 characters.');
      return;
    }
    if (widget.joining && code.text.trim().length != 6) {
      setState(() => error = 'Enter the six-character room code.');
      return;
    }
    if (!widget.joining && selectedTopic == null) {
      setState(() => error = 'Choose a topic.');
      return;
    }
    await _act(() async {
      final id = widget.joining
          ? await repo.join(code.text.trim().toUpperCase(), player)
          : await repo.create(player, selectedTopic!);
      if (!mounted) return;
      roomId = id;
      await _refresh();
      // Realtime makes changes immediate. Polling also recovers a dropped socket.
      channel = widget.client.channel('online:$id')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'online_rooms',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: id,
          ),
          callback: (_) => _refresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'online_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: id,
          ),
          callback: (_) => _refresh(),
        )
        ..subscribe();
      refreshTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _refresh(),
      );
    });
  }

  Future<void> _refresh() async {
    final id = roomId;
    if (id == null) return;
    try {
      final nextRoom = await repo.room(id);
      final nextMembers = nextRoom == null
          ? <Map<String, dynamic>>[]
          : await repo.members(id);
      if (!mounted || roomId != id) return;
      final phase = nextRoom?['status'] as String?;
      if (phase != 'reveal') {
        privateRole = null;
        roleVisible = false;
      }
      setState(() {
        room = nextRoom;
        members = nextMembers;
      });
    } catch (e) {
      if (mounted) setState(() => error = _message(e));
    }
  }

  Future<void> _leave() async {
    if (roomId != null && room?['status'] == 'lobby') {
      try {
        await repo.leave(roomId!);
      } catch (_) {
        /* Leave locally on outage. */
      }
    }
    refreshTimer?.cancel();
    if (channel != null) widget.client.removeChannel(channel!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refreshTimer?.cancel();
    if (channel != null) widget.client.removeChannel(channel!);
    name.dispose();
    code.dispose();
    clue.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get me {
    for (final member in members) {
      if (member['user_id'] == repo.userId) return member;
    }
    return null;
  }

  bool get isHost => room?['host_id'] == repo.userId;

  TopicPack? get topic {
    final id = room?['topic_id'] ?? selectedTopic;
    for (final pack in topics) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  Widget _button(String label, VoidCallback? onPressed) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: FilledButton(onPressed: busy ? null : onPressed, child: Text(label)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        roomId == null
            ? (widget.joining ? 'Join online' : 'Host online')
            : 'Online game',
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _leave,
      ),
    ),
    body: PageBody(
      children: [
        if (error != null)
          InfoCard(
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        if (busy && roomId == null)
          const Center(child: CircularProgressIndicator()),
        if (roomId == null && !busy) ..._entry(),
        if (roomId != null && room == null)
          const InfoCard(child: Text('Room closed or connection lost.')),
        if (room != null) ..._game(),
      ],
    ),
  );

  List<Widget> _entry() => [
    Text(
      widget.joining ? 'Join your friends' : 'Create a room',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 16),
    TextField(
      controller: name,
      maxLength: 20,
      decoration: const InputDecoration(labelText: 'Your name'),
    ),
    if (widget.joining)
      TextField(
        controller: code,
        maxLength: 6,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(labelText: 'Room code'),
      ),
    if (!widget.joining) ...[
      const Text('Choose a topic. Everyone can see the word board.'),
      for (final pack in topics)
        ListTile(
          title: Text(pack.name),
          subtitle: Text(pack.words.join(' · ')),
          leading: Icon(
            selectedTopic == pack.id
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          onTap: () => setState(() => selectedTopic = pack.id),
        ),
    ],
    _button(widget.joining ? 'Join room' : 'Create room', _enter),
  ];

  List<Widget> _game() {
    final phase = room!['status'] as String;
    return [
      Text(
        'Room ${room!['code']}',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      Text('Share this code with each player on their own phone.'),
      const SizedBox(height: 12),
      Text('Topic: ${topic?.name ?? room!['topic_id']}'),
      if (phase == 'lobby') ..._lobby(),
      if (phase == 'reveal') ..._reveal(),
      if (phase == 'clues') ..._clues(),
      if (phase == 'discussion') ..._discussion(),
      if (phase == 'voting') ..._voting(),
      if (phase == 'guess') ..._guess(),
      if (phase == 'result') ..._result(),
    ];
  }

  List<Widget> _lobby() => [
    const SizedBox(height: 16),
    Text(
      'Players (${members.length}/8)',
      style: Theme.of(context).textTheme.titleLarge,
    ),
    for (final player in members)
      ListTile(
        title: Text(player['name'] as String),
        trailing: Text(player['ready'] == true ? 'Ready' : 'Waiting'),
      ),
    if (isHost) ...[
      const Text('Change topic (everyone will need to ready up again):'),
      for (final pack in topics)
        ListTile(
          title: Text(pack.name),
          leading: Icon(
            room!['topic_id'] == pack.id
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          onTap: busy || pack.id == room!['topic_id']
              ? null
              : () => _act(() => repo.topic(roomId!, pack.id)),
        ),
    ],
    _button(
      me?['ready'] == true ? 'Not ready' : 'Ready',
      () => _act(() => repo.ready(roomId!, me?['ready'] != true)),
    ),
    if (isHost)
      _button(
        'Start round',
        members.length < 3 || members.any((p) => p['ready'] != true)
            ? null
            : () => _act(() => repo.start(roomId!)),
      ),
  ];

  List<Widget> _reveal() => [
    const SizedBox(height: 16),
    Text('Secret role', style: Theme.of(context).textTheme.titleLarge),
    const Text('Make sure nobody else can see your screen.'),
    if (me?['revealed'] == true)
      const InfoCard(
        child: Text('Role hidden. Waiting for everyone to finish.'),
      )
    else if (!roleVisible)
      _button(
        'Reveal my role',
        () => _act(() async {
          privateRole = await repo.role(roomId!);
          if (mounted) setState(() => roleVisible = true);
        }),
      )
    else ...[
      InfoCard(
        child: Text(
          privateRole?['is_chameleon'] == true
              ? 'You are the Chameleon. Blend in without knowing the word.'
              : 'The secret word is: ${privateRole?['word']}',
        ),
      ),
      _button(
        'Hide role and continue',
        () => _act(() async {
          setState(() => roleVisible = false);
          await repo.finishReveal(roomId!);
        }),
      ),
    ],
    Text(
      '${members.where((p) => p['revealed'] == true).length} of '
      '${members.length} players ready to continue',
    ),
  ];

  List<Widget> _clues() {
    final turn = room!['turn'];
    final current = members.where((p) => p['seat'] == turn).firstOrNull;
    return [
      const SizedBox(height: 16),
      Text('Give one clue', style: Theme.of(context).textTheme.titleLarge),
      Text('It is ${current?['name'] ?? 'the next player'}\'s turn.'),
      if (current?['user_id'] == repo.userId) ...[
        TextField(
          controller: clue,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'One-word clue'),
        ),
        _button('Send clue', () {
          final value = clue.text.trim();
          if (value.isEmpty || value.contains(RegExp(r'\s'))) {
            setState(() => error = 'Enter one word.');
            return;
          }
          _act(() async {
            await repo.clue(roomId!, value);
            clue.clear();
          });
        }),
      ],
      for (final player in members)
        ListTile(
          title: Text(player['name'] as String),
          trailing: Text(player['clue'] as String? ?? '…'),
        ),
    ];
  }

  List<Widget> _discussion() => [
    const SizedBox(height: 16),
    Text('Discuss the clues', style: Theme.of(context).textTheme.titleLarge),
    const Text('Talk in person or on a voice call. Who seems suspicious?'),
    for (final player in members)
      ListTile(
        title: Text(player['name'] as String),
        trailing: Text(player['clue'] as String? ?? ''),
      ),
    if (isHost)
      _button('Start voting', () => _act(() => repo.startVoting(roomId!))),
  ];

  List<Widget> _voting() => [
    const SizedBox(height: 16),
    Text('Vote privately', style: Theme.of(context).textTheme.titleLarge),
    const Text('Pick the Chameleon. You cannot vote for yourself.'),
    for (final player in members)
      if (player['user_id'] != repo.userId)
        ListTile(
          title: Text(player['name'] as String),
          leading: Icon(
            selectedVote == player['user_id']
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          onTap: me?['voted'] == true
              ? null
              : () =>
                    setState(() => selectedVote = player['user_id'] as String),
        ),
    if (me?['voted'] != true && selectedVote != null)
      _button('Cast vote', () => _act(() => repo.vote(roomId!, selectedVote!))),
    const Text('Results appear after everyone votes.'),
  ];

  List<Widget> _guess() => [
    const SizedBox(height: 16),
    Text(
      'The Chameleon was caught!',
      style: Theme.of(context).textTheme.titleLarge,
    ),
    const Text('One last chance: guess the secret word from the topic board.'),
    if (room!['result_chameleon'] == repo.userId && topic != null) ...[
      for (final word in topic!.words)
        ListTile(
          title: Text(word),
          leading: Icon(
            selectedGuess == word
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          onTap: () => setState(() => selectedGuess = word),
        ),
      if (selectedGuess != null)
        _button(
          'Submit guess',
          () => _act(() => repo.guess(roomId!, selectedGuess!)),
        ),
    ] else
      const Text('Waiting for the Chameleon’s guess.'),
  ];

  List<Widget> _result() {
    final chameleon = members
        .where((p) => p['user_id'] == room!['result_chameleon'])
        .firstOrNull;
    return [
      const SizedBox(height: 16),
      Text(
        room!['result_winner'] == 'group'
            ? 'The group wins!'
            : 'The Chameleon wins!',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(room!['result_reason'] as String? ?? ''),
            Text('Secret word: ${room!['result_word']}'),
            Text('Chameleon: ${chameleon?['name'] ?? 'Unknown'}'),
          ],
        ),
      ),
      const Text('Votes:'),
      for (final player in members)
        ListTile(
          title: Text(player['name'] as String),
          trailing: Text(
            '${(room!['vote_counts'] as Map?)?[player['user_id']] ?? 0}',
          ),
        ),
      _button('Done', _leave),
    ];
  }
}
