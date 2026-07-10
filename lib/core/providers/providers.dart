import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/contests/data/tournament_repository.dart';
import '../../features/teams/data/team_repository.dart';
import '../../features/players/data/player_repository.dart';
import '../../features/scoring/data/match_score_repository.dart';
import '../models/profile.dart';
import '../models/tournament.dart';
import '../models/team.dart';
import '../models/player.dart';
import '../models/match.dart';

// ── Repositories ───────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((_) => AuthRepository());

final tournamentRepositoryProvider =
    Provider<TournamentRepository>((_) => TournamentRepository());

final teamRepositoryProvider =
    Provider<TeamRepository>((_) => TeamRepository());

final playerRepositoryProvider =
    Provider<PlayerRepository>((_) => PlayerRepository());

final matchScoreRepositoryProvider =
    Provider<MatchScoreRepository>((_) => MatchScoreRepository());

// ── Auth ───────────────────────────────────────────────────────────────────

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.read(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.read(authRepositoryProvider).currentUser;
});

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.read(authRepositoryProvider).getProfile(user.id);
});

// ── Tournaments ────────────────────────────────────────────────────────────

final tournamentsProvider =
    FutureProvider.family<List<Tournament>, String?>((ref, sport) async {
  return ref.read(tournamentRepositoryProvider).fetchAll(sport: sport);
});

final tournamentDetailProvider =
    FutureProvider.family<Tournament?, String>((ref, id) async {
  return ref.read(tournamentRepositoryProvider).fetchById(id);
});

final tournamentMatchesProvider =
    FutureProvider.family<List<Match>, String>((ref, tournamentId) async {
  return ref.read(tournamentRepositoryProvider).fetchMatches(tournamentId);
});

final tournamentTeamsProvider =
    FutureProvider.family<List<Team>, String>((ref, tournamentId) async {
  return ref.read(tournamentRepositoryProvider).fetchTournamentTeams(tournamentId);
});

final tournamentMatchesStreamProvider =
    StreamProvider.family<List<Match>, String>((ref, tournamentId) {
  return ref.read(tournamentRepositoryProvider).watchMatches(tournamentId);
});

// ── Teams ──────────────────────────────────────────────────────────────────

final teamsProvider =
    FutureProvider.family<List<Team>, String?>((ref, sport) async {
  return ref.read(teamRepositoryProvider).fetchAll(sport: sport);
});

final teamDetailProvider =
    FutureProvider.family<Team?, String>((ref, id) async {
  return ref.read(teamRepositoryProvider).fetchById(id);
});

final teamPlayersProvider =
    FutureProvider.family<List<Player>, String>((ref, teamId) async {
  return ref.read(teamRepositoryProvider).fetchPlayers(teamId);
});

// ── Players ────────────────────────────────────────────────────────────────

final playersProvider =
    FutureProvider.family<List<Player>, String?>((ref, sport) async {
  return ref.read(playerRepositoryProvider).fetchAll(sport: sport, onlyFreeAgents: true);
});

final activeTournamentsProvider = FutureProvider<List<Tournament>>((ref) async {
  return ref.read(tournamentRepositoryProvider).fetchAll(status: 'live');
});

final profileStatsProvider =
    FutureProvider<({int events, int teams})>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return (events: 0, teams: 0);
  final client = Supabase.instance.client;
  final results = await Future.wait([
    client.from('tournaments').select('id').eq('organizer_id', user.id),
    client.from('teams').select('id').eq('captain_id', user.id),
  ]);
  return (
    events: (results[0] as List).length,
    teams: (results[1] as List).length,
  );
});

// ── Match / Scoring ────────────────────────────────────────────────────────

final matchStreamProvider =
    StreamProvider.family<Match, String>((ref, matchId) {
  return ref.read(matchScoreRepositoryProvider).watchMatch(matchId);
});
