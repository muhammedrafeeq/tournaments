import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PendingScoreUpdate {
  final String matchId;
  final int homeScore;
  final int awayScore;
  final Map<String, dynamic> metadata;
  final bool isFinal;
  final String timestamp;

  const PendingScoreUpdate({
    required this.matchId,
    required this.homeScore,
    required this.awayScore,
    required this.metadata,
    required this.isFinal,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'matchId': matchId,
        'homeScore': homeScore,
        'awayScore': awayScore,
        'metadata': metadata,
        'isFinal': isFinal,
        'timestamp': timestamp,
      };

  factory PendingScoreUpdate.fromJson(Map<String, dynamic> j) =>
      PendingScoreUpdate(
        matchId: j['matchId'] as String,
        homeScore: (j['homeScore'] as num).toInt(),
        awayScore: (j['awayScore'] as num).toInt(),
        metadata: Map<String, dynamic>.from(j['metadata'] as Map),
        isFinal: j['isFinal'] as bool? ?? false,
        timestamp: j['timestamp'] as String,
      );
}

class OfflineSyncService {
  static const _key = 'pending_score_updates';

  static final OfflineSyncService _instance = OfflineSyncService._();
  OfflineSyncService._();
  factory OfflineSyncService() => _instance;

  Future<List<PendingScoreUpdate>> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final result = <PendingScoreUpdate>[];
    for (final s in raw) {
      try {
        result.add(
            PendingScoreUpdate.fromJson(json.decode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    return result;
  }

  Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).length;
  }

  /// Queue an update, replacing any existing entry for the same matchId.
  Future<void> queue(PendingScoreUpdate update) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    final filtered = existing.where((s) {
      try {
        final m = json.decode(s) as Map<String, dynamic>;
        return m['matchId'] != update.matchId;
      } catch (_) {
        return true;
      }
    }).toList();
    filtered.add(json.encode(update.toJson()));
    await prefs.setStringList(_key, filtered);
  }

  Future<void> remove(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    final filtered = existing.where((s) {
      try {
        final m = json.decode(s) as Map<String, dynamic>;
        return m['matchId'] != matchId;
      } catch (_) {
        return true;
      }
    }).toList();
    await prefs.setStringList(_key, filtered);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
