import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/team.dart';
import '../../../core/models/player.dart';
import '../../../core/supabase/supabase_service.dart';

class TeamRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<List<Team>> fetchAll({String? sport, bool? isIndividual}) async {
    var query = _client.from('teams').select('*, players(count)');
    if (sport != null && sport != 'All') {
      query = query.eq('sport', sport.toLowerCase());
    }
    if (isIndividual != null) {
      query = query.eq('is_individual', isIndividual);
    } else {
      query = query.eq('is_individual', false);
    }
    final data = await query.order('name');
    return (data as List).map((e) => Team.fromJson(_withLiveCount(e))).toList();
  }

  Future<Team?> fetchById(String id) async {
    final data = await _client
        .from('teams')
        .select('*, players(count)')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Team.fromJson(_withLiveCount(data));
  }

  Map<String, dynamic> _withLiveCount(Map<String, dynamic> row) {
    final players = row['players'];
    int count = 0;
    if (players is List && players.isNotEmpty) {
      final first = players.first;
      if (first is Map && first['count'] != null) {
        count = (first['count'] as num).toInt();
      }
    }
    return {...row, 'player_count': count};
  }

  Future<List<Player>> fetchPlayers(String teamId) async {
    final data = await _client
        .from('players')
        .select()
        .eq('team_id', teamId)
        .order('jersey_number');
    return (data as List).map((e) => Player.fromJson(e)).toList();
  }

  Future<Team> create(Map<String, dynamic> payload) async {
    final data = await _client
        .from('teams')
        .insert(payload)
        .select()
        .single();
    return Team.fromJson(data);
  }

  Future<void> update(String id, Map<String, dynamic> payload) async {
    await _client.from('teams').update(payload).eq('id', id);
  }

  Future<void> addPlayer(Map<String, dynamic> payload) async {
    await _client.from('players').insert(payload);
  }

  Future<void> removePlayer(String playerId) async {
    await _client.from('players').delete().eq('id', playerId);
  }

  Future<void> delete(String id) async {
    await _client.from('teams').delete().eq('id', id);
  }

  /// Uploads [file] to the team-logos bucket and returns the public URL.
  Future<String> uploadLogo(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final bytes = await file.readAsBytes();
    await _client.storage.from('team-logos').uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
        );
    return _client.storage.from('team-logos').getPublicUrl(fileName);
  }

  /// Returns true if the team is enrolled in any upcoming or live tournament.
  Future<bool> isTeamInActiveTournament(String teamId) async {
    // Step 1: get tournament IDs this team belongs to
    final ttRows = await _client
        .from('tournament_teams')
        .select('tournament_id')
        .eq('team_id', teamId);
    final ids = (ttRows as List)
        .map((r) => r['tournament_id'] as String)
        .toList();
    if (ids.isEmpty) return false;

    // Step 2: check if any of those tournaments are active
    final tRows = await _client
        .from('tournaments')
        .select('status')
        .inFilter('id', ids);
    return (tRows as List).any((r) {
      final s = r['status'] as String?;
      return s == 'upcoming' || s == 'live';
    });
  }

  /// Returns true if the player is enrolled in any upcoming or live tournament,
  /// either via a team membership or as an individual participant (shadow team).
  Future<bool> isPlayerInActiveTournament(String playerId) async {
    final data = await _client
        .from('players')
        .select('team_id, profile_id')
        .eq('id', playerId)
        .maybeSingle();
    if (data == null) return false;

    // Path 1: player belongs to a regular team
    final teamId = data['team_id'] as String?;
    if (teamId != null && await isTeamInActiveTournament(teamId)) return true;

    // Path 2: player is enrolled as an individual (shadow team where captain_id = profile_id)
    final profileId = data['profile_id'] as String?;
    if (profileId == null) return false;

    final shadowTeams = await _client
        .from('teams')
        .select('id')
        .eq('captain_id', profileId)
        .eq('is_individual', true);
    for (final row in shadowTeams as List) {
      final sid = row['id'] as String;
      if (await isTeamInActiveTournament(sid)) return true;
    }
    return false;
  }
}
