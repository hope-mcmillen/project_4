import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import 'room_repository.dart';

class FirebaseRoomRepository implements RoomRepository {
  static Future<void>? _initializing;
  late FirebaseAuth _auth;
  late FirebaseFirestore _store;
  late FirebaseFunctions _functions;

  static Future<void> _initialize() async {
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: host.isEmpty
            ? DefaultFirebaseOptions.currentPlatform
            : const FirebaseOptions(
                apiKey: 'demo-key',
                appId: '1:123:web:demo',
                messagingSenderId: '123',
                projectId: 'demo-chameleon',
              ),
      );
    }
    if (host.isNotEmpty) {
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFunctions.instanceFor(region: 'us-central1')
          .useFunctionsEmulator(host, 5001);
    }
  }

  @override
  String get playerId => _auth.currentUser!.uid;

  @override
  Future<String?> connect() async {
    try {
      await (_initializing ??= _initialize());
    } catch (_) {
      _initializing = null;
      throw const LobbyException(
        'Online play could not connect. Please retry.',
      );
    }
    _auth = FirebaseAuth.instance;
    _store = FirebaseFirestore.instance;
    _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    try {
      if (_auth.currentUser == null) await _auth.signInAnonymously();
    } on FirebaseAuthException catch (error) {
      throw LobbyException(switch (error.code) {
        'configuration-not-found' => 'Firebase Authentication is not set up yet. Enable Authentication and Anonymous sign-in in the Firebase console.',
        'operation-not-allowed' => 'Anonymous sign-in is disabled. Enable it under Firebase Authentication → Sign-in method.',
        'network-request-failed' =>
          'Could not reach Firebase. Check your connection and retry.',
        _ =>
          'Could not sign in (${error.code}). Please check the Firebase Authentication setup.',
      });
    }
    return (await _call('getMyRoom', {}))['roomId'] as String?;
  }

  Future<Map<String, dynamic>> _call(
    String action,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _functions
          .httpsCallable(action)
          .call<dynamic>(data);
      return Map<String, dynamic>.from(response.data as Map);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        throw const LobbyException(
          'Connection lost. Please retry; your seat will not be duplicated.',
        );
      }
      if (error.code == 'not-found' && action != 'joinRoom') {
        throw const LobbyException(
          'Online lobbies are not available yet. Please try again later.',
        );
      }
      throw LobbyException(
        error.message ?? 'Could not update the lobby. Please retry.',
      );
    }
  }

  @override
  Future<String> createRoom(String name, String topicId) async =>
      (await _call('createRoom', {'name': name, 'topicId': topicId}))['roomId']
          as String;

  @override
  Future<String> joinRoom(String code, String name) async =>
      (await _call('joinRoom', {
            'code': code.trim().toUpperCase(),
            'name': name,
          }))['roomId']
          as String;

  @override
  Stream<RoomView> watchRoom(String roomId) => _store
      .doc('rooms/$roomId')
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) {
        final data = snapshot.data();
        if (data == null) throw const LobbyException('This lobby has closed.');
        final players =
            Map<String, dynamic>.from(data['players'] as Map).entries.toList()
              ..sort((a, b) {
                final order = (a.value['joinedAt'] as num).compareTo(
                  b.value['joinedAt'] as num,
                );
                return order == 0 ? a.key.compareTo(b.key) : order;
              });
        return RoomView(
          id: roomId,
          code: data['code'] as String,
          hostId: data['hostId'] as String,
          topicId: data['topicId'] as String,
          expiresAt: (data['expiresAt'] as Timestamp).toDate(),
          isFromCache: snapshot.metadata.isFromCache,
          players: players
              .map(
                (p) => LobbyPlayer(
                  id: p.key,
                  name: p.value['name'] as String,
                  ready: p.value['ready'] as bool,
                ),
              )
              .toList(),
        );
      });

  @override
  Future<void> setReady(String roomId, bool ready) async {
    await _call('setReady', {'roomId': roomId, 'ready': ready});
  }

  @override
  Future<void> setTopic(String roomId, String topicId) async {
    await _call('setTopic', {'roomId': roomId, 'topicId': topicId});
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    await _call('leaveRoom', {'roomId': roomId});
  }
}
