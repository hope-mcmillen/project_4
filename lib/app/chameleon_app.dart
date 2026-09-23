import 'package:flutter/material.dart';

import '../features/game/screens/home_screen.dart';
import 'theme.dart';

class ChameleonApp extends StatelessWidget {
  const ChameleonApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Chameleon',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: const HomeScreen(),
  );
}
