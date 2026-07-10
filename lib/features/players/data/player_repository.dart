import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/player.dart';
import '../../../core/supabase/supabase_service.dart';

class PlayerRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<List<Player>> fetchAll({String? sport, String? teamId, bool onlyFreeAgents = false}) async {
    var query = _client.from('players').select();
    if (sport != null && sport != 'All') {
      query = query.or('sport.eq.${sport.toLowerCase()},sport.is.null');
    }
    if (teamId != null) {
      query = query.eq('team_id', teamId);
    }
    if (onlyFreeAgents) {
      query = query.filter('team_id', 'is', null);
    }
    final data = await query.order('name');
    return (data as List).map((e) => Player.fromJson(e)).toList();
  }

  Future<Player?> fetchById(String id) async {
    final data = await _client
        .from('players')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Player.fromJson(data);
  }

  Future<Player> create(Map<String, dynamic> data) async {
    final result = await _client
        .from('players')
        .insert(data)
        .select()
        .single();
    return Player.fromJson(result);
  }

  Future<Player> update(String id, Map<String, dynamic> data) async {
    final result = await _client
        .from('players')
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return Player.fromJson(result);
  }

  Future<void> updateStats(String playerId, Map<String, dynamic> stats) async {
    await _client.from('players').update({'stats': stats}).eq('id', playerId);
  }

  Future<void> delete(String id) async {
    await _client.from('players').delete().eq('id', id);
  }

  /// Uploads [file] to the player-avatars bucket and returns the public URL.
  Future<String> uploadAvatar(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final bytes = await file.readAsBytes();
    await _client.storage.from('player-avatars').uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
        );
    return _client.storage.from('player-avatars').getPublicUrl(fileName);
  }
}
