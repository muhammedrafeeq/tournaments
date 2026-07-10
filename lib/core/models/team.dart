class Team {
  final String id;
  final String name;
  final String sport;
  final String? logoUrl;
  final String? colorHex;
  final String? captainId;
  final int playerCount;
  final bool isIndividual;
  final DateTime createdAt;

  const Team({
    required this.id,
    required this.name,
    required this.sport,
    this.logoUrl,
    this.colorHex,
    this.captainId,
    this.playerCount = 0,
    this.isIndividual = false,
    required this.createdAt,
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        name: json['name'] as String,
        sport: json['sport'] as String,
        logoUrl: json['logo_url'] as String?,
        colorHex: json['color_hex'] as String?,
        captainId: json['captain_id'] as String?,
        playerCount: (json['player_count'] as int?) ?? 0,
        isIndividual: (json['is_individual'] as bool?) ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sport': sport,
        'logo_url': logoUrl,
        'color_hex': colorHex,
        'captain_id': captainId,
        'is_individual': isIndividual,
        'created_at': createdAt.toIso8601String(),
      };
}
