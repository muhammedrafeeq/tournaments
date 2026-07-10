class Match {
  final String id;
  final String tournamentId;
  final String? homeTeamId;
  final String? awayTeamId;
  final String? homeTeamName;
  final String? awayTeamName;
  final String sport;
  final String status; // scheduled, live, completed, cancelled
  final int? homeScore;
  final int? awayScore;
  final DateTime? scheduledAt;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const Match({
    required this.id,
    required this.tournamentId,
    this.homeTeamId,
    this.awayTeamId,
    this.homeTeamName,
    this.awayTeamName,
    required this.sport,
    required this.status,
    this.homeScore,
    this.awayScore,
    this.scheduledAt,
    this.metadata = const {},
    required this.createdAt,
  });

  factory Match.fromJson(Map<String, dynamic> json) => Match(
        id: json['id'] as String,
        tournamentId: json['tournament_id'] as String,
        homeTeamId: json['home_team_id'] as String?,
        awayTeamId: json['away_team_id'] as String?,
        homeTeamName: json['home_team_name'] as String?,
        awayTeamName: json['away_team_name'] as String?,
        sport: json['sport'] as String,
        status: json['status'] as String,
        homeScore: json['home_score'] as int?,
        awayScore: json['away_score'] as int?,
        scheduledAt: json['scheduled_at'] != null
            ? DateTime.parse(json['scheduled_at'] as String)
            : null,
        metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tournament_id': tournamentId,
        'home_team_id': homeTeamId,
        'away_team_id': awayTeamId,
        'home_team_name': homeTeamName,
        'away_team_name': awayTeamName,
        'sport': sport,
        'status': status,
        'home_score': homeScore,
        'away_score': awayScore,
        'scheduled_at': scheduledAt?.toIso8601String(),
        'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
      };

  Match copyWith({
    String? status,
    int? homeScore,
    int? awayScore,
    Map<String, dynamic>? metadata,
  }) =>
      Match(
        id: id,
        tournamentId: tournamentId,
        homeTeamId: homeTeamId,
        awayTeamId: awayTeamId,
        homeTeamName: homeTeamName,
        awayTeamName: awayTeamName,
        sport: sport,
        status: status ?? this.status,
        homeScore: homeScore ?? this.homeScore,
        awayScore: awayScore ?? this.awayScore,
        scheduledAt: scheduledAt,
        metadata: metadata ?? this.metadata,
        createdAt: createdAt,
      );
}
