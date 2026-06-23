// Løyser sluttspilltreet: koplar openfootball sine plassholdarar (1H, 2J,
// 3A/B/C/D/F, W74, L101) til faktiske lag når de finst, elles til Thea sine
// predikerte gruppevinnerar/2-arar/3-arar (projeksjon før gruppespillet er ferdig).
//
// Tredjeplass-plassene følger FIFA sitt offisielle oppsett: hver plass (f.eks.
// "3A/B/C/D/F") kan bare få en 3.plass fra de oppgjevne gruppene. Av de 12
// gruppetrearanane går de 8 beste videre (rangert på poeng, målforskjell, mål),
// og de blir fordelte på plassene med ei tildeling som respekterer hva grupper
// hver plass har lov å ta imot.
import 'data.dart';
import 'models.dart';

/// Eitt lag i en sluttspillkamp.
class KoTeam {
  final String? team; // engelsk lagnavn, eller null om uavklart
  final String label; // det som skal visast
  final bool projected; // true = tippet gruppeplassering (ikke spilt ennå)
  const KoTeam(this.team, this.label, {this.projected = false});
  bool get resolved => team != null;
}

class KoMatch {
  final int num;
  final String round;
  final KoTeam home, away;
  const KoMatch(this.num, this.round, this.home, this.away);
}

/// Ei rad i en gruppetabell (med statistikk for rangering).
class _GroupRow {
  final String team;
  final int pts, gf, ga;
  const _GroupRow(this.team, this.pts, this.gf, this.ga);
  int get gd => gf - ga;
}

/// En resultatkjelde for en gruppekamp: returnerer {team1: mål, team2: mål}
/// eller null om kampen ikke har et (tippet eller spilt) resultat ennå.
typedef ScoreFor = Map<String, int>? Function(MatchInfo m);

/// Rik gruppetabell ut fra ei resultatkjelde (tippingar eller faktiske resultat).
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
    // I "Resultat"-modus tar vi bare med grupper som er heilt ferdigspilt,
    // slik at uavgjorte plasser viser plassholdaren (f.eks. "1A") i staden for ei
    // tilfeldig (alfabetisk) gjetting på en 0-0-0-tabell.
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

/// Rangering: poeng, så målforskjell, så mål, så navn (stabilt).
int _cmpStanding(_GroupRow a, _GroupRow b) {
  final c1 = b.pts.compareTo(a.pts);
  if (c1 != 0) return c1;
  final c2 = b.gd.compareTo(a.gd);
  if (c2 != 0) return c2;
  final c3 = b.gf.compareTo(a.gf);
  if (c3 != 0) return c3;
  return a.team.compareTo(b.team);
}

/// Gruppetabell ut fra en deltaker sine tippet resultat.
/// Returnerer kart: "Group X" -> rangerte lagnavn (1.,2.,3.,4.).
Map<String, List<String>> predictedStandings(
    Participant p, List<MatchInfo> matches) {
  return _richStandings((m) => p.forMatch(m.team1, m.team2), matches)
      .map((g, rows) => MapEntry(g, [for (final r in rows) r.team]));
}

/// Gruppetabeller (rangerte lagnavn) ut fra ei vilkårleg resultatkjelde.
/// Med [requireComplete] blir bare ferdigspilt grupper tekne med.
Map<String, List<String>> standingsFromScore(
    ScoreFor scoreFor, List<MatchInfo> matches,
    {bool requireComplete = false}) {
  return _richStandings(scoreFor, matches, requireComplete: requireComplete)
      .map((g, rows) => MapEntry(g, [for (final r in rows) r.team]));
}

/// Korleis et lag går videre fra gruppa.
enum Advance {
  direct, // 1. eller 2.plass – direkte videre
  thirdIn, // 3.plass blant de 8 beste – videre
  thirdOut, // 3.plass, men ikke blant de 8 beste – ute
  out, // 4.plass – ute
}

/// Ei visningsklar rad i en gruppetabell.
class TeamStanding {
  final int rank; // 1..4
  final String team;
  final int pts, gf, ga;
  final Advance advance;
  final int? thirdRank; // plassering (1..12) blant 3.plassene, bare for 3.plass
  const TeamStanding({
    required this.rank,
    required this.team,
    required this.pts,
    required this.gf,
    required this.ga,
    required this.advance,
    this.thirdRank,
  });
  int get gd => gf - ga;
}

/// Fulle gruppetabeller med rangering og videre-status (inkl. beste 8 av
/// 3.plassene). "Group X" -> rader sortert 1.,2.,3.,4.
Map<String, List<TeamStanding>> groupTables(
    ScoreFor scoreFor, List<MatchInfo> matches,
    {bool requireComplete = false}) {
  final rich =
      _richStandings(scoreFor, matches, requireComplete: requireComplete);
  // Rangér alle 3.plassene og finn de 8 beste.
  final thirds = <_GroupRow>[];
  rich.forEach((g, rows) {
    if (rows.length >= 3) thirds.add(rows[2]);
  });
  thirds.sort(_cmpStanding);
  final thirdRankOf = <String, int>{
    for (var i = 0; i < thirds.length; i++) thirds[i].team: i + 1,
  };
  final qualifiedThirds = thirds.take(8).map((r) => r.team).toSet();

  final out = <String, List<TeamStanding>>{};
  rich.forEach((g, rows) {
    out[g] = [
      for (var i = 0; i < rows.length; i++)
        TeamStanding(
          rank: i + 1,
          team: rows[i].team,
          pts: rows[i].pts,
          gf: rows[i].gf,
          ga: rows[i].ga,
          advance: i < 2
              ? Advance.direct
              : (i == 2
                  ? (qualifiedThirds.contains(rows[i].team)
                      ? Advance.thirdIn
                      : Advance.thirdOut)
                  : Advance.out),
          thirdRank: i == 2 ? thirdRankOf[rows[i].team] : null,
        ),
    ];
  });
  return out;
}

final _slotRe = RegExp(r'^([12])([A-L])$');
final _wlRe = RegExp(r'^([WL])(\d+)$');

// ---- Scenario-veljar: "hvem møter laget i sluttspillet" ---------------------

/// Eitt steg på vegen gjennom sluttspillet.
class ScenarioStep {
  final String round; // lesbar runde, f.eks. "16-delsfinale"
  final int matchNum;
  final String opponent; // lesbar motstandar-skildring
  const ScenarioStep(this.round, this.matchNum, this.opponent);
}

/// Resultatet av et scenario.
class Scenario {
  final String slotLabel; // f.eks. "vinner av gruppe I"
  final List<ScenarioStep> steps;
  final String? note; // forklaring (f.eks. for 3.plass)
  const Scenario(this.slotLabel, this.steps, {this.note});
}

String _roundNo(String r) {
  switch (r) {
    case 'Round of 32':
      return '16-delsfinale';
    case 'Round of 16':
      return '8-delsfinale';
    case 'Quarter-final':
      return 'Kvartfinale';
    case 'Semi-final':
      return 'Semifinale';
    case 'Final':
      return 'Finale';
    case 'Match for third place':
      return 'Bronsefinale';
    default:
      return r;
  }
}

/// Gjer en plassholdarkode lesbar. [expand] viser de to laga i en W/L-kamp.
String _describeCode(String code, Map<int, MatchInfo> byNum,
    {bool expand = true}) {
  final s = _slotRe.firstMatch(code);
  if (s != null) {
    return s[1] == '1' ? 'vinner av gruppe ${s[2]}' : '2.-plass i gruppe ${s[2]}';
  }
  final third = _thirdGroups(code);
  if (third != null) return '3.-plass (en av ${third.join('/')})';
  final wl = _wlRe.firstMatch(code);
  if (wl != null) {
    final n = int.parse(wl[2]!);
    final verb = wl[1] == 'W' ? 'vinneren' : 'taperen';
    final fm = byNum[n];
    if (expand && fm != null) {
      final a = _describeCode(fm.team1, byNum, expand: false);
      final b = _describeCode(fm.team2, byNum, expand: false);
      return '$verb av kamp $n ($a vs $b)';
    }
    return '$verb av kamp $n';
  }
  return code;
}

/// Reknar ut hvem et lag møter runde for runde i sluttspillet dersom det
/// kjem videre som [placement] (1, 2 eller 3) fra gruppe [group].
/// Følgjer vinner-vegen heilt til finalen (føreset at laget går videre).
Scenario scenarioPath({
  required List<MatchInfo> matches,
  required String group, // 'I'
  required int placement, // 1, 2, 3
}) {
  final ko = matches.where((m) => !m.isGroup).toList()
    ..sort((a, b) => a.num.compareTo(b.num));
  final byNum = {for (final m in ko) m.num: m};
  // nextOf[n] = kampen vinneren av kamp n går videre til.
  final nextOf = <int, int>{};
  for (final m in ko) {
    for (final c in [m.team1, m.team2]) {
      final wl = _wlRe.firstMatch(c);
      if (wl != null && wl[1] == 'W') nextOf[int.parse(wl[2]!)] = m.num;
    }
  }

  if (placement == 3) {
    final steps = <ScenarioStep>[];
    for (final m in ko.where((m) => m.round == 'Round of 32')) {
      for (final c in [m.team1, m.team2]) {
        final g = _thirdGroups(c);
        if (g != null && g.contains(group)) {
          final opp = c == m.team1 ? m.team2 : m.team1;
          steps.add(ScenarioStep(
              _roundNo(m.round), m.num, _describeCode(opp, byNum)));
        }
      }
    }
    return Scenario('3.-plass i gruppe $group', steps,
        note: 'Hvor hver 3.-plass havner avhenger av hvilke andre 3.-plasser som '
            'går videre. Dette er de mulige åpningskampene.');
  }

  final startCode = '$placement$group';
  MatchInfo? start;
  for (final m in ko) {
    if (m.team1 == startCode || m.team2 == startCode) {
      start = m;
      break;
    }
  }
  final slotLabel =
      placement == 1 ? 'vinner av gruppe $group' : '2.-plass i gruppe $group';
  if (start == null) return Scenario(slotLabel, const []);

  final steps = <ScenarioStep>[];
  MatchInfo? cur = start;
  var incoming = startCode;
  while (cur != null) {
    final opp = cur.team1 == incoming ? cur.team2 : cur.team1;
    steps.add(
        ScenarioStep(_roundNo(cur.round), cur.num, _describeCode(opp, byNum)));
    final nx = nextOf[cur.num];
    if (nx == null) break;
    incoming = 'W${cur.num}';
    cur = byNum[nx];
  }
  return Scenario(slotLabel, steps);
}

/// Parsar en 3.plass-kode som "3A/B/C/D/F" til gruppebokstavane den kan ta imot.
/// Returnerer null om koden ikke er en 3.plass-plass.
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

/// Bipartitt maksmatching (Kuhn): tildeler hver plass éi tillaten gruppe.
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

/// Bygg heile sluttspilltreet, runde for runde (R32 først).
/// [winnerSide] gir faktisk vinner-side (1/2) for en spilt kamp, elles null.
/// Bygg sluttspilltreet.
/// - [scoreFor]: kjelda til gruppeplasseringenne. I "Projeksjon"-modus er dette
///   deltakeren sine tippingar; i "Resultat"-modus er det faktiske resultat.
/// - [winnerSide]: faktisk vinner-side (1/2) for en spilt sluttspillkamp.
/// I "Resultat"-modus bør [scoreFor] bare gje resultat for ferdigspilt kamper,
/// slik at treet fyller seg etter hvert som det blir spilt.
List<KoMatch> buildBracket({
  required ScoreFor scoreFor,
  required List<MatchInfo> matches,
  required int? Function(MatchInfo) winnerSide,
  bool requireComplete = false,
  // [project]: fyll treet frå NOVERANDE stilling sjølv om gruppene ikkje er
  // ferdige. Plassar i ferdigspilt grupper vert merkte som avgjorde
  // (projected=false), resten som projiserte (projected=true, "kan endre seg").
  bool project = false,
}) {
  final rich = _richStandings(scoreFor, matches,
      requireComplete: requireComplete && !project);

  // Kva grupper er ferdigspilte (alle kampar har eit resultat)?
  final groupComplete = <String, bool>{};
  {
    final byG = <String, List<MatchInfo>>{};
    for (final m in matches.where((m) => m.isGroup)) {
      byG.putIfAbsent(m.group, () => []).add(m);
    }
    byG.forEach((g, ms) {
      groupComplete[g.replaceFirst('Group ', '')] =
          ms.every((m) => scoreFor(m) != null);
    });
  }
  final allComplete =
      groupComplete.isNotEmpty && groupComplete.values.every((x) => x);
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
  // 1) 3.plass i hver gruppe, med statistikk.
  final thirds = <_GroupRow>[]; // rad
  final thirdGroupOf = <String, String>{}; // lagnavn -> gruppebokstav
  rich.forEach((g, rows) {
    if (rows.length >= 3) {
      final letter = g.replaceFirst('Group ', '');
      thirds.add(rows[2]);
      thirdGroupOf[rows[2].team] = letter;
    }
  });
  // 2) Rangér alle gruppetrearanane og ta de 8 beste.
  thirds.sort(_cmpStanding);
  final qualified = thirds.take(8).toList();
  final teamByGroup = <String, String>{
    for (final r in qualified) thirdGroupOf[r.team]!: r.team,
  };
  final qualGroups = teamByGroup.keys.toSet();
  // 3) Samle 3.plass-plassene i kampnummer-rekkjefølgje.
  final thirdSlots = <String>[]; // kodestrengerar (unike)
  for (final m in ko) {
    for (final code in [m.team1, m.team2]) {
      if (_thirdGroups(code) != null && !thirdSlots.contains(code)) {
        thirdSlots.add(code);
      }
    }
  }
  // 4) Matching som respekterer hva grupper hver plass kan ta imot.
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

  // I "Resultat"-modus resolvar gruppeplassene bare når gruppa er ferdigspilt,
  // så da er de ekte (ikke projiserte). I "Projeksjon"-modus er de tippet.
  final markProjected = !requireComplete;

  KoTeam resolveSlot(String code) {
    // Allereie et ekte lag (gruppespill ferdig / kamp trekt).
    if (groupTeams.contains(code)) return KoTeam(code, code);

    final m = _slotRe.firstMatch(code);
    if (m != null) {
      final pos = m[1]!;
      final letter = m[2]!;
      final tbl = standings['Group $letter'];
      if (tbl != null && tbl.length >= 2) {
        final t = pos == '1' ? tbl[0] : tbl[1];
        final proj = project ? !(groupComplete[letter] ?? false) : markProjected;
        return KoTeam(t, t, projected: proj);
      }
      return KoTeam(null, code);
    }
    if (_thirdGroups(code) != null) {
      final t = thirdSlotToTeam[code];
      if (t != null) {
        final proj = project ? !allComplete : markProjected;
        return KoTeam(t, t, projected: proj);
      }
      return KoTeam(null, '3.plass');
    }
    final wl = _wlRe.firstMatch(code);
    if (wl != null) {
      final isWinner = wl[1] == 'W';
      final n = int.parse(wl[2]!);
      final feeder = resolved[n];
      final fm = byNum[n];
      if (feeder != null && fm != null) {
        final w = winnerSide(fm); // bare kjent når kampen er spilt
        if (w == 1 || w == 2) {
          final advancing = (w == 1) == isWinner ? feeder.home : feeder.away;
          if (advancing.resolved) {
            return KoTeam(advancing.team, advancing.team!);
          }
        }
      }
      return KoTeam(null, isWinner ? 'Vinner K$n' : 'Taper K$n');
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
