import 'package:flutter/material.dart';

import '../features/game/screens/home_screen.dart';
import 'theme.dart';
import 'word_repository_config.dart';
import '../features/game/data/word_repository.dart';

class ChameleonApp extends StatefulWidget {
  const ChameleonApp({super.key, this.wordRepository});
  final WordRepository? wordRepository;

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
    home: HomeScreen(wordRepository: _words),
  );
}
