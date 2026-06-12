import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

const _wcUrl =
    'https://raw.githubusercontent.com/openfootball/worldcup.json/master/2026/worldcup.json';

/// Tipsa til éin deltaker, lasta fra app-ressurs.
class Participant {
  final String name;
  // pairKey ("TeamA|TeamB", sortert) -> mål for [sortert A, sortert B]
  final Map<String, List<int>> byPair;
  final Map<String, String> medals; // gold/silver/bronze -> lag

  const Participant(this.name, this.byPair, this.medals);

  /// Tippa mål per lag for en gitt kamp, eller null om ikke tippet.
  Map<String, int>? forMatch(String t1, String t2) {
    final l = [t1, t2]..sort();
    final v = byPair['${l[0]}|${l[1]}'];
    if (v == null) return null;
    return {l[0]: v[0], l[1]: v[1]};
  }

  factory Participant.fromJson(Map<String, dynamic> j) {
    final map = <String, List<int>>{};
    for (final p in (j['predictions'] as List)) {
      final teams = (p['teams'] as List).cast<String>();
      final goals = (p['goals'] as Map);
      final l = [teams[0], teams[1]]..sort();
      map['${l[0]}|${l[1]}'] = [
        (goals[l[0]] as num).toInt(),
        (goals[l[1]] as num).toInt(),
      ];
    }
    final m = (j['medals'] as Map);
    return Participant(
      (j['name'] ?? '').toString(),
      map,
      {
        'gold': m['gold'].toString(),
        'silver': m['silver'].toString(),
        'bronze': m['bronze'].toString(),
      },
    );
  }

  static Future<List<Participant>> _loadFrom(String asset) async {
    final raw = await rootBundle.loadString(asset);
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return (j['participants'] as List)
        .map((e) => Participant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Participant>> loadAll() =>
      _loadFrom('assets/data/predictions.json');

  /// Den offisielle konkurransen (alle påmeldte, frå PDF-en).
  static Future<List<Participant>> loadOfficial() =>
      _loadFrom('assets/data/official.json');
}

Future<List<MatchInfo>> fetchMatches() async {
  final res = await http.get(Uri.parse(_wcUrl));
  if (res.statusCode != 200) {
    throw Exception('Klarte ikke hente kampdata (HTTP ${res.statusCode})');
  }
  final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  final list = j['matches'] as List;
  // openfootball nummererer bare sluttspillet; gruppekamper manglar 'num'.
  // Lista er kronologisk (72 gruppe + 32 sluttspill), så posisjon gir stabil id.
  return [
    for (var i = 0; i < list.length; i++)
      MatchInfo.fromJson({
        ...list[i] as Map<String, dynamic>,
        'num': i + 1,
      })
  ];
}

/// Manuelle overstyringar av resultat, lagra lokalt (per kamp-num).
class Overrides {
  final SharedPreferences _p;
  Overrides(this._p);

  static Future<Overrides> load() async =>
      Overrides(await SharedPreferences.getInstance());

  String _k(int num) => 'ovr_$num';

  /// [mål1, mål2] om overstyrt, elles null.
  List<int>? get(int num) {
    final s = _p.getString(_k(num));
    if (s == null) return null;
    final parts = s.split('-');
    if (parts.length != 2) return null;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return null;
    return [a, b];
  }

  Future<void> set(int num, int a, int b) => _p.setString(_k(num), '$a-$b');
  Future<void> clear(int num) => _p.remove(_k(num));
}
