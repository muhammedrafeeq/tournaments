import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TournamentTemplate {
  final String name;
  final String sport;
  final String type;
  final String drawMethod;
  final int maxTeams;
  final bool isPublic;

  const TournamentTemplate({
    required this.name,
    required this.sport,
    required this.type,
    required this.drawMethod,
    required this.maxTeams,
    required this.isPublic,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'sport': sport,
        'type': type,
        'drawMethod': drawMethod,
        'maxTeams': maxTeams,
        'isPublic': isPublic,
      };

  factory TournamentTemplate.fromJson(Map<String, dynamic> j) =>
      TournamentTemplate(
        name: j['name'] as String,
        sport: j['sport'] as String,
        type: j['type'] as String,
        drawMethod: j['drawMethod'] as String,
        maxTeams: (j['maxTeams'] as num).toInt(),
        isPublic: j['isPublic'] as bool? ?? true,
      );
}

class TournamentTemplateService {
  static const _key = 'tournament_templates';

  Future<List<TournamentTemplate>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) {
          try {
            return TournamentTemplate.fromJson(
                json.decode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<TournamentTemplate>()
        .toList();
  }

  Future<void> save(TournamentTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    existing.add(json.encode(template.toJson()));
    await prefs.setStringList(_key, existing);
  }

  Future<void> delete(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    if (index >= 0 && index < existing.length) {
      existing.removeAt(index);
      await prefs.setStringList(_key, existing);
    }
  }
}
