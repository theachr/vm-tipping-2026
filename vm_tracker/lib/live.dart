// Live-resultat fra ESPN sitt opne scoreboard-API (gratis, utan nøkkel, CORS-ope).
// Vi matchar ESPN-kamper mot våre gruppekamper på lag-paret (unikt), og rettar
// inn stillinga etter våre team1/team2. Sluttspillet har plassholdar-navn i vår
// statiske data, så live gjeld førebels gruppespillet.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

const _espnBase =
    'https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard';

// ESPN-navn -> våre (openfootball-engelske) navn. Resten er like.
const _alias = <String, String>{
  'Czechia': 'Czech Republic',
  'Türkiye': 'Turkey',
  'United States': 'USA',
  'Congo DR': 'DR Congo',
  'Bosnia-Herzegovina': 'Bosnia & Herzegovina',
};

String _norm(String espn) => _alias[espn] ?? espn;
String _two(int n) => n.toString().padLeft(2, '0');

/// Live-info for éin kamp. Stillinga er retta inn etter våre team1/team2.
class LiveInfo {
  final String state; // 'pre' | 'in' | 'post'
  final int? s1, s2; // mål for team1 / team2
  final String detail; // f.eks. "45'+2'", "Halftime", "FT"
  const LiveInfo(this.state, this.s1, this.s2, this.detail);
  bool get inPlay => state == 'in';
  bool get finished => state == 'post';
}

/// Hentar live-data for kamper rundt no (i går–i morgon) og matchar de mot
/// gruppekampene våre. Returnerer kart fra kamp-nummer til [LiveInfo].
Future<Map<int, LiveInfo>> fetchLive(List<MatchInfo> matches) async {
  // Lag-par (sortert, våre navn) -> kamp-nummer, bare for kamper med ekte navn.
  final pairToNum = <String, int>{};
  final byNum = <int, MatchInfo>{};
  for (final m in matches) {
    byNum[m.num] = m;
    if (!m.isGroup) continue;
    final l = [m.team1, m.team2]..sort();
    pairToNum['${l[0]}|${l[1]}'] = m.num;
  }

  final now = DateTime.now();
  final out = <int, LiveInfo>{};
  for (var d = -1; d <= 1; d++) {
    final dt = now.add(Duration(days: d));
    final ymd = '${dt.year}${_two(dt.month)}${_two(dt.day)}';
    try {
      final res = await http
          .get(Uri.parse('$_espnBase?dates=$ymd'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) continue;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      for (final e in (j['events'] as List? ?? const [])) {
        final comps = (e['competitions'] as List?) ?? const [];
        if (comps.isEmpty) continue;
        final cs = (comps.first['competitors'] as List?) ?? const [];
        if (cs.length != 2) continue;
        final c0 = cs[0] as Map<String, dynamic>;
        final c1 = cs[1] as Map<String, dynamic>;
        final home = c0['homeAway'] == 'home' ? c0 : c1;
        final away = c0['homeAway'] == 'home' ? c1 : c0;
        final hn = _norm((home['team']?['displayName'] ?? '').toString());
        final an = _norm((away['team']?['displayName'] ?? '').toString());
        final l = [hn, an]..sort();
        final num = pairToNum['${l[0]}|${l[1]}'];
        if (num == null) continue;
        final st = (e['status']?['type']?['state'] ?? '').toString();
        final detail = (e['status']?['type']?['shortDetail'] ?? '').toString();
        final hs = int.tryParse((home['score'] ?? '').toString());
        final as = int.tryParse((away['score'] ?? '').toString());
        // Rett inn mot våre team1/team2.
        final m = byNum[num]!;
        final s1 = m.team1 == hn ? hs : as;
        final s2 = m.team1 == hn ? as : hs;
        out[num] = LiveInfo(st, s1, s2, detail);
      }
    } catch (_) {
      // Hopp over – live er «best effort».
    }
  }
  return out;
}
