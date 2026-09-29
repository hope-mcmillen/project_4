import '../models/topic_pack.dart';
import 'topic_packs.dart';
import 'word_repository.dart';

/// The bundled catalog works offline and its const packs cannot be mutated.
class LocalWordRepository implements WordRepository {
  const LocalWordRepository();

  @override
  Future<List<TopicPack>> getTopics() async => topicPacks;
}
