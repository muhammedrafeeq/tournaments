import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/tournament.dart';
import '../../../core/models/team.dart';
import '../../../core/models/match.dart';
import '../../../core/supabase/supabase_service.dart';

class TournamentRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<List<Tournament>> fetchAll({String? sport, String? status}) async {
    var query = _client.from('tournaments').select();
    if (sport != null && sport != 'All') {
      query = query.eq('sport', sport.toLowerCase());
    }
    if (status != null) {
      query = query.eq('status', status);
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => Tournament.fromJson(e)).toList();
  }

  Future<Tournament?> fetchById(String id) async {
    final data = await _client
        .from('tournaments')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Tournament.fromJson(data);
  }

  Future<Tournament?> fetchByInviteCode(String code) async {
    final data = await _client
        .from('tournaments')
        .select()
        .eq('invite_code', code.toUpperCase().trim())
        .maybeSingle();
    if (data == null) return null;
    return Tournament.fromJson(data);
  }

  Future<void> scheduleMatch(String matchId, DateTime scheduledAt) async {
    await _client.from('matches').update({
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
    }).eq('id', matchId);
  }

  Future<Tournament> create(Map<String, dynamic> payload) async {
    final data = await _client
        .from('tournaments')
        .insert(payload)
        .select()
        .single();
    return Tournament.fromJson(data);
  }

  Future<void> update(String id, Map<String, dynamic> payload) async {
    await _client.from('tournaments').update(payload).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('tournaments').delete().eq('id', id);
  }

  Future<void> joinTournament(String tournamentId, String teamId) async {
    await _client.from('tournament_teams').insert({
      'tournament_id': tournamentId,
      'team_id': teamId,
    });
  }

  Future<List<Team>> fetchTournamentTeams(String tournamentId) async {
    final data = await _client
        .from('tournament_teams')
        .select('teams(*)')
        .eq('tournament_id', tournamentId);
    return (data as List)
        .map((e) => Team.fromJson(e['teams'] as Map<String, dynamic>))
        .toList();
  }

  Future<List<Match>> fetchMatches(String tournamentId) async {
    final data = await _client
        .from('matches')
        .select()
        .eq('tournament_id', tournamentId)
        .order('scheduled_at');
    return (data as List).map((e) => Match.fromJson(e)).toList();
  }

  /// Real-time subscription to a tournament's matches
  Stream<List<Match>> watchMatches(String tournamentId) {
    return _client
        .from('matches')
        .stream(primaryKey: ['id'])
        .eq('tournament_id', tournamentId)
        .order('scheduled_at')
        .map((rows) => rows.map(Match.fromJson).toList());
  }
}
