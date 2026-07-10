class Tournament {
  final String id;
  final String name;
  final String sport;
  final String type; // teams, individual
  final String status; // draft, upcoming, live, completed
  final String? organizerId;
  final String? location;
  final DateTime? startDate;
  final DateTime? endDate;
  final int maxTeams;
  final int currentTeams;
  final String? description;
  final String? inviteCode;
  final DateTime createdAt;

  const Tournament({
    required this.id,
    required this.name,
    required this.sport,
    this.type = 'teams',
    required this.status,
    this.organizerId,
    this.location,
    this.startDate,
    this.endDate,
    this.maxTeams = 16,
    this.currentTeams = 0,
    this.description,
    this.inviteCode,
    required this.createdAt,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
        id: json['id'] as String,
        name: json['name'] as String,
        sport: json['sport'] as String,
        type: (json['type'] as String?) ?? 'teams',
        status: json['status'] as String,
        organizerId: json['organizer_id'] as String?,
        location: json['location'] as String?,
        startDate: json['start_date'] != null
            ? DateTime.parse(json['start_date'] as String)
            : null,
        endDate: json['end_date'] != null
            ? DateTime.parse(json['end_date'] as String)
            : null,
        maxTeams: (json['max_teams'] as int?) ?? 16,
        currentTeams: (json['current_teams'] as int?) ?? 0,
        description: json['description'] as String?,
        inviteCode: json['invite_code'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sport': sport,
        'type': type,
        'status': status,
        'organizer_id': organizerId,
        'location': location,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'max_teams': maxTeams,
        'current_teams': currentTeams,
        'description': description,
        'created_at': createdAt.toIso8601String(),
      };
}
