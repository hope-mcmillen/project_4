import '../models/topic_pack.dart';

/// Supplies playable topic packs. CHM-2 can implement this against a server
/// without changing setup, previews, or the game controller.
abstract interface class WordRepository {
  Future<List<TopicPack>> getTopics();
}
