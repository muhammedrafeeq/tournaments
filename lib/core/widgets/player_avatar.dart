import 'package:flutter/material.dart';
import 'team_logo.dart'; // reuses kShieldColors

/// Circular avatar for a player — uploaded photo or initials on a colored disc.
class PlayerAvatarWidget extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final Color color;
  final double size;

  const PlayerAvatarWidget({
    super.key,
    required this.name,
    required this.color,
    this.avatarUrl,
    this.size = 48,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    if (name.length >= 2) return name.substring(0, 2).toUpperCase();
    return name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _InitialsDisc(
            color: color,
            initials: _initials,
            size: size,
          ),
        ),
      );
    }
    return _InitialsDisc(color: color, initials: _initials, size: size);
  }
}

class _InitialsDisc extends StatelessWidget {
  final Color color;
  final String initials;
  final double size;

  const _InitialsDisc({
    required this.color,
    required this.initials,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.3)!,
            color,
            Color.lerp(color, Colors.black, 0.2)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(80),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.32,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            shadows: const [
              Shadow(
                  color: Colors.black26,
                  blurRadius: 3,
                  offset: Offset(0, 1)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Returns a deterministic avatar color for a player based on their name.
Color avatarColorForName(String name) {
  if (name.isEmpty) return kShieldColors[0];
  final idx = name.codeUnits.fold(0, (a, b) => a + b) % kShieldColors.length;
  return kShieldColors[idx];
}
