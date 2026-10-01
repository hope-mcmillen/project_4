import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/chameleon_app.dart';
import 'app/supabase_config.dart';
import 'app/word_repository_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }
  runApp(
    ChameleonApp(
      wordRepository: createWordRepository(
        url: supabaseUrl,
        key: supabasePublishableKey,
      ),
      onlineClient: supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty
          ? Supabase.instance.client
          : null,
    ),
  );
}
