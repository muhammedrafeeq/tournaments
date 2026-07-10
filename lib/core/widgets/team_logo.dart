import 'package:flutter/material.dart';

/// Displays a team logo: uploaded image if [logoUrl] is set,
/// otherwise a shield with initials in [color].
class TeamLogoWidget extends StatelessWidget {
  final String? logoUrl;
  final Color color;
  final String name;
  final double size;

  const TeamLogoWidget({
    super.key,
    required this.name,
    required this.color,
    this.logoUrl,
    this.size = 52,
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
    return SizedBox(
      width: size,
      height: size,
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? ClipPath(
              clipper: _ShieldClipper(),
              child: Image.network(
                logoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => _ShieldWithInitials(
                  color: color,
                  initials: _initials,
                  size: size,
                ),
              ),
            )
          : _ShieldWithInitials(
              color: color,
              initials: _initials,
              size: size,
            ),
    );
  }
}

class _ShieldWithInitials extends StatelessWidget {
  final Color color;
  final String initials;
  final double size;

  const _ShieldWithInitials({
    required this.color,
    required this.initials,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ShieldPainter(color),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.28,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            shadows: const [
              Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  final Color color;
  _ShieldPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(60)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(_shieldPath(w, h, offset: const Offset(0, 2)), shadowPaint);

    // Fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(color, Colors.white, 0.25)!,
          color,
          Color.lerp(color, Colors.black, 0.2)!,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(_shieldPath(w, h), fillPaint);

    // Gloss overlay
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.white.withAlpha(60),
          Colors.white.withAlpha(0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.5));
    canvas.drawPath(_shieldPath(w, h), glossPaint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.white.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(_shieldPath(w, h), borderPaint);
  }

  Path _shieldPath(double w, double h, {Offset offset = Offset.zero}) {
    final dx = offset.dx;
    final dy = offset.dy;
    final r = w * 0.12; // corner radius at top
    final path = Path();
    path.moveTo(dx + r, dy);
    path.lineTo(dx + w - r, dy);
    path.quadraticBezierTo(dx + w, dy, dx + w, dy + r);
    path.lineTo(dx + w, dy + h * 0.58);
    path.quadraticBezierTo(dx + w, dy + h * 0.82, dx + w * 0.5, dy + h);
    path.quadraticBezierTo(dx, dy + h * 0.82, dx, dy + h * 0.58);
    path.lineTo(dx, dy + r);
    path.quadraticBezierTo(dx, dy, dx + r, dy);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_ShieldPainter old) => old.color != color;
}

class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.12;
    final path = Path();
    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r);
    path.lineTo(w, h * 0.58);
    path.quadraticBezierTo(w, h * 0.82, w * 0.5, h);
    path.quadraticBezierTo(0, h * 0.82, 0, h * 0.58);
    path.lineTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_ShieldClipper old) => false;
}

/// The 8 preset shield colors users can choose from.
const kShieldColors = [
  Color(0xFFE53935), // red
  Color(0xFF1E88E5), // blue
  Color(0xFF43A047), // green
  Color(0xFFFB8C00), // orange
  Color(0xFF8E24AA), // purple
  Color(0xFF00ACC1), // teal
  Color(0xFFFFB300), // amber
  Color(0xFF546E7A), // steel
];

/// Returns a deterministic color for a team based on its name.
Color shieldColorForName(String name) {
  if (name.isEmpty) return kShieldColors[0];
  final idx = name.codeUnits.fold(0, (a, b) => a + b) % kShieldColors.length;
  return kShieldColors[idx];
}

/// Parses a hex color string like '#E53935' into a Color.
Color? colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return null;
  }
}
