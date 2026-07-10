import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/contests/presentation/create_tournament_screen.dart';
import '../../features/contests/presentation/tournament_dashboard_screen.dart';
import '../../features/contests/presentation/tournament_detail_screen.dart';
import '../../features/contests/presentation/tournaments_list_screen.dart';
import '../../features/teams/presentation/teams_screen.dart';
import '../../features/teams/presentation/team_detail_screen.dart';
import '../../features/players/presentation/players_screen.dart';
import '../../features/players/presentation/player_detail_screen.dart';
import '../../features/contests/presentation/join_tournament_screen.dart';
import '../../features/matches/presentation/match_detail_screen.dart';
import '../../features/scoring/presentation/scoring_router.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../widgets/main_shell.dart';

Page<dynamic> _slidePage(LocalKey key, Widget child) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (ctx, state) =>
          _slidePage(state.pageKey, const SplashScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (ctx, state) =>
          _slidePage(state.pageKey, const LoginScreen()),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (ctx, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/tournaments/dashboard',
          pageBuilder: (ctx, state) =>
              _slidePage(state.pageKey, const TournamentDashboardScreen()),
        ),
        GoRoute(
          path: '/tournaments',
          pageBuilder: (ctx, state) =>
              _slidePage(state.pageKey, const TournamentsListScreen()),
        ),
        GoRoute(
          path: '/teams',
          pageBuilder: (ctx, state) =>
              _slidePage(state.pageKey, const TeamsScreen()),
        ),
        GoRoute(
          path: '/players',
          pageBuilder: (ctx, state) =>
              _slidePage(state.pageKey, const PlayersScreen()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (ctx, state) =>
              _slidePage(state.pageKey, const ProfileScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/teams/:id',
      pageBuilder: (ctx, state) {
        final id = state.pathParameters['id']!;
        return _slidePage(state.pageKey, TeamDetailScreen(id: id));
      },
    ),
    GoRoute(
      path: '/players/:id',
      pageBuilder: (ctx, state) {
        final id = state.pathParameters['id']!;
        return _slidePage(state.pageKey, PlayerDetailScreen(id: id));
      },
    ),
    GoRoute(
      path: '/tournaments/create',
      pageBuilder: (ctx, state) =>
          _slidePage(state.pageKey, const CreateTournamentScreen()),
    ),
    GoRoute(
      path: '/tournaments/join',
      pageBuilder: (ctx, state) =>
          _slidePage(state.pageKey, const JoinTournamentScreen()),
    ),
    GoRoute(
      path: '/tournaments/:id',
      pageBuilder: (ctx, state) {
        final id = state.pathParameters['id']!;
        return _slidePage(state.pageKey, TournamentDetailScreen(id: id));
      },
    ),
    GoRoute(
      path: '/tournaments/:id/matches/:matchId',
      pageBuilder: (ctx, state) {
        final tournamentId = state.pathParameters['id']!;
        final matchId = state.pathParameters['matchId']!;
        final sport = state.uri.queryParameters['sport'] ?? 'generic';
        final home = state.uri.queryParameters['home'] ?? 'Home';
        final away = state.uri.queryParameters['away'] ?? 'Away';
        return _slidePage(
          state.pageKey,
          MatchDetailScreen(
            tournamentId: tournamentId,
            matchId: matchId,
            sport: sport,
            homeTeam: home,
            awayTeam: away,
          ),
        );
      },
    ),
    GoRoute(
      path: '/tournaments/:id/matches/:matchId/score',
      pageBuilder: (ctx, state) {
        final tournamentId = state.pathParameters['id']!;
        final matchId = state.pathParameters['matchId']!;
        final sport = state.uri.queryParameters['sport'] ?? 'generic';
        final home = state.uri.queryParameters['home'] ?? 'Home';
        final away = state.uri.queryParameters['away'] ?? 'Away';
        return _slidePage(
          state.pageKey,
          ScoringRouter(
            tournamentId: tournamentId,
            matchId: matchId,
            sport: sport,
            homeTeam: home,
            awayTeam: away,
          ),
        );
      },
    ),
    GoRoute(
      path: '/notifications',
      pageBuilder: (ctx, state) =>
          _slidePage(state.pageKey, const _PlaceholderScreen(title: 'Notifications')),
    ),
    GoRoute(
      path: '/points-shop',
      pageBuilder: (ctx, state) =>
          _slidePage(state.pageKey, const _PlaceholderScreen(title: 'Points Shop')),
    ),
  ],
);

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B09),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(title),
      ),
      body: Center(
        child: Text(
          title,
          style: const TextStyle(color: Colors.white54, fontSize: 18),
        ),
      ),
    );
  }
}
