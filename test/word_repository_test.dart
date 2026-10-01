import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/features/game/data/local_word_repository.dart';
import 'package:project_4/features/game/data/topic_packs.dart';
import 'package:project_4/features/game/data/word_repository.dart';

void main() {
  test(
    'local repository exposes the bundled catalog through the interface',
    () async {
      const WordRepository repository = LocalWordRepository();
      final packs = await repository.getTopics();
      expect(packs, same(topicPacks));
      expect(packs.length, greaterThanOrEqualTo(5));
      expect(packs.map((pack) => pack.id).toSet().length, packs.length);
      expect(() => packs.clear(), throwsUnsupportedError);
    },
  );

  for (final pack in topicPacks) {
    test('${pack.name} has exactly 12 distinct, nonempty words', () {
      expect(pack.id.trim(), isNotEmpty);
      expect(pack.name.trim(), isNotEmpty);
      expect(pack.words, hasLength(12));
      for (final word in pack.words) {
        expect(word.trim(), isNotEmpty);
        expect(
          word,
          word.trim(),
          reason: 'Words must not have edge whitespace.',
        );
      }
      expect(
        pack.words.map((word) => word.trim().toLowerCase()).toSet(),
        hasLength(12),
      );
      expect(() => pack.words.add('Another word'), throwsUnsupportedError);
    });
  }
}
