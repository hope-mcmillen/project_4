import '../features/game/data/local_word_repository.dart';
import '../features/game/data/remote_word_repository.dart';
import '../features/game/data/word_repository.dart';

WordRepository createWordRepository({
  String url = const String.fromEnvironment('SUPABASE_URL'),
  String key = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
}) {
  if (url.trim().isEmpty && key.trim().isEmpty) {
    return const LocalWordRepository();
  }
  if (url.trim().isEmpty || key.trim().isEmpty) {
    throw ArgumentError('Set both SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.');
  }
  return RemoteWordRepository(supabaseUrl: url, publishableKey: key);
}
