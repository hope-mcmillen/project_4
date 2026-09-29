import 'package:flutter/material.dart';

import '../features/game/screens/home_screen.dart';
import '../features/lobby/logic/fake_room_repository.dart';
import '../features/lobby/logic/room_repository.dart';
import 'theme.dart';

class ChameleonApp extends StatefulWidget {
  const ChameleonApp({super.key, this.rooms});

  /// The online room backend. Defaults to an in-memory fake until CHM-S1
  /// picks a real one; tests can pass their own.
  final RoomRepository? rooms;

  @override
  State<ChameleonApp> createState() => _ChameleonAppState();
}

class _ChameleonAppState extends State<ChameleonApp> {
  FakeRoomRepository? _ownRooms;

  RoomRepository get _rooms =>
      widget.rooms ?? (_ownRooms ??= FakeRoomRepository());

  @override
  void dispose() {
    _ownRooms?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Chameleon',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: HomeScreen(rooms: _rooms),
  );
}
