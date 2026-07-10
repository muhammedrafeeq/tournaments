class Player {
  final String id;
  final String profileId;
  final String name;
  final String? teamId;
  final String? sport;
  final String? role;
  final int? jerseyNumber;
  final String? avatarUrl;
  final Map<String, dynamic> stats;
  final DateTime createdAt;

  const Player({
    required this.id,
    required this.profileId,
    required this.name,
    this.teamId,
    this.sport,
    this.role,
    this.jerseyNumber,
    this.avatarUrl,
    this.stats = const {},
    required this.createdAt,
  });

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        profileId: json['profile_id'] as String,
        name: json['name'] as String,
        teamId: json['team_id'] as String?,
        sport: json['sport'] as String?,
        role: json['role'] as String?,
        jerseyNumber: json['jersey_number'] as int?,
        avatarUrl: json['avatar_url'] as String?,
        stats: (json['stats'] as Map<String, dynamic>?) ?? {},
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile_id': profileId,
        'name': name,
        'team_id': teamId,
        'sport': sport,
        'role': role,
        'jersey_number': jerseyNumber,
        'avatar_url': avatarUrl,
        'stats': stats,
        'created_at': createdAt.toIso8601String(),
      };
}
