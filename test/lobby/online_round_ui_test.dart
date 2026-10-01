import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project_4/app/theme.dart';
import 'package:project_4/features/game/widgets/game_widgets.dart';
import 'package:project_4/features/lobby/screens/supabase_online_screen.dart';
import 'package:project_4/features/lobby/supabase_online_repository.dart';
import 'package:project_4/features/lobby/widgets/room_code_badge.dart';

class OnlineFake extends SupabaseOnlineRepository {
  OnlineFake(super.client, {this.host = true});
  final bool host;
  String phase = 'discussion';
  int clueRound = 1;
  int turn = 0;
  int repeats = 0;
  bool failRepeat = false;
  bool chameleon = true;
  VoidCallback? changed;
  @override
  String get userId => host ? 'host' : 'guest';
  @override
  Future<void> signIn() async {}
  @override
  Future<List<Map<String, dynamic>>> topics() async => [
    {
      'id': 'food',
      'name': 'Food & drink',
      'words': ['Pizza', 'Sushi'],
    },
  ];
  @override
  Future<String> create(String name, String topic) async => 'room';
  @override
  Future<String> join(String code, String name) async => 'room';
  @override
  RealtimeChannel? watch(String id, VoidCallback onChange) {
    changed = onChange;
    return null;
  }

  @override
  Future<Map<String, dynamic>?> room(String id) async => {
    'id': id,
    'host_id': 'host',
    'code': 'ABC234',
    'topic_id': 'food',
    'status': phase,
    'turn': phase == 'clues' ? turn : null,
    'clue_round': clueRound,
  };
  @override
  Future<List<Map<String, dynamic>>> members(String id) async => [
    for (final (index, player) in ['host', 'guest', 'third'].indexed)
      {
        'user_id': player,
        'name': player,
        'seat': index,
        'revealed': false,
        'clue': phase == 'discussion' ? 'tasty' : null,
      },
  ];
  @override
  Future<Map<String, dynamic>> role(String id) async => {
    'is_chameleon': chameleon,
    'word': chameleon ? null : 'Sushi',
  };
  @override
  Future<void> anotherRound(String id, int round) async {
    expect(round, clueRound);
    if (failRepeat) throw const PostgrestException(message: 'Try again');
    repeats++;
    clueRound++;
    phase = 'clues';
    turn = 0;
  }

  @override
  Future<void> startVoting(String id) async {
    phase = 'voting';
  }
}

Future<void> tapLabel(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> openRoom(WidgetTester tester, OnlineFake repo) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: SupabaseOnlineScreen(
        client: repo.client,
        repository: repo,
        joining: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'Alex');
  await tapLabel(tester, 'Create room');
}

void main() {
  late SupabaseClient client;
  setUp(() {
    client = SupabaseClient('https://example.supabase.co', 'test-key');
  });
  tearDown(() async {
    await client.dispose();
  });

  testWidgets('host repeats clues, returns to discussion, and can vote', (
    tester,
  ) async {
    final repo = OnlineFake(client);
    await openRoom(tester, repo);
    for (var i = 0; i < 2; i++) {
      await tapLabel(tester, 'Another Round');
      expect(find.text('Give one clue'), findsOneWidget);
      expect(find.text('Start voting'), findsNothing);
      expect(find.text('tasty'), findsNothing);
      repo.phase = 'discussion';
      repo.changed!();
      await tester.pumpAndSettle();
    }
    expect(repo.repeats, 2);
    await tapLabel(tester, 'Start voting');
    expect(find.text('Vote privately'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('guest cannot restart; failed host request stays in discussion', (
    tester,
  ) async {
    final guest = OnlineFake(client, host: false);
    await openRoom(tester, guest);
    expect(find.text('Another Round'), findsNothing);
    expect(find.text('Start voting'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    final host = OnlineFake(client)..failRepeat = true;
    await openRoom(tester, host);
    await tapLabel(tester, 'Another Round');
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Discuss the clues'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('compact copyable code and mascot fit a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final repo = OnlineFake(client)..phase = 'reveal';
    await openRoom(tester, repo);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(RoomCodeBadge),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Copy room code'));
    await tester.pumpAndSettle();
    expect(copied, ['ABC234']);
    await tapLabel(tester, 'Reveal my role');
    expect(find.byType(ChameleonMascot), findsOneWidget);
    expect(find.text('Sushi'), findsNothing);
    expect(find.byType(TopicBanner), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('clue word hides on background and when the turn changes', (
    tester,
  ) async {
    final repo = OnlineFake(client)
      ..phase = 'clues'
      ..chameleon = false;
    await openRoom(tester, repo);
    await tapLabel(tester, 'View my clue screen');
    expect(find.text('Sushi'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('Sushi'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tapLabel(tester, 'View my clue screen');
    repo.turn = 1;
    repo.changed!();
    await tester.pumpAndSettle();
    expect(find.text('Sushi'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
