import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/topic_pack.dart';
import 'local_word_repository.dart';
import 'word_repository.dart';

/// Reads public topic packs from Supabase's Data API. No player/role data is sent.
/// Cache is session-local, with a TTL so content updates arrive without a release.
class RemoteWordRepository implements WordRepository {
  RemoteWordRepository({
    required String supabaseUrl,
    required String publishableKey,
    this.fallback = const LocalWordRepository(),
    http.Client Function()? clientFactory,
    DateTime Function()? now,
    this.cacheDuration = const Duration(minutes: 10),
    this.retryDelay = const Duration(seconds: 30),
    this.requestTimeout = const Duration(seconds: 8),
  }) : _url = Uri.parse(supabaseUrl.trim()),
       _key = publishableKey.trim(),
       _clientFactory = clientFactory ?? http.Client.new,
       _now = now ?? DateTime.now {
    if (_url.scheme != 'https' ||
        _url.host.isEmpty ||
        _url.userInfo.isNotEmpty ||
        _url.hasQuery ||
        _url.hasFragment ||
        (_url.path.isNotEmpty && _url.path != '/')) {
      throw ArgumentError('SUPABASE_URL must be an HTTPS project origin.');
    }
    // Publishable credentials belong in a client. Never accept an admin key.
    if (!_isPublicKey(_key)) {
      throw ArgumentError('Use a Supabase publishable key or legacy anon key.');
    }
    if (cacheDuration.isNegative ||
        retryDelay.isNegative ||
        requestTimeout <= Duration.zero) {
      throw ArgumentError('Invalid topic cache/timeout duration.');
    }
  }

  final Uri _url;
  final String _key;
  final WordRepository fallback;
  final http.Client Function() _clientFactory;
  final DateTime Function() _now;
  final Duration cacheDuration;
  final Duration retryDelay;
  final Duration requestTimeout;
  List<TopicPack>? _cached;
  DateTime? _nextFetch;
  Future<List<TopicPack>>? _pending;

  @override
  Future<List<TopicPack>> getTopics() {
    if (_cached != null && _nextFetch != null && _now().isBefore(_nextFetch!)) {
      return Future.value(_cached);
    }
    return _pending ??= _refresh().whenComplete(() => _pending = null);
  }

  Future<List<TopicPack>> _refresh() async {
    final client = _clientFactory();
    try {
      final topics = await _fetch(client).timeout(requestTimeout);
      _cached = topics;
      _nextFetch = _now().add(cacheDuration);
      return topics;
    } on Exception {
      // Preserve downloaded topics on a temporary outage. On first use offline,
      // the bundled list keeps the game playable. Do not log keys/server bodies.
      _cached ??= List.unmodifiable(await fallback.getTopics());
      _nextFetch = _now().add(retryDelay);
      return _cached!;
    } finally {
      // Also cancels outstanding I/O when the whole catalog request times out.
      client.close();
    }
  }

  Future<List<TopicPack>> _fetch(http.Client client) async {
    final topics = <TopicPack>[];
    final ids = <String>{};
    // Continue to an empty page, not a short page: server row limits may be
    // smaller than our requested page size. Never cache a partial catalog.
    while (true) {
      final response = await client.get(
        _url.replace(
          path: '/rest/v1/topic_packs',
          queryParameters: {
            'select': 'id,name,words',
            'is_published': 'eq.true',
            'order': 'id.asc',
            'limit': '100',
            'offset': '${topics.length}',
          },
        ),
        headers: {
          'apikey': _key,
          if (!_key.startsWith('sb_publishable_'))
            'Authorization': 'Bearer $_key',
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
      );
      if (response.statusCode != 200) {
        throw const FormatException('Topic service unavailable.');
      }
      final rows = jsonDecode(utf8.decode(response.bodyBytes));
      if (rows is! List) throw const FormatException('Invalid topic catalog.');
      if (rows.isEmpty) return List.unmodifiable(topics);
      for (final row in rows) {
        if (row is! Map<String, dynamic>) {
          throw const FormatException('Invalid topic.');
        }
        final pack = _parsePack(row);
        if (!ids.add(pack.id)) {
          throw const FormatException('Duplicate topic ID.');
        }
        topics.add(pack);
      }
      if (topics.length > 5000) {
        throw const FormatException('Topic catalog too large.');
      }
    }
  }

  static TopicPack _parsePack(Map<String, dynamic> row) {
    String text(Object? value, int max) {
      if (value is! String ||
          value.trim().isEmpty ||
          value.trim().length > max) {
        throw const FormatException('Invalid topic text.');
      }
      return value.trim();
    }

    final id = text(row['id'], 100);
    final name = text(row['name'], 80);
    final rawWords = row['words'];
    if (rawWords is! List || rawWords.length != 12) {
      throw const FormatException('A topic must contain 12 words.');
    }
    final words = rawWords.map((word) => text(word, 40)).toList();
    if (words.map((word) => word.toLowerCase()).toSet().length != 12) {
      throw const FormatException('Topic words must be distinct.');
    }
    return TopicPack(id: id, name: name, words: List.unmodifiable(words));
  }

  static bool _isPublicKey(String key) {
    if (key.startsWith('sb_publishable_') &&
        key.length > 'sb_publishable_'.length) {
      return true;
    }
    try {
      final parts = key.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map && payload['role'] == 'anon';
    } on FormatException {
      return false;
    }
  }
}
