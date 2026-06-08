// Løyser sluttspeltreet: koplar openfootball sine plassholdarar (1H, 2J,
// 3C/D/F/G/H, W74, L101) til faktiske lag når dei finst, elles til Thea sine
// predikerte gruppevinnarar/2-arar (projeksjon før gruppespelet er ferdig).
import 'data.dart';
import 'models.dart';

/// Eitt lag i ein sluttspelkamp.
class KoTeam {
  final String? team; // engelsk lagnamn, eller null om uavklart
  final String label; // det som skal visast
  final bool projected; // true = tippa gruppeplassering (ikkje spelt enno)
  const KoTeam(this.team, this.label, {this.projected = false});
  bool get resolved => team != null;
}

class KoMatch {
  final int num;
  final String round;
  final KoTeam home, away;
  const KoMatch(this.num, this.round, this.home, this.away);
}

/// Gruppetabell ut frå ein deltakar sine tippa resultat.
/// Returnerer kart: "Group X" -> rangerte lagnamn (1.,2.,3.,4.).
Map<String, List<String>> predictedStandings(
    Participant p, List<MatchInfo> matches) {
  final groups = <String, List<MatchInfo>>{};
  for (final m in matches.where((m) => m.isGroup)) {
    groups.putIfAbsent(m.group, () => []).add(m);
  }
  final out = <String, List<String>>{};
  groups.forEach((g, ms) {
    final pts = <String, int>{};
    final gf = <String, int>{};
    final ga = <String, int>{};
    final teams = <String>{};
    void ensure(String t) {
      teams.add(t);
      pts.putIfAbsent(t, () => 0);
      gf.putIfAbsent(t, () => 0);
      ga.putIfAbsent(t, () => 0);
    }

    for (final m in ms) {
      ensure(m.team1);
      ensure(m.team2);
      final pred = p.forMatch(m.team1, m.team2);
      if (pred == null) continue;
      final x = pred[m.team1]!, y = pred[m.team2]!;
      gf[m.team1] = gf[m.team1]! + x;
      ga[m.team1] = ga[m.team1]! + y;
      gf[m.team2] = gf[m.team2]! + y;
      ga[m.team2] = ga[m.team2]! + x;
      if (x > y) {
        pts[m.team1] = pts[m.team1]! + 3;
      } else if (y > x) {
        pts[m.team2] = pts[m.team2]! + 3;
      } else {
        pts[m.team1] = pts[m.team1]! + 1;
        pts[m.team2] = pts[m.team2]! + 1;
      }
    }
    final ranked = teams.toList()
      ..sort((a, b) {
        final c1 = pts[b]!.compareTo(pts[a]!);
        if (c1 != 0) return c1;
        final c2 = (gf[b]! - ga[b]!).compareTo(gf[a]! - ga[a]!);
        if (c2 != 0) return c2;
        final c3 = gf[b]!.compareTo(gf[a]!);
        if (c3 != 0) return c3;
        return a.compareTo(b);
      });
    out[g] = ranked;
  });
  return out;
}

final _slotRe = RegExp(r'^([12])([A-L])$');
final _wlRe = RegExp(r'^([WL])(\d+)$');

/// Bygg heile sluttspeltreet, runde for runde (R32 først).
/// [winnerSide] gir faktisk vinnar-side (1/2) for ein spelt kamp, elles null.
List<KoMatch> buildBracket({
  required Participant participant,
  required List<MatchInfo> matches,
  required int? Function(MatchInfo) winnerSide,
}) {
  final standings = predictedStandings(participant, matches);
  final groupTeams = <String>{
    for (final m in matches.where((m) => m.isGroup)) ...[m.team1, m.team2]
  };
  final ko = matches.where((m) => !m.isGroup).toList()
    ..sort((a, b) => a.num.compareTo(b.num));
  final byNum = {for (final m in ko) m.num: m};
  final resolved = <int, KoMatch>{};

  KoTeam resolveSlot(String code) {
    // Allereie eit ekte lag (gruppespel ferdig / kamp trekt).
    if (groupTeams.contains(code)) return KoTeam(code, code);

    final m = _slotRe.firstMatch(code);
    if (m != null) {
      final pos = m[1]!;
      final tbl = standings['Group ${m[2]}'];
      if (tbl != null && tbl.length >= 2) {
        final t = pos == '1' ? tbl[0] : tbl[1];
        return KoTeam(t, t, projected: true);
      }
      return KoTeam(null, code);
    }
    if (code.startsWith('3')) {
      return KoTeam(null, '3.plass'); // ein av fleire grupper
    }
    final wl = _wlRe.firstMatch(code);
    if (wl != null) {
      final isWinner = wl[1] == 'W';
      final n = int.parse(wl[2]!);
      final feeder = resolved[n];
      final fm = byNum[n];
      if (feeder != null && fm != null) {
        final w = winnerSide(fm); // berre kjent når kampen er spelt
        if (w == 1 || w == 2) {
          final advancing = (w == 1) == isWinner ? feeder.home : feeder.away;
          if (advancing.resolved) {
            return KoTeam(advancing.team, advancing.team!);
          }
        }
      }
      return KoTeam(null, isWinner ? 'Vinnar K$n' : 'Tapar K$n');
    }
    return KoTeam(null, code);
  }

  for (final m in ko) {
    final km = KoMatch(
      m.num,
      m.round,
      resolveSlot(m.team1),
      resolveSlot(m.team2),
    );
    resolved[m.num] = km;
  }
  return ko.map((m) => resolved[m.num]!).toList();
}
