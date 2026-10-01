import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/game/data/word_repository.dart';
import '../features/game/screens/home_screen.dart';
import '../features/lobby/logic/room_repository.dart';
import 'theme.dart';
import 'word_repository_config.dart';

class ChameleonApp extends StatefulWidget {
  const ChameleonApp({
    super.key,
    this.wordRepository,
    this.rooms,
    this.onlineClient,
  });
  final WordRepository? wordRepository;

  /// Tests may inject an in-memory room backend.
  final RoomRepository? rooms;
  final SupabaseClient? onlineClient;

  @override
  State<ChameleonApp> createState() => _ChameleonAppState();
}

class _ChameleonAppState extends State<ChameleonApp> {
  // One repository per app session: opening setup again reuses its cache.
  late final WordRepository _words =
      widget.wordRepository ?? createWordRepository();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Chameleon',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: HomeScreen(
      wordRepository: _words,
      rooms: widget.rooms,
      onlineClient: widget.onlineClient,
    ),
  );
}
