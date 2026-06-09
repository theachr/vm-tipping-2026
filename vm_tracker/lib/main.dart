import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bracket.dart';
import 'data.dart';
import 'flags.dart';
import 'models.dart';
import 'scoring.dart';

void main() => runApp(const VmTippingApp());

/// Fargetema å velje mellom. Mørke variantar med dempa aksentar.
class AppTheme {
  final String name;
  final Color seed;
  final Brightness brightness;

  /// Viser regnboge-gradient på toppbanneret (Pride-tema).
  final bool rainbow;
  const AppTheme(this.name, this.seed, this.brightness,
      {this.rainbow = false});
}

/// Klassisk Pride-regnboge (6 striper).
const kPrideColors = <Color>[
  Color(0xFFE40303), // raud
  Color(0xFFFF8C00), // oransje
  Color(0xFFFFED00), // gul
  Color(0xFF008026), // grøn
  Color(0xFF004DFF), // blå
  Color(0xFF750787), // lilla
];

const kThemes = <AppTheme>[
  AppTheme('Rosa natt', Color(0xFFE91E8C), Brightness.dark),
  AppTheme('Stadiongrøn', Color(0xFF2E7D32), Brightness.dark),
  AppTheme('Kveldsnavy', Color(0xFF5C7CFA), Brightness.dark),
  AppTheme('Gull & svart', Color(0xFFFFB300), Brightness.dark),
  AppTheme('Pride natt', Color(0xFF9C27B0), Brightness.dark, rainbow: true),
  AppTheme('Rosa (lys)', Color(0xFFE91E8C), Brightness.light),
  AppTheme('Pride (lys)', Color(0xFF9C27B0), Brightness.light, rainbow: true),
];

/// Vald tema-indeks, lytta på av heile appen og lagra lokalt.
final themeIndex = ValueNotifier<int>(0);
const _themePrefKey = 'theme_index';

Future<void> _loadTheme() async {
  final p = await SharedPreferences.getInstance();
  final i = p.getInt(_themePrefKey);
  if (i != null && i >= 0 && i < kThemes.length) themeIndex.value = i;
}

Future<void> setTheme(int i) async {
  themeIndex.value = i;
  final p = await SharedPreferences.getInstance();
  await p.setInt(_themePrefKey, i);
}

class VmTippingApp extends StatelessWidget {
  const VmTippingApp({super.key});
  @override
  Widget build(BuildContext context) {
    _loadTheme();
    return ValueListenableBuilder<int>(
      valueListenable: themeIndex,
      builder: (context, idx, _) {
        final t = kThemes[idx];
        final scheme = ColorScheme.fromSeed(
          seedColor: t.seed,
          brightness: t.brightness,
        );
        return MaterialApp(
          title: 'VM Tipping 2026',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorScheme: scheme, useMaterial3: true),
          home: const HomePage(),
        );
      },
    );
  }
}

// ---- Delte resultat-hjelparar (resultat er felles for alle deltakarar) ----

/// Faktiske mål [m1, m2] (manuell overstyring vinn over offisielt), eller null.
List<int>? actualResult(MatchInfo m, Overrides ovr) {
  final o = ovr.get(m.num);
  if (o != null) return o;
  if (m.played) return [m.score1!, m.score2!];
  return null;
}

/// 1/2 = vinnar-side, 0 = uavgjort, null = ikkje avgjort. Override-medviten.
int? winnerSideOf(MatchInfo m, Overrides ovr) {
  final o = ovr.get(m.num);
  if (o != null) return o[0] > o[1] ? 1 : (o[1] > o[0] ? 2 : 0);
  return m.winnerSide;
}

Map<String, String?> actualMedals(List<MatchInfo> matches, Overrides ovr) {
  String? gold, silver, bronze;
  for (final m in matches) {
    if (m.round == 'Final') {
      final w = winnerSideOf(m, ovr);
      if (w == 1) {
        gold = m.team1;
        silver = m.team2;
      } else if (w == 2) {
        gold = m.team2;
        silver = m.team1;
      }
    } else if (m.round == 'Match for third place') {
      final w = winnerSideOf(m, ovr);
      if (w == 1) bronze = m.team1;
      if (w == 2) bronze = m.team2;
    }
  }
  return {'gold': gold, 'silver': silver, 'bronze': bronze};
}

const _thStyle = TextStyle(
    fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600);

Color advColor(Advance a) {
  switch (a) {
    case Advance.direct:
      return Colors.green;
    case Advance.thirdIn:
      return const Color(0xFF8BC34A); // lysegrøn
    case Advance.thirdOut:
      return const Color(0xFFF5A623); // oransje
    case Advance.out:
      return Colors.red;
  }
}

String advLabel(TeamStanding r) {
  switch (r.advance) {
    case Advance.direct:
      return 'Vidare';
    case Advance.thirdIn:
      return '3.pl (nr ${r.thirdRank}) → vidare';
    case Advance.thirdOut:
      return '3.pl (nr ${r.thirdRank}) → ute';
    case Advance.out:
      return 'Ute';
  }
}

/// Gjenbrukbart gruppetabell-kort. [showStatus] = vis vidare-status (skru av
/// før gruppa har spelt nokon kampar, så vi ikkje fargar ei tom 0-0-tabell).
class GroupTableCard extends StatelessWidget {
  final List<TeamStanding> rows;
  final bool showStatus;
  const GroupTableCard({super.key, required this.rows, this.showStatus = true});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 22),
                const SizedBox(width: 24),
                const Expanded(child: Text('Lag', style: _thStyle)),
                const SizedBox(
                    width: 34,
                    child:
                        Text('P', textAlign: TextAlign.center, style: _thStyle)),
                const SizedBox(
                    width: 40,
                    child: Text('MF',
                        textAlign: TextAlign.center, style: _thStyle)),
                if (showStatus)
                  const SizedBox(
                      width: 130,
                      child: Text('Status',
                          textAlign: TextAlign.right, style: _thStyle)),
              ],
            ),
            const Divider(height: 10),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: showStatus
                            ? advColor(r.advance)
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Text('${r.rank}',
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                    Text(flagFor(r.team), style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(r.team,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text('${r.pts}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(r.gd >= 0 ? '+${r.gd}' : '${r.gd}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[700])),
                    ),
                    if (showStatus)
                      SizedBox(
                        width: 130,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: advColor(r.advance).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              advLabel(r),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: advColor(r.advance),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Toppnivå-fane: sluttspeloppsettet (felles) ut frå faktiske resultat,
/// med ein scenario-veljar ("kven møter laget vidare").
class KnockoutView extends StatefulWidget {
  final List<MatchInfo> matches;
  final Overrides overrides;
  const KnockoutView(
      {super.key, required this.matches, required this.overrides});

  @override
  State<KnockoutView> createState() => _KnockoutViewState();
}

class _KnockoutViewState extends State<KnockoutView> {
  String? _team;
  int _placement = 1;

  /// Lagnamn -> gruppebokstav (A..L), frå gruppekampane.
  Map<String, String> get _teamGroup {
    final out = <String, String>{};
    for (final m in widget.matches.where((m) => m.isGroup)) {
      final letter = m.group.replaceFirst('Group ', '');
      out[m.team1] = letter;
      out[m.team2] = letter;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final ko = buildBracket(
      scoreFor: _resultScore(widget.overrides),
      matches: widget.matches,
      winnerSide: (m) => winnerSideOf(m, widget.overrides),
      requireComplete: true,
    );
    final medals = actualMedals(widget.matches, widget.overrides);
    final highlight = <String>{
      for (final v in medals.values) ?v,
    };
    return Column(
      children: [
        _scenarioCard(),
        Expanded(
          child: BracketView(
            matches: ko,
            highlight: highlight,
            caption:
                'Sluttspeloppsettet ut frå faktiske resultat (felles for alle). '
                'Plassane (1A, 2B, 3.-arar, vinnar/tapar av kamp) fyller seg med '
                'ekte lag etter kvart som gruppene og sluttspelkampane blir spelte. '
                'Venstre og høgre halvdel møtest i finalen i midten.',
          ),
        ),
      ],
    );
  }

  Widget _scenarioCard() {
    final scheme = Theme.of(context).colorScheme;
    final teamGroup = _teamGroup;
    final teams = teamGroup.keys.toList()..sort();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                const Text('Spør om sluttspelet',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Vel eit lag og kva plassering du tenkjer deg – så viser eg kven '
              'dei møter runde for runde (om dei held fram).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _team,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Lag',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final t in teams)
                        DropdownMenuItem(
                          value: t,
                          child: Text('${flagFor(t)} $t (gr. ${teamGroup[t]})',
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _team = v),
                  ),
                ),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Vinnar')),
                    ButtonSegment(value: 2, label: Text('2.-plass')),
                    ButtonSegment(value: 3, label: Text('3.-plass')),
                  ],
                  selected: {_placement},
                  onSelectionChanged: (s) =>
                      setState(() => _placement = s.first),
                ),
              ],
            ),
            if (_team != null) ...[
              const SizedBox(height: 12),
              _scenarioResult(teamGroup[_team!]!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _scenarioResult(String group) {
    final scheme = Theme.of(context).colorScheme;
    final sc = scenarioPath(
        matches: widget.matches, group: group, placement: _placement);
    if (sc.steps.isEmpty) {
      return Text('Fann ingen sluttspelveg for dette valet.',
          style: TextStyle(color: scheme.outline));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$_team som ${sc.slotLabel} møter:',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        for (final s in sc.steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: '${s.round} ',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(
                        text: '(kamp ${s.matchNum}): ',
                        style: TextStyle(color: scheme.outline)),
                    TextSpan(text: s.opponent),
                  ])),
                ),
              ],
            ),
          ),
        if (sc.note != null) ...[
          const SizedBox(height: 6),
          Text(sc.note!,
              style: TextStyle(
                  fontSize: 12,
                  color: scheme.outline,
                  fontStyle: FontStyle.italic)),
        ],
      ],
    );
  }
}

/// Toppnivå-fane: alle gruppetabellane ut frå faktiske resultat (felles).
class GroupStageView extends StatelessWidget {
  final List<MatchInfo> matches;
  final Overrides overrides;
  const GroupStageView(
      {super.key, required this.matches, required this.overrides});

  @override
  Widget build(BuildContext context) {
    final tables = groupTables(_resultScore(overrides), matches);
    final keys = tables.keys.toList()..sort();
    // Tal spelte gruppekampar per gruppe (for å avgjere om status er meiningsfull).
    final playedByGroup = <String, int>{};
    for (final m in matches.where((m) => m.isGroup)) {
      if (actualResult(m, overrides) != null) {
        playedByGroup[m.group] = (playedByGroup[m.group] ?? 0) + 1;
      }
    }
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(
            'Gruppetabellar ut frå faktiske resultat. Fyller seg etter kvart '
            'som kampane vert spelte. Grøn = 1./2.plass (direkte vidare), '
            'lysegrøn = 3.plass blant dei 8 beste, oransje = 3.plass utanfor, '
            'raud = ute.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        for (final g in keys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(g,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          GroupTableCard(
            rows: tables[g]!,
            showStatus: (playedByGroup[g] ?? 0) > 0,
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---- Medalje-trafikklys --------------------------------------------------
// Vurderer om eit medaljetips framleis er oppnåeleg.
enum MedalFeas { ok, caution, impossible, achieved }

class MedalEval {
  final MedalFeas status;
  final String reason;
  const MedalEval(this.status, this.reason);
}

ScoreFor _tipsScore(Participant p) => (m) => p.forMatch(m.team1, m.team2);
ScoreFor _resultScore(Overrides ovr) => (m) {
      final a = actualResult(m, ovr);
      return a == null ? null : {m.team1: a[0], m.team2: a[1]};
    };

/// Lag som er slått ut i verkelegheita: taparar av spelte sluttspelkampar, og
/// lag som vart sist i ei ferdigspelt gruppe (4.plass kan ikkje gå vidare).
Set<String> _eliminatedTeams(List<MatchInfo> matches, Overrides ovr) {
  final out = <String>{};
  final score = _resultScore(ovr);
  // Sisteplass i ferdigspelte grupper kan ikkje gå vidare.
  final st = standingsFromScore(score, matches, requireComplete: true);
  for (final rows in st.values) {
    if (rows.length == 4) out.add(rows.last);
  }
  // Taparar av spelte sluttspelkampar.
  final ko = buildBracket(
    scoreFor: score,
    matches: matches,
    winnerSide: (m) => winnerSideOf(m, ovr),
    requireComplete: true,
  );
  final byNum = {for (final m in matches) m.num: m};
  for (final km in ko) {
    final mi = byNum[km.num];
    if (mi == null) continue;
    final w = winnerSideOf(mi, ovr);
    final loser = w == 1 ? km.away : (w == 2 ? km.home : null);
    if (loser != null && loser.resolved) out.add(loser.team!);
  }
  return out;
}

/// Per-medalje status for trafikklyset.
Map<String, MedalEval> evalMedals(
    Participant p, List<MatchInfo> matches, Overrides ovr) {
  final picks = p.medals; // gold/silver/bronze -> lagnamn
  final actual = actualMedals(matches, ovr);
  final eliminated = _eliminatedTeams(matches, ovr);

  // Projisert halvdel (frå deltakaren sine tips) for kvar kvalifisert lag.
  final proj = buildBracket(
    scoreFor: _tipsScore(p),
    matches: matches,
    winnerSide: (m) => winnerSideOf(m, ovr),
  );
  final leftR32 = _leftRounds[0].toSet();
  final rightR32 = _rightRounds[0].toSet();
  final halfOf = <String, String>{}; // lagnamn -> 'V'/'H'
  for (final km in proj) {
    final isLeft = leftR32.contains(km.num);
    final isRight = rightR32.contains(km.num);
    if (!isLeft && !isRight) continue;
    final h = isLeft ? 'V' : 'H';
    if (km.home.resolved) halfOf[km.home.team!] = h;
    if (km.away.resolved) halfOf[km.away.team!] = h;
  }
  final qualified = halfOf.keys.toSet();

  final gold = picks['gold'], silver = picks['silver'];
  final sameHalf = gold != null &&
      silver != null &&
      halfOf[gold] != null &&
      halfOf[gold] == halfOf[silver];

  MedalEval eval(String key, String medalLabel, String? finalMedalKey) {
    final team = picks[key];
    if (team == null || team.isEmpty) {
      return const MedalEval(MedalFeas.caution, 'Inkje tips');
    }
    // 1) Allereie avgjord i verkelegheita?
    final decided = actual[finalMedalKey];
    if (decided != null) {
      return decided == team
          ? MedalEval(MedalFeas.achieved, 'Oppnådd – $medalLabel sikra')
          : MedalEval(MedalFeas.impossible, '$medalLabel gjekk til $decided');
    }
    // 2) Slått ut?
    if (eliminated.contains(team)) {
      return MedalEval(MedalFeas.impossible, '$team er alt ute');
    }
    // 3) Duplikat?
    final others = [
      for (final e in picks.entries)
        if (e.key != key) e.value
    ];
    if (others.contains(team)) {
      return const MedalEval(
          MedalFeas.impossible, 'Same lag er tippa på fleire medaljar');
    }
    // 4) Kvalifiserer laget i deltakaren si eiga projeksjon?
    if (!qualified.contains(team)) {
      return MedalEval(MedalFeas.caution,
          'Mogleg, men dine tips har $team ute av gruppespelet');
    }
    // 5) Gull/sølv på same halvdel (møtest før finalen) i eigne tips?
    if ((key == 'gold' || key == 'silver') && sameHalf) {
      return const MedalEval(MedalFeas.caution,
          'Gull og sølv hamnar på same halvdel i dine tips – dei møtest før finalen');
    }
    return const MedalEval(MedalFeas.ok, 'Mogleg og i tråd med dine tips');
  }

  return {
    'gold': eval('gold', 'Gull', 'gold'),
    'silver': eval('silver', 'Sølv', 'silver'),
    'bronze': eval('bronze', 'Bronse', 'bronze'),
  };
}

int matchPointsFor(Participant p, MatchInfo m, Overrides ovr) {
  final pred = p.forMatch(m.team1, m.team2);
  final act = actualResult(m, ovr);
  if (pred == null || act == null) return 0;
  return matchPoints(
    pred1: pred[m.team1]!,
    pred2: pred[m.team2]!,
    act1: act[0],
    act2: act[1],
  );
}

class Standing {
  final Participant p;
  final int group, medal, played;
  const Standing(this.p, this.group, this.medal, this.played);
  int get total => group + medal;
}

Standing standingFor(Participant p, List<MatchInfo> matches, Overrides ovr) {
  var group = 0, played = 0;
  for (final m in matches.where((m) => m.isGroup)) {
    final pred = p.forMatch(m.team1, m.team2);
    final act = actualResult(m, ovr);
    if (pred != null && act != null) {
      played++;
      group += matchPoints(
        pred1: pred[m.team1]!,
        pred2: pred[m.team2]!,
        act1: act[0],
        act2: act[1],
      );
    }
  }
  final medal = medalPoints(p.medals, actualMedals(matches, ovr));
  return Standing(p, group, medal, played);
}

// ---- Startskjerm: resultattavle ----

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Participant> _participants = [];
  Overrides? _ovr;
  List<MatchInfo> _matches = [];
  bool _loading = true;
  String? _error;
  int _navIndex = 0;

  /// Namn på deltakarar som er skjult i visninga (lagra lokalt).
  Set<String> _hidden = {};
  static const _hiddenPrefKey = 'hidden_participants';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final participants = await Participant.loadAll();
      final ovr = await Overrides.load();
      final matches = await fetchMatches();
      final prefs = await SharedPreferences.getInstance();
      final hidden = prefs.getStringList(_hiddenPrefKey)?.toSet() ?? <String>{};
      setState(() {
        _participants = participants;
        _ovr = ovr;
        _matches = matches;
        _hidden = hidden;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Deltakarane som faktisk skal visast (filteret teke med).
  List<Participant> get _visible =>
      _participants.where((p) => !_hidden.contains(p.name)).toList();

  Future<void> _setHidden(Set<String> hidden) async {
    setState(() => _hidden = hidden);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenPrefKey, hidden.toList());
  }

  /// Dialog med avkryssing for kvar deltakar.
  void _openFilter() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        // Lokal kopi som vi redigerer i dialogen.
        final hidden = {..._hidden};
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Vis deltakarar'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final p in _participants)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.name),
                        value: !hidden.contains(p.name),
                        onChanged: (v) => setLocal(() {
                          if (v == true) {
                            hidden.remove(p.name);
                          } else {
                            hidden.add(p.name);
                          }
                        }),
                      ),
                    const Divider(),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setLocal(hidden.clear),
                          child: const Text('Vis alle'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Avbryt'),
                ),
                FilledButton(
                  onPressed: () {
                    _setHidden(hidden);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Bruk'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  int get _playedGroupMatches =>
      _matches.where((m) => m.isGroup && actualResult(m, _ovr!) != null).length;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('VM Tipping 2026')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 12),
                Text('Klarte ikkje hente data:\n$_error',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Prøv igjen'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final standings = _visible
        .map((p) => standingFor(p, _matches, _ovr!))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return Scaffold(
      appBar: AppBar(
        title: const Text('VM Tipping 2026'),
        actions: [
          IconButton(
            tooltip: 'Filtrer deltakarar',
            onPressed: _openFilter,
            icon: Icon(_hidden.isEmpty
                ? Icons.filter_list
                : Icons.filter_list_alt),
          ),
          PopupMenuButton<int>(
            tooltip: 'Bytt tema',
            icon: const Icon(Icons.palette_outlined),
            initialValue: themeIndex.value,
            onSelected: setTheme,
            itemBuilder: (context) => [
              for (var i = 0; i < kThemes.length; i++)
                PopupMenuItem(
                  value: i,
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: kThemes[i].rainbow ? null : kThemes[i].seed,
                          gradient: kThemes[i].rainbow
                              ? const LinearGradient(colors: kPrideColors)
                              : null,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black26),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(kThemes[i].name),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Oppdater resultat',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final content = _navIndex == 0
              ? _scoreboard(standings)
              : _navIndex == 1
                  ? GroupStageView(matches: _matches, overrides: _ovr!)
                  : _navIndex == 2
                      ? UpcomingMatchesView(
                          matches: _matches,
                          participants: _visible,
                          overrides: _ovr!,
                        )
                      : KnockoutView(matches: _matches, overrides: _ovr!);

          // Smal skjerm (mobil): innhald i full breidde, meny kjem
          // som botnmeny under (sjå bottomNavigationBar).
          if (constraints.maxWidth < 600) return content;

          // Brei skjerm (mac/web): fast sidemeny til venstre.
          return Row(
            children: [
              NavigationRail(
                extended: constraints.maxWidth >= 760,
                minExtendedWidth: 168,
                selectedIndex: _navIndex,
                onDestinationSelected: (i) => setState(() => _navIndex = i),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.leaderboard_outlined),
                    selectedIcon: Icon(Icons.leaderboard),
                    label: Text('Tavle'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.table_chart_outlined),
                    selectedIcon: Icon(Icons.table_chart),
                    label: Text('Gruppespill'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.event_outlined),
                    selectedIcon: Icon(Icons.event),
                    label: Text('Kampar'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.account_tree_outlined),
                    selectedIcon: Icon(Icons.account_tree),
                    label: Text('Sluttspill'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          );
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 600
          ? NavigationBar(
              selectedIndex: _navIndex,
              onDestinationSelected: (i) => setState(() => _navIndex = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.leaderboard_outlined),
                  selectedIcon: Icon(Icons.leaderboard),
                  label: 'Tavle',
                ),
                NavigationDestination(
                  icon: Icon(Icons.table_chart_outlined),
                  selectedIcon: Icon(Icons.table_chart),
                  label: 'Gruppespill',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event),
                  label: 'Kampar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_tree_outlined),
                  selectedIcon: Icon(Icons.account_tree),
                  label: 'Sluttspill',
                ),
              ],
            )
          : null,
    );
  }

  Widget _scoreboard(List<Standing> standings) {
    final scheme = Theme.of(context).colorScheme;
    final pride = kThemes[themeIndex.value].rainbow;

    // Pride: kvit tekst med skugge så han les på alle regnbogefargane.
    // Elles: vanleg primærfarge.
    final headerFg = pride ? Colors.white : scheme.onPrimaryContainer;
    final shadows = pride
        ? const [Shadow(blurRadius: 4, color: Colors.black54)]
        : const <Shadow>[];

    return ListView(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: pride ? null : scheme.primaryContainer,
            gradient: pride
                ? const LinearGradient(
                    colors: kPrideColors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
          ),
          child: Column(
            children: [
              Icon(Icons.emoji_events,
                  size: 36, color: headerFg, shadows: shadows),
              const SizedBox(height: 4),
              Text('Resultattavle',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: headerFg,
                      shadows: shadows)),
              Text('$_playedGroupMatches av 72 gruppekampar spelt',
                  style: TextStyle(color: headerFg, shadows: shadows)),
            ],
          ),
        ),
        for (var i = 0; i < standings.length; i++)
          _standingTile(standings[i], i + 1),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _standingTile(Standing s, int rank) {
    final medalColor = switch (rank) {
      1 => const Color(0xFFFFC107),
      2 => const Color(0xFFB0BEC5),
      3 => const Color(0xFFCD7F32),
      _ => Colors.transparent,
    };
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            rank <= 3 ? medalColor : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text('$rank',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      title: Text(s.p.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('Gruppe: ${s.group} · Medaljar: ${s.medal} · ${s.played} kampar talt'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${s.total}',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(width: 2),
          const Text('p'),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ParticipantPage(
              participant: s.p,
              matches: _matches,
              overrides: _ovr!,
            ),
          ),
        );
        if (mounted) setState(() {}); // overstyringar kan ha endra seg
      },
    );
  }
}

// ---- Kommande kampar (kronologisk, med alle sine tips) ----

const _months = [
  '', 'jan', 'feb', 'mars', 'april', 'mai', 'juni',
  'juli', 'aug', 'sep', 'okt', 'nov', 'des'
];

/// "2026-06-11" -> "11. juni". Fell tilbake til rådata om uventa format.
String _prettyDate(String iso) {
  final parts = iso.split('-');
  if (parts.length == 3) {
    final mo = int.tryParse(parts[1]);
    final da = int.tryParse(parts[2]);
    if (mo != null && da != null && mo >= 1 && mo <= 12) {
      return '$da. ${_months[mo]}';
    }
  }
  return iso;
}

// openfootball lagrar tid som "HH:mm UTC±N" (spelstaden si lokaltid).
final _timeRe = RegExp(r'^(\d{1,2}):(\d{2})\s*UTC([+-]\d{1,2})$');

// Noreg er på sommartid (CEST = UTC+2) heile VM-vindauget (11. juni–19. juli),
// så vi kan bruke ein fast offset.
const _osloOffset = 2;

/// Kamptidspunktet i norsk tid, eller null om tid/dato ikkje kan tolkast.
DateTime? _osloDateTime(MatchInfo m) {
  final t = _timeRe.firstMatch(m.time.trim());
  final d = m.date.split('-');
  if (t == null || d.length != 3) return null;
  final y = int.tryParse(d[0]),
      mo = int.tryParse(d[1]),
      da = int.tryParse(d[2]);
  final hh = int.parse(t[1]!), mm = int.parse(t[2]!), off = int.parse(t[3]!);
  if (y == null || mo == null || da == null) return null;
  // Lokal veggklokke -> UTC -> Oslo.
  final utc = DateTime.utc(y, mo, da, hh, mm).subtract(Duration(hours: off));
  return utc.add(const Duration(hours: _osloOffset));
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Klokkeslett i norsk tid ("21:00"), elles rå tid som fallback.
String _osloTime(MatchInfo m) {
  final dt = _osloDateTime(m);
  if (dt == null) return m.time;
  return '${_two(dt.hour)}:${_two(dt.minute)}';
}

/// Dato (ISO) i norsk tid – kan rulle over til neste dag for seine kampar.
String _osloDateIso(MatchInfo m) {
  final dt = _osloDateTime(m);
  if (dt == null) return m.date;
  return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
}

/// Sorteringsnøkkel: faktisk tidspunkt (UTC-instans), elles rå streng.
String _sortKey(MatchInfo m) {
  final dt = _osloDateTime(m);
  if (dt == null) return '${m.date} ${m.time}';
  return dt.toIso8601String();
}

class UpcomingMatchesView extends StatefulWidget {
  final List<MatchInfo> matches;
  final List<Participant> participants;
  final Overrides overrides;
  const UpcomingMatchesView({
    super.key,
    required this.matches,
    required this.participants,
    required this.overrides,
  });

  @override
  State<UpcomingMatchesView> createState() => _UpcomingMatchesViewState();
}

enum _MatchFilter { upcoming, nextPerGroup, all }

class _UpcomingMatchesViewState extends State<UpcomingMatchesView> {
  _MatchFilter _filter = _MatchFilter.upcoming;

  @override
  Widget build(BuildContext context) {
    final ovr = widget.overrides;
    final all = [...widget.matches]
      ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));

    Widget body;
    if (_filter == _MatchFilter.nextPerGroup) {
      body = _nextPerGroupList(all, ovr);
    } else {
      final shown = _filter == _MatchFilter.upcoming
          ? all.where((m) => actualResult(m, ovr) == null).toList()
          : all;
      body = shown.isEmpty
          ? const Center(child: Text('Ingen kampar å vise.'))
          : ListView(children: _groupedByDay(shown));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<_MatchFilter>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: _MatchFilter.upcoming, label: Text('Kommande')),
              ButtonSegment(
                  value: _MatchFilter.nextPerGroup,
                  label: Text('Neste pr. gruppe')),
              ButtonSegment(value: _MatchFilter.all, label: Text('Alle')),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  /// Dei neste (inntil 2) uspelte kampane i kvar gruppe, under gruppe-overskrift.
  Widget _nextPerGroupList(List<MatchInfo> all, Overrides ovr) {
    final byGroup = <String, List<MatchInfo>>{};
    for (final m in all) {
      if (m.isGroup && actualResult(m, ovr) == null) {
        byGroup.putIfAbsent(m.group, () => []).add(m);
      }
    }
    final keys = byGroup.keys.toList()..sort();
    if (keys.isEmpty) {
      return const Center(child: Text('Ingen kommande gruppekampar.'));
    }
    final out = <Widget>[];
    final scheme = Theme.of(context).colorScheme;
    for (final g in keys) {
      final next = byGroup[g]!.take(2).toList(); // all er alt sortert
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 4),
        child: Row(
          children: [
            Icon(Icons.table_chart_outlined, size: 15, color: scheme.primary),
            const SizedBox(width: 8),
            Text(g.replaceFirst('Group', 'Gruppe'),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                    fontSize: 15)),
            const SizedBox(width: 10),
            Expanded(
                child: Divider(color: scheme.primary.withValues(alpha: 0.4))),
          ],
        ),
      ));
      for (final m in next) {
        out.add(_matchTile(m));
      }
    }
    out.add(const SizedBox(height: 16));
    return ListView(children: out);
  }

  /// Byggjer lista med ein dato-skiljelinje ("ny dag") føre kvar nye dag.
  List<Widget> _groupedByDay(List<MatchInfo> shown) {
    final out = <Widget>[];
    String? lastDate;
    for (final m in shown) {
      final day = _osloDateIso(m);
      if (day != lastDate) {
        lastDate = day;
        final sameDay = shown.where((x) => _osloDateIso(x) == day).length;
        out.add(_dayHeader(day, sameDay));
      }
      out.add(_matchTile(m));
    }
    out.add(const SizedBox(height: 16));
    return out;
  }

  Widget _dayHeader(String iso, int count) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 6),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 15, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            _prettyDate(iso),
            style: TextStyle(
                fontWeight: FontWeight.bold, color: scheme.primary, fontSize: 15),
          ),
          const SizedBox(width: 8),
          Text('$count ${count == 1 ? 'kamp' : 'kampar'}',
              style: TextStyle(color: scheme.outline, fontSize: 12)),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: scheme.primary.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _matchTile(MatchInfo m) {
    final scheme = Theme.of(context).colorScheme;
    final act = actualResult(m, widget.overrides);
    final label = m.isGroup ? m.group.replaceFirst('Group', 'Gruppe') : m.round;

    // Kven har tippa på denne kampen?
    final tippers = <Participant>[
      for (final p in widget.participants)
        if (p.forMatch(m.team1, m.team2) != null) p
    ];

    Widget trailing;
    if (act != null) {
      trailing = Text('${act[0]}–${act[1]}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
    } else {
      trailing = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_osloTime(m),
              style: TextStyle(
                  color: scheme.outline, fontWeight: FontWeight.w600)),
          const Text('norsk tid', style: TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        title: Text(
          '${flagFor(m.team1)} ${m.team1}  –  ${flagFor(m.team2)} ${m.team2}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(label),
        ),
        trailing: trailing,
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          if (m.isGroup) ..._groupTableSection(m),
          if (tippers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                m.isGroup
                    ? 'Ingen har tippa denne kampen enno.'
                    : 'Sluttspelkampar blir ikkje tippa på resultat.',
                style: TextStyle(
                    color: scheme.outline, fontStyle: FontStyle.italic),
              ),
            )
          else
            for (final p in tippers) _tipRow(p, m, act),
        ],
      ),
    );
  }

  /// Gruppetabell (faktiske resultat) for gruppa kampen høyrer til.
  List<Widget> _groupTableSection(MatchInfo m) {
    final tables = groupTables(_resultScore(widget.overrides), widget.matches);
    final rows = tables[m.group];
    if (rows == null) return const [];
    final played = widget.matches
        .where((x) => x.group == m.group && actualResult(x, widget.overrides) != null)
        .length;
    return [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Tabell · ${m.group.replaceFirst('Group', 'Gruppe')}',
              style: _thStyle),
        ),
      ),
      GroupTableCard(rows: rows, showStatus: played > 0),
      const SizedBox(height: 6),
    ];
  }

  Widget _tipRow(Participant p, MatchInfo m, List<int>? act) {
    final scheme = Theme.of(context).colorScheme;
    final pred = p.forMatch(m.team1, m.team2)!;
    final tip = '${pred[m.team1]}–${pred[m.team2]}';

    Color? bg;
    String? badge;
    if (act != null) {
      final pts = matchPointsFor(p, m, widget.overrides);
      if (pts == 3) {
        bg = Colors.green.withValues(alpha: 0.18);
        badge = '3p';
      } else if (pts == 1) {
        bg = Colors.amber.withValues(alpha: 0.20);
        badge = '1p';
      } else {
        badge = '0p';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(p.name)),
          Text(tip, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Text(badge,
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.outline,
                    fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }
}

// ---- Detaljside for éin deltakar ----

class ParticipantPage extends StatefulWidget {
  final Participant participant;
  final List<MatchInfo> matches;
  final Overrides overrides;
  const ParticipantPage({
    super.key,
    required this.participant,
    required this.matches,
    required this.overrides,
  });
  @override
  State<ParticipantPage> createState() => _ParticipantPageState();
}

class _ParticipantPageState extends State<ParticipantPage> {
  Participant get _p => widget.participant;
  Overrides get _ovr => widget.overrides;
  List<MatchInfo> get _matches => widget.matches;

  // Sluttspeltre-modus: true = faktiske resultat, false = denne deltakaren si
  // projeksjon (tipping). Treet skal i utgangspunktet vise resultata.
  bool _bracketResults = true;

  // Gruppetabell-modus: same logikk – tabellen viser resultata som standard.
  bool _groupResults = true;

  Standing get _standing => standingFor(_p, _matches, _ovr);

  @override
  Widget build(BuildContext context) {
    final s = _standing;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_p.name),
          bottom: const TabBar(tabs: [
            Tab(text: 'Gruppespill'),
            Tab(text: 'Sluttspeltre'),
            Tab(text: 'Medaljar'),
          ]),
        ),
        body: Column(
          children: [
            _ScoreHeader(group: s.group, medal: s.medal, played: s.played),
            Expanded(
              child: TabBarView(
                  children: [_groupTab(), _bracketTab(), _medalTab()]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bracketTab() {
    final ko = buildBracket(
      scoreFor: _bracketResults
          ? (m) {
              final a = actualResult(m, _ovr);
              return a == null ? null : {m.team1: a[0], m.team2: a[1]};
            }
          : (m) => _p.forMatch(m.team1, m.team2),
      matches: _matches,
      winnerSide: (m) => winnerSideOf(m, _ovr),
      requireComplete: _bracketResults,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Resultat'),
                    icon: Icon(Icons.sports_soccer),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Projeksjon'),
                    icon: Icon(Icons.insights),
                  ),
                ],
                selected: {_bracketResults},
                onSelectionChanged: (s) =>
                    setState(() => _bracketResults = s.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _bracketResults
                      ? 'Faktiske resultat. Plassane fyller seg etter kvart '
                          'som gruppene og kampane vert ferdigspelte.'
                      : '${_p.name} si projeksjon ut frå tippingane.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: BracketView(
            matches: ko,
            highlight: _p.medals.values.toSet(),
            caption: _bracketResults
                ? 'Sluttspeltreet ut frå faktiske resultat. Medaljetipsa dine '
                    'er utheva. Venstre og høgre halvdel møtest i finalen i '
                    'midten; ekte lag fyller inn etter kvart.'
                : '${_p.name} si projeksjon ut frå tippingane. Medaljetipsa '
                    'er utheva. Venstre og høgre halvdel møtest i finalen i midten.',
          ),
        ),
      ],
    );
  }

  Widget _medalTab() {
    final actual = actualMedals(_matches, _ovr);
    final feas = evalMedals(_p, _matches, _ovr);
    return ListView(
      children: [
        _MedalCard(
          picks: _p.medals,
          actual: actual,
          feas: feas,
          points: medalPoints(_p.medals, actual),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            'Fargeprikk = om medaljen framleis går an:\n'
            '🟢 grøn = mogleg og i tråd med dine tips\n'
            '🟡 gul = mogleg, men dine tips gjev ein konflikt (t.d. gull og '
            'sølv på same halvdel – då møtest dei før finalen)\n'
            '🔴 raud = umogleg (laget er alt ute, eller medaljen er avgjord).\n'
            'Hald peikaren over prikken for forklaring.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Text(
            'Hugs: gull og sølv må kome frå kvar si halvdel av treet '
            '(dei møtest i finalen). Bronse er vinnaren av bronsefinalen '
            '(taparen av ein semifinale). Sjå «Sluttspeltre» for kven som '
            'kan møte kven.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _groupTab() {
    final groups = <String, List<MatchInfo>>{};
    for (final m in _matches.where((m) => m.isGroup)) {
      groups.putIfAbsent(m.group, () => []).add(m);
    }
    final keys = groups.keys.toList()..sort();
    // Resultat-modus: faktiske resultat (felles). Projeksjon: dine tips.
    final tables = _groupResults
        ? groupTables(_resultScore(_ovr), _matches)
        : groupTables(_tipsScore(_p), _matches);
    // Tal spelte gruppekampar per gruppe (for status-fargen i Resultat-modus).
    final playedByGroup = <String, int>{};
    for (final m in _matches.where((m) => m.isGroup)) {
      if (actualResult(m, _ovr) != null) {
        playedByGroup[m.group] = (playedByGroup[m.group] ?? 0) + 1;
      }
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: true,
                      label: Text('Resultat'),
                      icon: Icon(Icons.sports_soccer)),
                  ButtonSegment(
                      value: false,
                      label: Text('Projeksjon'),
                      icon: Icon(Icons.insights)),
                ],
                selected: {_groupResults},
                onSelectionChanged: (s) =>
                    setState(() => _groupResults = s.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _groupResults
                      ? 'Faktiske resultat. Poenga fyller seg etter kvart som '
                          'kampane vert spelte.'
                      : '${_p.name} si projeksjon ut frå tippingane.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        for (final g in keys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(g,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (tables[g] != null)
            GroupTableCard(
              rows: tables[g]!,
              showStatus: _groupResults ? (playedByGroup[g] ?? 0) > 0 : true,
            ),
          for (final m in groups[g]!) _matchTile(m),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _matchTile(MatchInfo m) {
    final pred = _p.forMatch(m.team1, m.team2);
    final act = actualResult(m, _ovr);
    final pts = matchPointsFor(_p, m, _ovr);
    final overridden = _ovr.get(m.num) != null;
    final predStr = pred == null ? '–' : '${pred[m.team1]}–${pred[m.team2]}';
    final actStr = act == null ? 'ikkje spelt' : '${act[0]}–${act[1]}';

    return ListTile(
      dense: true,
      title: Text(
          '${flagFor(m.team1)} ${m.team1}  –  ${flagFor(m.team2)} ${m.team2}'),
      subtitle: Text('${_prettyDate(_osloDateIso(m))} ${_osloTime(m)} · ${m.ground}'
          '${overridden ? ' · (manuelt)' : ''}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Tips: $predStr',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Fasit: $actStr',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          const SizedBox(width: 10),
          _PointsBadge(points: pts, hasResult: act != null),
          IconButton(
            tooltip: 'Overstyr resultat',
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () => _editOverride(m),
          ),
        ],
      ),
    );
  }

  Future<void> _editOverride(MatchInfo m) async {
    final existing = _ovr.get(m.num);
    final c1 = TextEditingController(text: existing?[0].toString() ?? '');
    final c2 = TextEditingController(text: existing?[1].toString() ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${m.team1} – ${m.team2}'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              child: TextField(
                controller: c1,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Heime'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('–'),
            ),
            SizedBox(
              width: 56,
              child: TextField(
                controller: c2,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Borte'),
              ),
            ),
          ],
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'clear'),
              child: const Text('Fjern overstyring'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Lagre'),
          ),
        ],
      ),
    );
    if (result == 'save') {
      final a = int.tryParse(c1.text);
      final b = int.tryParse(c2.text);
      if (a != null && b != null) {
        await _ovr.set(m.num, a, b);
        setState(() {});
      }
    } else if (result == 'clear') {
      await _ovr.clear(m.num);
      setState(() {});
    }
  }
}

class _ScoreHeader extends StatelessWidget {
  final int group, medal, played;
  const _ScoreHeader(
      {required this.group, required this.medal, required this.played});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.primaryContainer,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text('${group + medal}',
              style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer)),
          Text('poeng totalt',
              style: TextStyle(color: scheme.onPrimaryContainer)),
          const SizedBox(height: 4),
          Text(
            'Gruppespel: $group · Medaljar: $medal · $played kampar talt',
            style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PointsBadge extends StatelessWidget {
  final int points;
  final bool hasResult;
  const _PointsBadge({required this.points, required this.hasResult});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color bg;
    if (!hasResult) {
      bg = Colors.grey.shade300;
    } else if (points == 3) {
      bg = Colors.green.shade400;
    } else if (points == 1) {
      bg = Colors.amber.shade400;
    } else {
      bg = Colors.red.shade200;
    }
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(hasResult ? '$points' : '–',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: scheme.onSurface)),
    );
  }
}

class _MedalCard extends StatelessWidget {
  final Map<String, String> picks;
  final Map<String, String?> actual;
  final Map<String, MedalEval> feas;
  final int points;
  const _MedalCard(
      {required this.picks,
      required this.actual,
      required this.feas,
      required this.points});

  static Color _dotColor(MedalFeas s) {
    switch (s) {
      case MedalFeas.ok:
      case MedalFeas.achieved:
        return Colors.green;
      case MedalFeas.caution:
        return const Color(0xFFF5A623); // gul/oransje
      case MedalFeas.impossible:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget row(String emoji, String place, String key) {
      final pick = picks[key] ?? '';
      final act = actual[key];
      final correct = act != null && act == pick;
      final ev = feas[key];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            if (ev != null)
              Tooltip(
                message: ev.reason,
                child: Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _dotColor(ev.status),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(child: Text('$place: $pick')),
            Text(
              act == null ? 'venter' : (correct ? '✓ $act' : '✗ $act'),
              style: TextStyle(
                color: act == null
                    ? Colors.grey
                    : (correct ? Colors.green : Colors.red),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Medaljetips',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('$points poeng',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            row('🥇', 'Gull', 'gold'),
            row('🥈', 'Sølv', 'silver'),
            row('🥉', 'Bronse', 'bronze'),
          ],
        ),
      ),
    );
  }
}

// ---- Sluttspeltre (to-sidig: venstre + høgre møtest i finalen i midten) ----

const double _cardW = 190;
const double _cardH = 64;
const double _vGap = 14;
const double _colGap = 52;
const double _leftPad = 24;
const double _topPad = 56;
const double _titleH = 18; // høgd til tittel over eit kort

// Venstre halvdel (veks mot høgre): R32 -> R16 -> QF -> SF.
const _leftRounds = <List<int>>[
  [74, 77, 73, 75, 83, 84, 81, 82],
  [89, 90, 93, 94],
  [97, 98],
  [101],
];
// Høgre halvdel (veks mot venstre, spegla).
const _rightRounds = <List<int>>[
  [76, 78, 79, 80, 86, 88, 85, 87],
  [91, 92, 95, 96],
  [99, 100],
  [102],
];
const _finalNum = 104;
const _thirdNum = 103;
const _finalCol = 4; // midtkolonne
const _roundTitles = ['32-del', '16-del', 'Kvartfinale', 'Semifinale'];

double _colX(int col) => _leftPad + col * (_cardW + _colGap);
int _leftCol(int r) => r; // 0..3
int _rightCol(int r) => 8 - r; // 8..5

/// Vertikale senter per runde for ei halvdel med [leaf] kort i fyrste runde.
List<List<double>> _mkCenters(int leaf) {
  final c = <List<double>>[];
  c.add([for (var i = 0; i < leaf; i++) _topPad + _cardH / 2 + i * (_cardH + _vGap)]);
  for (var r = 1; r < 4; r++) {
    final prev = c[r - 1];
    c.add([for (var k = 0; k < prev.length ~/ 2; k++) (prev[2 * k] + prev[2 * k + 1]) / 2]);
  }
  return c;
}

class BracketView extends StatelessWidget {
  final List<KoMatch> matches;
  final Set<String> highlight;
  final String? caption;
  const BracketView(
      {super.key, required this.matches, required this.highlight, this.caption});

  @override
  Widget build(BuildContext context) {
    final byNum = {for (final m in matches) m.num: m};
    final scheme = Theme.of(context).colorScheme;

    final lc = _mkCenters(8); // venstre
    final rc = _mkCenters(8); // høgre
    final midY = lc[3][0]; // == rc[3][0]: midten der finalen står

    final totalH = _topPad + 8 * (_cardH + _vGap) + 40;
    final totalW = _colX(8) + _cardW + _leftPad;

    final cards = <Widget>[];
    void place(int col, double centerY, KoMatch? km, {String? title}) {
      if (km == null) return;
      cards.add(Positioned(
        left: _colX(col),
        top: centerY - _cardH / 2 - (title != null ? _titleH : 0),
        child: _MatchCard(km: km, highlight: highlight, title: title),
      ));
    }

    for (var r = 0; r < 4; r++) {
      for (var k = 0; k < _leftRounds[r].length; k++) {
        place(_leftCol(r), lc[r][k], byNum[_leftRounds[r][k]]);
      }
      for (var k = 0; k < _rightRounds[r].length; k++) {
        place(_rightCol(r), rc[r][k], byNum[_rightRounds[r][k]]);
      }
    }
    place(_finalCol, midY, byNum[_finalNum], title: '🏆 Finale');

    // Bronsefinale rett under finalen, i midten.
    final third = byNum[_thirdNum];
    if (third != null) {
      cards.add(Positioned(
        left: _colX(_finalCol),
        top: midY + _cardH / 2 + 30,
        child: _MatchCard(km: third, highlight: highlight, title: '🥉 Bronsefinale'),
      ));
    }

    // Rundetitlar på begge sider + finale i midten.
    Widget hdr(int col, String text) => Positioned(
          left: _colX(col),
          top: 12,
          width: _cardW,
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        );
    final headers = <Widget>[
      for (var r = 0; r < 4; r++) ...[
        hdr(_leftCol(r), _roundTitles[r]),
        hdr(_rightCol(r), _roundTitles[r]),
      ],
      hdr(_finalCol, 'Finale'),
    ];

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: scheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            caption ??
                'Venstre og høgre halvdel møtest i finalen i midten. '
                    'Dra/scroll for å sjå heile treet; ekte lag fyller inn '
                    'etter kvart som kampane blir spelt.',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalW,
                height: totalH,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ConnectorPainter(lc, rc, midY, scheme.outlineVariant),
                      ),
                    ),
                    ...headers,
                    ...cards,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  final KoMatch km;
  final Set<String> highlight;
  final String? title;
  const _MatchCard({required this.km, required this.highlight, this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget teamRow(KoTeam t) {
      final hot = t.team != null && highlight.contains(t.team);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: hot ? scheme.primaryContainer : null,
        child: Row(
          children: [
            Text(t.resolved ? flagFor(t.team!) : '·',
                style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                t.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: hot ? FontWeight.bold : FontWeight.w500,
                  fontStyle: t.resolved ? FontStyle.normal : FontStyle.italic,
                  color: t.resolved
                      ? (hot ? scheme.onPrimaryContainer : scheme.onSurface)
                      : scheme.outline,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(title!,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        Container(
          width: _cardW,
          height: _cardH,
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(child: teamRow(km.home)),
              Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
              Expanded(child: teamRow(km.away)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final List<List<double>> lc, rc; // venstre/høgre senter per runde
  final double midY;
  final Color color;
  _ConnectorPainter(this.lc, this.rc, this.midY, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Eit «merge»: to kort i ytre kolonne -> eitt i indre kolonne.
    // [outerEdge] = kanten på ytre kort som vender innover,
    // [innerEdge] = kanten på indre kort som vender utover.
    void merge(double outerEdge, double innerEdge, List<double> outer,
        List<double> inner) {
      final midX = (outerEdge + innerEdge) / 2;
      for (var k = 0; k < inner.length; k++) {
        final yTop = outer[2 * k], yBot = outer[2 * k + 1], yCur = inner[k];
        canvas.drawLine(Offset(outerEdge, yTop), Offset(midX, yTop), paint);
        canvas.drawLine(Offset(outerEdge, yBot), Offset(midX, yBot), paint);
        canvas.drawLine(Offset(midX, yTop), Offset(midX, yBot), paint);
        canvas.drawLine(Offset(midX, yCur), Offset(innerEdge, yCur), paint);
      }
    }

    for (var r = 1; r < 4; r++) {
      // Venstre: ytre kolonne r-1 (høgrekant) -> indre kolonne r (venstrekant).
      merge(_colX(r - 1) + _cardW, _colX(r), lc[r - 1], lc[r]);
      // Høgre: ytre kolonne 8-(r-1) (venstrekant) -> indre 8-r (høgrekant).
      merge(_colX(8 - (r - 1)), _colX(8 - r) + _cardW, rc[r - 1], rc[r]);
    }

    // Semifinalane inn til finalen i midten.
    canvas.drawLine(Offset(_colX(3) + _cardW, midY), Offset(_colX(4), midY), paint);
    canvas.drawLine(Offset(_colX(5), midY), Offset(_colX(4) + _cardW, midY), paint);
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) =>
      old.lc != lc || old.rc != rc || old.midY != midY || old.color != color;
}
