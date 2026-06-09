// Løyser sluttspeltreet: koplar openfootball sine plassholdarar (1H, 2J,
// 3A/B/C/D/F, W74, L101) til faktiske lag når dei finst, elles til Thea sine
// predikerte gruppevinnarar/2-arar/3-arar (projeksjon før gruppespelet er ferdig).
//
// Tredjeplass-plassane følgjer FIFA sitt offisielle oppsett: kvar plass (t.d.
// "3A/B/C/D/F") kan berre få ein 3.plass frå dei oppgjevne gruppene. Av dei 12
// gruppetrearanane går dei 8 beste vidare (rangert på poeng, målforskjell, mål),
// og dei vert fordelte på plassane med ei tildeling som respekterer kva grupper
// kvar plass har lov å ta imot.
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

/// Ei rad i ein gruppetabell (med statistikk for rangering).
class _GroupRow {
  final String team;
  final int pts, gf, ga;
  const _GroupRow(this.team, this.pts, this.gf, this.ga);
  int get gd => gf - ga;
}

/// Ein resultatkjelde for ein gruppekamp: returnerer {team1: mål, team2: mål}
/// eller null om kampen ikkje har eit (tippa eller spelt) resultat enno.
typedef ScoreFor = Map<String, int>? Function(MatchInfo m);

/// Rik gruppetabell ut frå ei resultatkjelde (tippingar eller faktiske resultat).
/// "Group X" -> rangerte rader (1.,2.,3.,4.).
Map<String, List<_GroupRow>> _richStandings(
    ScoreFor scoreFor, List<MatchInfo> matches,
    {bool requireComplete = false}) {
  final groups = <String, List<MatchInfo>>{};
  for (final m in matches.where((m) => m.isGroup)) {
    groups.putIfAbsent(m.group, () => []).add(m);
  }
  final out = <String, List<_GroupRow>>{};
  groups.forEach((g, ms) {
    // I "Resultat"-modus tek vi berre med grupper som er heilt ferdigspelte,
    // slik at uavgjorde plassar viser plassholdaren (t.d. "1A") i staden for ei
    // tilfeldig (alfabetisk) gjetting på ein 0-0-0-tabell.
    if (requireComplete && ms.any((m) => scoreFor(m) == null)) return;
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
      final pred = scoreFor(m);
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
      ..sort((a, b) => _cmpStanding(
            _GroupRow(a, pts[a]!, gf[a]!, ga[a]!),
            _GroupRow(b, pts[b]!, gf[b]!, ga[b]!),
          ));
    out[g] = [
      for (final t in ranked) _GroupRow(t, pts[t]!, gf[t]!, ga[t]!),
    ];
  });
  return out;
}

/// Rangering: poeng, så målforskjell, så mål, så namn (stabilt).
int _cmpStanding(_GroupRow a, _GroupRow b) {
  final c1 = b.pts.compareTo(a.pts);
  if (c1 != 0) return c1;
  final c2 = b.gd.compareTo(a.gd);
  if (c2 != 0) return c2;
  final c3 = b.gf.compareTo(a.gf);
  if (c3 != 0) return c3;
  return a.team.compareTo(b.team);
}

/// Gruppetabell ut frå ein deltakar sine tippa resultat.
/// Returnerer kart: "Group X" -> rangerte lagnamn (1.,2.,3.,4.).
Map<String, List<String>> predictedStandings(
    Participant p, List<MatchInfo> matches) {
  return _richStandings((m) => p.forMatch(m.team1, m.team2), matches)
      .map((g, rows) => MapEntry(g, [for (final r in rows) r.team]));
}

final _slotRe = RegExp(r'^([12])([A-L])$');
final _wlRe = RegExp(r'^([WL])(\d+)$');

/// Parsar ein 3.plass-kode som "3A/B/C/D/F" til gruppebokstavane den kan ta imot.
/// Returnerer null om koden ikkje er ein 3.plass-plass.
List<String>? _thirdGroups(String code) {
  if (!code.startsWith('3') || code.length < 2) return null;
  final parts = code.substring(1).split('/');
  if (parts.every((p) => p.length == 1 && _isGroupLetter(p))) return parts;
  return null;
}

bool _isGroupLetter(String s) {
  final c = s.codeUnitAt(0);
  return c >= 65 && c <= 76; // A..L
}

/// Bipartitt maksmatching (Kuhn): tildeler kvar plass éi tillaten gruppe.
/// [slotAllowed][s] = liste over gruppeindeksar plassen kan ta imot (0=A..11=L).
/// Returnerer slotToGroup: gruppeindeks per plass, eller null om uavklart.
List<int?> _matchSlots(List<List<int>> slotAllowed, int numGroups) {
  final slotToGroup = List<int?>.filled(slotAllowed.length, null);
  final groupToSlot = List<int?>.filled(numGroups, null);

  bool tryAssign(int s, List<bool> seen) {
    for (final g in slotAllowed[s]) {
      if (seen[g]) continue;
      seen[g] = true;
      if (groupToSlot[g] == null || tryAssign(groupToSlot[g]!, seen)) {
        slotToGroup[s] = g;
        groupToSlot[g] = s;
        return true;
      }
    }
    return false;
  }

  for (var s = 0; s < slotAllowed.length; s++) {
    tryAssign(s, List<bool>.filled(numGroups, false));
  }
  return slotToGroup;
}

/// Bygg heile sluttspeltreet, runde for runde (R32 først).
/// [winnerSide] gir faktisk vinnar-side (1/2) for ein spelt kamp, elles null.
/// Bygg sluttspeltreet.
/// - [scoreFor]: kjelda til gruppeplasseringane. I "Projeksjon"-modus er dette
///   deltakaren sine tippingar; i "Resultat"-modus er det faktiske resultat.
/// - [winnerSide]: faktisk vinnar-side (1/2) for ein spelt sluttspelkamp.
/// I "Resultat"-modus bør [scoreFor] berre gje resultat for ferdigspelte kampar,
/// slik at treet fyller seg etter kvart som det vert spelt.
List<KoMatch> buildBracket({
  required ScoreFor scoreFor,
  required List<MatchInfo> matches,
  required int? Function(MatchInfo) winnerSide,
  bool requireComplete = false,
}) {
  final rich =
      _richStandings(scoreFor, matches, requireComplete: requireComplete);
  final standings =
      rich.map((g, rows) => MapEntry(g, [for (final r in rows) r.team]));
  final groupTeams = <String>{
    for (final m in matches.where((m) => m.isGroup)) ...[m.team1, m.team2]
  };
  final ko = matches.where((m) => !m.isGroup).toList()
    ..sort((a, b) => a.num.compareTo(b.num));
  final byNum = {for (final m in ko) m.num: m};
  final resolved = <int, KoMatch>{};

  // --- Tredjeplass-fordeling (FIFA-oppsett) ---------------------------------
  // 1) 3.plass i kvar gruppe, med statistikk.
  final thirds = <_GroupRow>[]; // rad
  final thirdGroupOf = <String, String>{}; // lagnamn -> gruppebokstav
  rich.forEach((g, rows) {
    if (rows.length >= 3) {
      final letter = g.replaceFirst('Group ', '');
      thirds.add(rows[2]);
      thirdGroupOf[rows[2].team] = letter;
    }
  });
  // 2) Rangér alle gruppetrearanane og ta dei 8 beste.
  thirds.sort(_cmpStanding);
  final qualified = thirds.take(8).toList();
  final teamByGroup = <String, String>{
    for (final r in qualified) thirdGroupOf[r.team]!: r.team,
  };
  final qualGroups = teamByGroup.keys.toSet();
  // 3) Samle 3.plass-plassane i kampnummer-rekkjefølgje.
  final thirdSlots = <String>[]; // kodestrengar (unike)
  for (final m in ko) {
    for (final code in [m.team1, m.team2]) {
      if (_thirdGroups(code) != null && !thirdSlots.contains(code)) {
        thirdSlots.add(code);
      }
    }
  }
  // 4) Matching som respekterer kva grupper kvar plass kan ta imot.
  int gi(String letter) => letter.codeUnitAt(0) - 65;
  final slotAllowed = [
    for (final code in thirdSlots)
      [
        for (final g in _thirdGroups(code)!)
          if (qualGroups.contains(g)) gi(g)
      ]
  ];
  final assign = _matchSlots(slotAllowed, 12);
  final thirdSlotToTeam = <String, String>{};
  for (var i = 0; i < thirdSlots.length; i++) {
    final g = assign[i];
    if (g != null) {
      final letter = String.fromCharCode(65 + g);
      thirdSlotToTeam[thirdSlots[i]] = teamByGroup[letter]!;
    }
  }
  // --------------------------------------------------------------------------

  // I "Resultat"-modus resolvar gruppeplassane berre når gruppa er ferdigspelt,
  // så då er dei ekte (ikkje projiserte). I "Projeksjon"-modus er dei tippa.
  final markProjected = !requireComplete;

  KoTeam resolveSlot(String code) {
    // Allereie eit ekte lag (gruppespel ferdig / kamp trekt).
    if (groupTeams.contains(code)) return KoTeam(code, code);

    final m = _slotRe.firstMatch(code);
    if (m != null) {
      final pos = m[1]!;
      final tbl = standings['Group ${m[2]}'];
      if (tbl != null && tbl.length >= 2) {
        final t = pos == '1' ? tbl[0] : tbl[1];
        return KoTeam(t, t, projected: markProjected);
      }
      return KoTeam(null, code);
    }
    if (_thirdGroups(code) != null) {
      final t = thirdSlotToTeam[code];
      if (t != null) return KoTeam(t, t, projected: markProjected);
      return KoTeam(null, '3.plass');
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
