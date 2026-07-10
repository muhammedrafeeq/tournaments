import 'package:flutter/material.dart';
import 'cricket_scoring_screen.dart';
import 'football_scoring_screen.dart';
import 'efootball_scoring_screen.dart';
import 'basketball_scoring_screen.dart';
import 'tennis_scoring_screen.dart';
import 'badminton_scoring_screen.dart';
import 'chess_scoring_screen.dart';
import 'generic_scoring_screen.dart';

class ScoringRouter extends StatelessWidget {
  final String tournamentId;
  final String matchId;
  final String sport;
  final String homeTeam;
  final String awayTeam;

  const ScoringRouter({
    super.key,
    required this.tournamentId,
    required this.matchId,
    required this.sport,
    this.homeTeam = 'Home',
    this.awayTeam = 'Away',
  });

  @override
  Widget build(BuildContext context) {
    switch (sport.toLowerCase()) {
      case 'cricket':
        return CricketScoringScreen(
          matchId: matchId,
          homeTeam: homeTeam,
          awayTeam: awayTeam,
        );
      case 'football':
        return FootballScoringScreen(
          matchId: matchId,
          homeTeam: homeTeam,
          awayTeam: awayTeam,
        );
      case 'efootball':
        return EFootballScoringScreen(
          matchId: matchId,
          homeTeam: homeTeam,
          awayTeam: awayTeam,
        );
      case 'basketball':
        return BasketballScoringScreen(
          matchId: matchId,
          homeTeam: homeTeam,
          awayTeam: awayTeam,
        );
      case 'tennis':
        return TennisScoringScreen(
          matchId: matchId,
          playerA: homeTeam,
          playerB: awayTeam,
        );
      case 'badminton':
        return BadmintonScoringScreen(
          matchId: matchId,
          playerA: homeTeam,
          playerB: awayTeam,
        );
      case 'chess':
        return ChessScoringScreen(
          matchId: matchId,
          playerWhite: homeTeam,
          playerBlack: awayTeam,
        );
      default:
        return GenericScoringScreen(
          matchId: matchId,
          teamA: homeTeam,
          teamB: awayTeam,
          sport: sport,
        );
    }
  }
}
