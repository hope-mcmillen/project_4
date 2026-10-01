import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOnlineRepository {
  SupabaseOnlineRepository(this.client);

  final SupabaseClient client;

  String get userId => client.auth.currentUser!.id;

  Future<void> signIn() async {
    if (client.auth.currentUser == null) await client.auth.signInAnonymously();
  }

  Future<List<Map<String, dynamic>>> topics() async => await client
      .from('topic_packs')
      .select('id,name,words')
      .eq('is_published', true)
      .order('name');

  Future<String> create(String name, String topic) async => (await client.rpc(
    'online_create_room',
    params: {'p_name': name, 'p_topic': topic},
  )) as String;

  Future<String> join(String code, String name) async => (await client.rpc(
    'online_join_room',
    params: {'p_code': code, 'p_name': name},
  )) as String;

  Future<Map<String, dynamic>?> room(String id) async =>
      await client.from('online_rooms').select().eq('id', id).maybeSingle();

  Future<List<Map<String, dynamic>>> members(String id) async => await client
      .from('online_members')
      .select()
      .eq('room_id', id)
      .order('seat');

  Future<void> ready(String id, bool value) =>
      _call('online_set_ready', {'p_room': id, 'p_ready': value});
  Future<void> topic(String id, String value) =>
      _call('online_set_topic', {'p_room': id, 'p_topic': value});
  Future<void> leave(String id) => _call('online_leave_room', {'p_room': id});
  Future<void> start(String id) => _call('online_start_round', {'p_room': id});
  Future<Map<String, dynamic>> role(
    String id,
  ) async => Map<String, dynamic>.from(
    (await client.rpc('online_my_role', params: {'p_room': id}) as List).single
        as Map,
  );
  Future<void> finishReveal(String id) =>
      _call('online_finish_reveal', {'p_room': id});
  Future<void> clue(String id, String value) =>
      _call('online_submit_clue', {'p_room': id, 'p_clue': value});
  Future<void> startVoting(String id) =>
      _call('online_start_voting', {'p_room': id});
  Future<void> vote(String id, String suspect) =>
      _call('online_cast_vote', {'p_room': id, 'p_suspect': suspect});
  Future<void> guess(String id, String word) =>
      _call('online_guess_word', {'p_room': id, 'p_guess': word});

  Future<void> _call(String name, Map<String, dynamic> params) async {
    await client.rpc(name, params: params);
  }
}
