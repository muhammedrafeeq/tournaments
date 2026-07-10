class Profile {
  final String id;
  final String username;
  final String? phone;
  final String? avatarUrl;
  final int level;
  final int xp;
  final int xpToNext;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.username,
    this.phone,
    this.avatarUrl,
    this.level = 1,
    this.xp = 0,
    this.xpToNext = 1000,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String,
        phone: json['phone'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        level: (json['level'] as int?) ?? 1,
        xp: (json['xp'] as int?) ?? 0,
        xpToNext: (json['xp_to_next'] as int?) ?? 1000,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'phone': phone,
        'avatar_url': avatarUrl,
        'level': level,
        'xp': xp,
        'xp_to_next': xpToNext,
        'created_at': createdAt.toIso8601String(),
      };

  Profile copyWith({
    String? username,
    String? avatarUrl,
    int? level,
    int? xp,
    int? xpToNext,
  }) =>
      Profile(
        id: id,
        username: username ?? this.username,
        phone: phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        level: level ?? this.level,
        xp: xp ?? this.xp,
        xpToNext: xpToNext ?? this.xpToNext,
        createdAt: createdAt,
      );
}
