import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/match.dart';
import '../../../core/supabase/supabase_service.dart';

class MatchScoreRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<Match?> fetchMatch(String matchId) async {
    final data = await _client
        .from('matches')
        .select()
        .eq('id', matchId)
        .maybeSingle();
    if (data == null) return null;
    return Match.fromJson(data);
  }

  Future<void> updateScore({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required Map<String, dynamic> metadata,
  }) async {
    await _client.from('matches').update({
      'home_score': homeScore,
      'away_score': awayScore,
      'metadata': metadata,
      'status': 'live',
    }).eq('id', matchId);
  }

  Future<void> finalizeMatch({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required Map<String, dynamic> metadata,
  }) async {
    await _client.from('matches').update({
      'home_score': homeScore,
      'away_score': awayScore,
      'metadata': metadata,
      'status': 'completed',
    }).eq('id', matchId);
  }

  /// Real-time stream for live score updates
  Stream<Match> watchMatch(String matchId) {
    return _client
        .from('matches')
        .stream(primaryKey: ['id'])
        .eq('id', matchId)
        .expand(
            (rows) => rows.isNotEmpty ? [Match.fromJson(rows.first)] : const []);
  }
}
