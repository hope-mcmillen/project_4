import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_4/app/word_repository_config.dart';
import 'package:project_4/features/game/data/local_word_repository.dart';
import 'package:project_4/features/game/data/remote_word_repository.dart';
import 'package:project_4/features/game/data/topic_packs.dart';
import 'package:project_4/features/game/data/word_repository.dart';

Map<String, dynamic> pack({
  String id = 'remote',
  String name = 'Server pack',
}) => {'id': id, 'name': name, 'words': topicPacks.first.words};

http.Response json(Object value, [int code = 200]) => http.Response(
  jsonEncode(value),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class ClosingClient extends MockClient {
  ClosingClient(super.handler);
  bool closed = false;
  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  late DateTime now;
  late int requests;
  late Future<http.Response> Function(http.Request) handler;
  late RemoteWordRepository repository;

  setUp(() {
    now = DateTime.utc(2026, 9, 29);
    requests = 0;
    handler = (request) async =>
        json(request.url.queryParameters['offset'] == '0' ? [pack()] : []);
    repository = RemoteWordRepository(
      supabaseUrl: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_test',
      now: () => now,
      clientFactory: () => MockClient((request) {
        requests++;
        return handler(request);
      }),
    );
  });

  test(
    'uses the WordRepository interface and published Supabase REST contract',
    () async {
      handler = (request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/rest/v1/topic_packs');
        expect(request.url.queryParameters['select'], 'id,name,words');
        expect(request.url.queryParameters['is_published'], 'eq.true');
        expect(request.url.queryParameters['order'], 'id.asc');
        expect(request.headers['apikey'], 'sb_publishable_test');
        expect(request.headers.containsKey('Authorization'), isFalse);
        return json(
          request.url.queryParameters['offset'] == '0' ? [pack()] : [],
        );
      };
      final WordRepository words = repository;
      final result = await words.getTopics();
      expect(result.single.name, 'Server pack');
      expect(() => result.clear(), throwsUnsupportedError);
      expect(() => result.single.words.clear(), throwsUnsupportedError);
    },
  );

  test(
    'cache avoids requests until ten-minute expiry, then picks up edits',
    () async {
      final initial = await repository.getTopics();
      final calls = requests;
      now = now.add(const Duration(minutes: 9));
      expect(await repository.getTopics(), same(initial));
      expect(requests, calls);
      handler = (request) async => json(
        request.url.queryParameters['offset'] == '0'
            ? [pack(name: 'Updated topic')]
            : [],
      );
      now = now.add(const Duration(minutes: 1));
      expect((await repository.getTopics()).single.name, 'Updated topic');
      expect(requests, calls + 2);
      expect(initial.single.name, 'Server pack');
    },
  );

  test('concurrent callers share one catalog fetch', () async {
    final response = Completer<http.Response>();
    handler = (request) => request.url.queryParameters['offset'] == '0'
        ? response.future
        : Future.value(json([]));
    final first = repository.getTopics();
    final second = repository.getTopics();
    expect(second, same(first));
    response.complete(json([pack()]));
    expect(await first, same(await second));
    expect(requests, 2);
  });

  test('paginates even when the backend applies a smaller row limit', () async {
    handler = (request) async =>
        switch (request.url.queryParameters['offset']) {
          '0' => json([pack(id: 'a')]),
          '1' => json([pack(id: 'b')]),
          _ => json([]),
        };
    expect((await repository.getTopics()).map((p) => p.id), ['a', 'b']);
    expect(requests, 3);
  });

  test(
    'offline first launch uses local topics, throttles retry, then recovers',
    () async {
      handler = (_) async => throw http.ClientException('offline');
      expect(
        (await repository.getTopics()).map((p) => p.id),
        topicPacks.map((p) => p.id),
      );
      await repository.getTopics();
      expect(requests, 1);
      handler = (request) async =>
          json(request.url.queryParameters['offset'] == '0' ? [pack()] : []);
      now = now.add(const Duration(seconds: 30));
      expect((await repository.getTopics()).single.id, 'remote');
    },
  );

  test('failed refresh retains the last successful server catalog', () async {
    final initial = await repository.getTopics();
    now = now.add(const Duration(minutes: 10));
    handler = (_) async => json({'message': 'unavailable'}, 503);
    expect(await repository.getTopics(), same(initial));
    expect(requests, 3);
  });

  test('a later-page failure does not expose a partial catalog', () async {
    handler = (request) async => request.url.queryParameters['offset'] == '0'
        ? json([pack()])
        : json({}, 500);
    expect((await repository.getTopics()).length, topicPacks.length);
  });

  test(
    'an empty successful response clears old topics instead of restoring them',
    () async {
      await repository.getTopics();
      now = now.add(const Duration(minutes: 10));
      handler = (_) async => json([]);
      expect(await repository.getTopics(), isEmpty);
      final calls = requests;
      expect(await repository.getTopics(), isEmpty);
      expect(requests, calls);
    },
  );

  for (final status in [401, 403, 404, 429, 500]) {
    test('HTTP $status falls back without exposing server errors', () async {
      handler = (_) async => json({'message': 'backend details'}, status);
      expect((await repository.getTopics()).length, topicPacks.length);
    });
  }

  final invalidResponses = <Object>[
    {'unexpected': 'object'},
    [42],
    [pack()..['name'] = ' '],
    [
      pack()..['words'] = ['Only one'],
    ],
    [pack()..['words'] = List.filled(12, 'Duplicate')],
    [
      pack()..['words'] = ['', ...topicPacks.first.words.skip(1)],
    ],
    [
      pack()..['words'] = [null, ...topicPacks.first.words.skip(1)],
    ],
    [pack(), pack()],
  ];
  for (var i = 0; i < invalidResponses.length; i++) {
    test('invalid catalog $i falls back safely', () async {
      handler = (_) async => json(invalidResponses[i]);
      expect((await repository.getTopics()).length, topicPacks.length);
    });
  }

  test('malformed JSON falls back', () async {
    handler = (_) async => http.Response('<html>error</html>', 200);
    expect((await repository.getTopics()).length, topicPacks.length);
  });

  test(
    'timeout closes the client and late results cannot replace fallback',
    () async {
      final pending = Completer<http.Response>();
      final client = ClosingClient((_) => pending.future);
      final slow = RemoteWordRepository(
        supabaseUrl: 'https://example.supabase.co',
        publishableKey: 'sb_publishable_test',
        clientFactory: () => client,
        requestTimeout: const Duration(milliseconds: 10),
      );
      final result = await slow.getTopics();
      expect(result.length, topicPacks.length);
      expect(client.closed, isTrue);
      pending.complete(json([]));
      await Future<void>.delayed(Duration.zero);
      expect(await slow.getTopics(), same(result));
    },
  );

  test('configuration defaults local and accepts public credentials only', () {
    expect(createWordRepository(url: '', key: ''), isA<LocalWordRepository>());
    expect(
      createWordRepository(
        url: 'https://example.supabase.co',
        key: 'sb_publishable_test',
      ),
      isA<RemoteWordRepository>(),
    );
    for (final key in ['', 'sb_secret_private', 'invalid']) {
      expect(
        () =>
            createWordRepository(url: 'https://example.supabase.co', key: key),
        throwsArgumentError,
      );
    }
    expect(
      () => createWordRepository(
        url: 'http://example.supabase.co',
        key: 'sb_publishable_test',
      ),
      throwsArgumentError,
    );
    String jwt(String role) =>
        'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role})))}.signature';
    expect(
      () => createWordRepository(
        url: 'https://example.supabase.co',
        key: jwt('service_role'),
      ),
      throwsArgumentError,
    );
    expect(
      createWordRepository(
        url: 'https://example.supabase.co',
        key: jwt('anon'),
      ),
      isA<RemoteWordRepository>(),
    );
  });
}
