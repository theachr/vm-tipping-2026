import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bracket.dart';
import 'data.dart';
import 'flags.dart';
import 'live.dart';
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

  /// Brutalistisk stil: skarpe hjørne, tjukke svarte kantar, ingen skuggar,
  /// monospace-font, papirkvit bakgrunn med en hard aksentfarge.
  final bool brutalist;

  /// Skalering av all tekst (1.0 = normal, 2.0 = dobbel).
  final double textScale;
  const AppTheme(this.name, this.seed, this.brightness,
      {this.rainbow = false, this.brutalist = false, this.textScale = 1.0});
}

/// Klassisk Pride-regnboge (6 striper).
const kPrideColors = <Color>[
  Color(0xFFE40303), // rød
  Color(0xFFFF8C00), // oransje
  Color(0xFFFFED00), // gul
  Color(0xFF008026), // grønn
  Color(0xFF004DFF), // blå
  Color(0xFF750787), // lilla
];

const kThemes = <AppTheme>[
  AppTheme('Rosa natt', Color(0xFFE91E8C), Brightness.dark),
  AppTheme('Stadiongrønn', Color(0xFF2E7D32), Brightness.dark),
  AppTheme('Kveldsnavy', Color(0xFF5C7CFA), Brightness.dark),
  AppTheme('Gull & svart', Color(0xFFFFB300), Brightness.dark),
  AppTheme('Pride natt', Color(0xFF9C27B0), Brightness.dark, rainbow: true),
  AppTheme('Rosa (lys)', Color(0xFFE91E8C), Brightness.light),
  AppTheme('Pride (lys)', Color(0xFF9C27B0), Brightness.light, rainbow: true),
  AppTheme('Brutalistisk', Color(0xFFFFD400), Brightness.light, brutalist: true),
  AppTheme('Brutalistisk BIG', Color(0xFFFFD400), Brightness.light,
      brutalist: true, textScale: 2.0),
];

/// Byggjer ThemeData for et tema. Brutalist får en heilt eigen, hard stil.
ThemeData buildAppTheme(AppTheme t) {
  if (!t.brutalist) {
    return ThemeData(
      colorScheme:
          ColorScheme.fromSeed(seedColor: t.seed, brightness: t.brightness),
      useMaterial3: true,
    );
  }
  const ink = Color(0xFF111111);
  const paper = Color(0xFFF4F1E8);
  const mono = 'monospace';
  const fallback = ['Menlo', 'Consolas', 'Courier New', 'monospace'];
  final scheme = ColorScheme.fromSeed(
    seedColor: t.seed,
    brightness: Brightness.light,
  ).copyWith(
    surface: paper,
    onSurface: ink,
    primary: ink,
    onPrimary: Colors.white,
    secondary: t.seed,
    onSecondary: ink,
    secondaryContainer: t.seed,
    onSecondaryContainer: ink,
    primaryContainer: t.seed,
    onPrimaryContainer: ink,
    outline: ink,
    surfaceContainerHighest: const Color(0xFFE7E2D4),
  );
  const sharp = RoundedRectangleBorder(
    side: BorderSide(color: ink, width: 2),
    borderRadius: BorderRadius.zero,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: paper,
    fontFamily: mono,
    fontFamilyFallback: fallback,
    dividerTheme: const DividerThemeData(color: ink, thickness: 2, space: 12),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: sharp,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: ink,
        fontFamily: mono,
        fontFamilyFallback: fallback,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: sharp,
        backgroundColor: ink,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: sharp,
        side: const BorderSide(color: ink, width: 2),
        foregroundColor: ink,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: sharp, foregroundColor: ink),
    ),
    segmentedButtonTheme: const SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(sharp),
      ),
    ),
    chipTheme: const ChipThemeData(
      shape: sharp,
      side: BorderSide(color: ink, width: 2),
    ),
    dialogTheme: const DialogThemeData(shape: sharp),
    listTileTheme: const ListTileThemeData(iconColor: ink, textColor: ink),
  );
}

/// Standard-tema for nye besøkande: Pride natt (mørk regnboge).
final int _defaultThemeIndex = () {
  final i = kThemes
      .indexWhere((t) => t.rainbow && t.brightness == Brightness.dark);
  return i >= 0 ? i : 0;
}();

/// Vald tema-indeks, lytta på av heile appen og lagra lokalt.
final themeIndex = ValueNotifier<int>(_defaultThemeIndex);
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
        return MaterialApp(
          title: 'VM Tipping 2026',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(t),
          builder: (context, child) {
            if (t.textScale == 1.0 || child == null) return child ?? const SizedBox();
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(t.textScale)),
              child: child,
            );
          },
          home: const HomePage(),
        );
      },
    );
  }
}

// ---- Delte resultat-hjelparar (resultat er felles for alle deltakere) ----

/// Faktiske mål [m1, m2] (manuell overstyring vinn over offisielt), eller null.
List<int>? actualResult(MatchInfo m, Overrides ovr) {
  final o = ovr.get(m.num);
  if (o != null) return o;
  if (m.played) return [m.score1!, m.score2!];
  return null;
}

/// 1/2 = vinner-side, 0 = uavgjort, null = ikke avgjort. Override-medviten.
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
      return const Color(0xFF8BC34A); // lysegrønn
    case Advance.thirdOut:
      return const Color(0xFFF5A623); // oransje
    case Advance.out:
      return Colors.red;
  }
}

String advLabel(TeamStanding r) {
  switch (r.advance) {
    case Advance.direct:
      return 'Videre';
    case Advance.thirdIn:
      return '3.pl (nr ${r.thirdRank}) → videre';
    case Advance.thirdOut:
      return '3.pl (nr ${r.thirdRank}) → ute';
    case Advance.out:
      return 'Ute';
  }
}

/// Gjenbrukbart gruppetabell-kort. [showStatus] = vis videre-status (skru av
/// før gruppa har spilt noen kamper, så vi ikke fargar ei tom 0-0-tabell).
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

/// Toppnivå-fane: sluttspilloppsettet (felles) ut fra faktiske resultat,
/// med en scenario-veljar ("hvem møter laget videre").
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

  /// Lagnavn -> gruppebokstav (A..L), fra gruppekampene.
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
                'Sluttspilloppsettet ut fra faktiske resultat (felles for alle). '
                'Plassene (1A, 2B, 3.-ere, vinner/taper av kamp) fyller seg med '
                'ekte lag etter hvert som gruppene og sluttspillkampene blir spilt. '
                'Venstre og høyre halvdel møtes i finalen i midten.',
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
                const Text('Spør om sluttspillet',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Velg et lag og hvilken plassering du tenker deg – så viser jeg hvem '
              'de møter runde for runde (om de går videre).',
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
                    ButtonSegment(value: 1, label: Text('Vinner')),
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
      return Text('Fant ingen sluttspillvei for dette valget.',
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

/// Toppnivå-fane: alle gruppetabellane ut fra faktiske resultat (felles).
class GroupStageView extends StatelessWidget {
  final List<MatchInfo> matches;
  final Overrides overrides;
  final Map<int, LiveInfo> live;
  const GroupStageView(
      {super.key,
      required this.matches,
      required this.overrides,
      this.live = const {}});

  @override
  Widget build(BuildContext context) {
    // Live-bevisst: tabellen rører seg medan kamper pågår.
    final tables = groupTables(_liveAwareScore(overrides, live), matches);
    final keys = tables.keys.toList()..sort();
    final anyLive = matches.any((m) =>
        m.isGroup && (live[m.num]?.inPlay ?? false));
    // Tal kamper med resultat (ferdig ELLER live) per gruppe – styrer status.
    final score = _liveAwareScore(overrides, live);
    final playedByGroup = <String, int>{};
    for (final m in matches.where((m) => m.isGroup)) {
      if (score(m) != null) {
        playedByGroup[m.group] = (playedByGroup[m.group] ?? 0) + 1;
      }
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              if (anyLive) ...[
                const _PulsingDot(size: 8),
                const SizedBox(width: 6),
                const Text('LIVE',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red)),
                const SizedBox(width: 8),
              ],
              const Expanded(
                child: Text(
                  'Gruppetabeller som oppdaterer seg live. Grønn = 1./2.plass '
                  '(direkte videre), lysegrønn = 3.plass blant de 8 beste, '
                  'oransje = 3.plass utenfor, rød = ute.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
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

/// Intern visningsnamn -> namn i den offisielle lista (for å vise off. plassering).
const _internalToOfficial = {
  'Thea': 'Thea Christianslund',
  'Svein Egil': 'Svein Egil Christianslund',
  'Britt Heidi': 'Britt Heidi Christianslund',
  'Simen og Lina': 'Simen Roseth',
  'Kenneth': 'Kenneth Roseth',
  'Mikal': 'Mikal West',
  'Jamal': 'Jamal Al Abdi',
  'Liv Marit': 'Liv Marit Brakstad',
  'Elisabeth': 'Elisabeth Laasby',
  'Sindre': 'Sindre Steinsvik',
  'Erlend': 'Erlend Hollund',
  'Maja Emilie': 'Maja Hermansen',
  // 'Steinar' (Vassnes) er ikkje med i den offisielle lista.
};

/// Namn i den offisielle lista som er «våre» (intern-poolen) – berre for utheving.
const _ourOfficialNames = {
  'Thea Christianslund',
  'Svein Egil Christianslund',
  'Britt Heidi Christianslund',
  'Simen Roseth',
  'Kenneth Roseth',
  'Mikal West',
  'Jamal Al Abdi',
  'Liv Marit Brakstad',
  'Elisabeth Laasby',
  'Sindre Steinsvik',
  'Erlend Hollund',
  'Maja Hermansen',
};

/// Toppnivå-fane: enkel rangert tabell for den offisielle konkurransen.
class OfficialView extends StatefulWidget {
  final List<Participant> official;
  final List<MatchInfo> matches;
  final Overrides overrides;
  final Map<String, double>? winPct;
  final bool simBusy;
  final VoidCallback? onCompute;
  const OfficialView(
      {super.key,
      required this.official,
      required this.matches,
      required this.overrides,
      this.winPct,
      this.simBusy = false,
      this.onCompute});

  @override
  State<OfficialView> createState() => _OfficialViewState();
}

class _OfficialViewState extends State<OfficialView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.official.isEmpty) {
      return const Center(child: Text('Inga offisiell liste lasta.'));
    }
    // Global rangering på total poeng (tiebreak: namn).
    final standings = widget.official
        .map((p) => standingFor(p, widget.matches, widget.overrides))
        .toList()
      ..sort((a, b) {
        final c = b.total.compareTo(a.total);
        return c != 0 ? c : a.p.name.compareTo(b.p.name);
      });
    final q = _query.trim().toLowerCase();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Offisiell konkurranse · ${standings.length} deltakere',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                'Rangert på poeng (gruppe + medaljer). Trykk på en person for '
                'å se tipsene deres. Dine egne er uthevet.',
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: 'Søk etter navn …',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: widget.simBusy ? null : widget.onCompute,
                    icon: widget.simBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.casino_outlined, size: 18),
                    label: Text(widget.simBusy
                        ? 'Reknar …'
                        : 'Rekn sjanse for 1. plass'),
                  ),
                  const SizedBox(width: 10),
                  if (widget.winPct != null)
                    Expanded(
                      child: Text('🏆 vist per person (1000 simuleringar)',
                          style:
                              TextStyle(fontSize: 11, color: scheme.outline)),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: standings.length,
            itemBuilder: (_, i) {
              final s = standings[i];
              final rank = i + 1;
              if (q.isNotEmpty && !s.p.name.toLowerCase().contains(q)) {
                return const SizedBox.shrink();
              }
              final ours = _ourOfficialNames.contains(s.p.name);
              final rankColor = switch (rank) {
                1 => const Color(0xFFFFC107),
                2 => const Color(0xFFB0BEC5),
                3 => const Color(0xFFCD7F32),
                4 || 5 => scheme.primary,
                _ => scheme.surfaceContainerHighest,
              };
              return Container(
                color: ours ? scheme.primary.withValues(alpha: 0.10) : null,
                child: ListTile(
                  dense: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OfficialTipsPage(
                        p: s.p,
                        matches: widget.matches,
                        overrides: widget.overrides,
                      ),
                    ),
                  ),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: rankColor,
                    child: Text('$rank',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: rank <= 5 ? Colors.white : scheme.onSurface)),
                  ),
                  title: Text(
                    s.p.name,
                    style: TextStyle(
                        fontWeight:
                            ours ? FontWeight.bold : FontWeight.w500),
                  ),
                  subtitle: Text('Gruppepoeng: ${s.group} · Medaljepoeng: ${s.medal}'
                      '${widget.winPct != null ? ' · 🏆 ${_fmtPct(widget.winPct![s.p.name] ?? 0)} sjanse' : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${s.total} p',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Detaljside: éin offisiell deltaker sine tips, med Kommende/Tidligere-filter.
class OfficialTipsPage extends StatefulWidget {
  final Participant p;
  final List<MatchInfo> matches;
  final Overrides overrides;
  const OfficialTipsPage(
      {super.key,
      required this.p,
      required this.matches,
      required this.overrides});

  @override
  State<OfficialTipsPage> createState() => _OfficialTipsPageState();
}

class _OfficialTipsPageState extends State<OfficialTipsPage> {
  bool _showUpcoming = true;
  bool _showPlayed = false;

  Participant get p => widget.p;
  Overrides get ovr => widget.overrides;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final group = widget.matches.where((m) => m.isGroup).toList()
      ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
    final shown = group.where((m) {
      final played = actualResult(m, ovr) != null;
      return played ? _showPlayed : _showUpcoming;
    }).toList();

    Widget medalChip(String emoji, String? team) => Expanded(
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 2),
              Text(team == null || team.isEmpty ? '–' : '${flagFor(team)} $team',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: ListView(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Medaljer',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    medalChip('🥇', p.medals['gold']),
                    medalChip('🥈', p.medals['silver']),
                    medalChip('🥉', p.medals['bronze']),
                  ]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Kommende'),
                  selected: _showUpcoming,
                  onSelected: (v) => setState(() => _showUpcoming = v),
                ),
                FilterChip(
                  label: const Text('Tidligere'),
                  selected: _showPlayed,
                  onSelected: (v) => setState(() => _showPlayed = v),
                ),
              ],
            ),
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Ingen kamper å vise. Huk av eit filter.',
                  style: TextStyle(color: scheme.outline)),
            ),
          for (final m in shown) _officialTipTile(m),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _officialTipTile(MatchInfo m) {
    final pred = p.forMatch(m.team1, m.team2);
    final tip = pred == null ? '–' : '${pred[m.team1]}–${pred[m.team2]}';
    final act = actualResult(m, ovr);
    final played = act != null;
    final pts = played ? matchPointsFor(p, m, ovr) : null;
    final sub = played
        ? '${_prettyDate(_osloDateIso(m))} · fasit ${act[0]}–${act[1]} · ${pts}p'
        : '${_prettyDate(_osloDateIso(m))} ${_osloTime(m)} · ${m.group.replaceFirst('Group', 'Gruppe')}';
    final ptsColor = pts == 3
        ? Colors.green
        : (pts == 1 ? const Color(0xFFF5A623) : null);
    return ListTile(
      dense: true,
      title: Text(
          '${flagFor(m.team1)} ${m.team1}  –  ${flagFor(m.team2)} ${m.team2}'),
      subtitle: Text(sub,
          style: played && ptsColor != null
              ? TextStyle(color: ptsColor, fontWeight: FontWeight.w600)
              : null),
      trailing: Text('Tippet: $tip',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }
}

// ---- Medalje-trafikklys --------------------------------------------------
// Vurderer om et medaljetips fortsatt er oppnåeleg.
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

/// Som [_resultScore], men tar òg med live-stillinga for kamper som pågår.
/// Brukast til gruppetabellar så dei rører seg LIVE (poeng tel framleis berre
/// på ferdige resultat – det går via actualResult/standingFor).
ScoreFor _liveAwareScore(Overrides ovr, Map<int, LiveInfo> live) => (m) {
      final a = actualResult(m, ovr);
      if (a != null) return {m.team1: a[0], m.team2: a[1]};
      final li = live[m.num];
      if (li != null && li.inPlay && li.s1 != null && li.s2 != null) {
        return {m.team1: li.s1!, m.team2: li.s2!};
      }
      return null;
    };

/// Lag som er slått ut i verkelegheita: taperar av spilt sluttspillkamper, og
/// lag som vart sist i ei ferdigspilt gruppe (4.plass kan ikke gå videre).
Set<String> _eliminatedTeams(List<MatchInfo> matches, Overrides ovr) {
  final out = <String>{};
  final score = _resultScore(ovr);
  // Sisteplass i ferdigspilt grupper kan ikke gå videre.
  final st = standingsFromScore(score, matches, requireComplete: true);
  for (final rows in st.values) {
    if (rows.length == 4) out.add(rows.last);
  }
  // Taperar av spilt sluttspillkamper.
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
  final picks = p.medals; // gold/silver/bronze -> lagnavn
  final actual = actualMedals(matches, ovr);
  final eliminated = _eliminatedTeams(matches, ovr);

  // Projisert halvdel (fra deltakeren sine tips) for hver kvalifisert lag.
  final proj = buildBracket(
    scoreFor: _tipsScore(p),
    matches: matches,
    winnerSide: (m) => winnerSideOf(m, ovr),
  );
  final leftR32 = _leftRounds[0].toSet();
  final rightR32 = _rightRounds[0].toSet();
  final halfOf = <String, String>{}; // lagnavn -> 'V'/'H'
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
      return const MedalEval(MedalFeas.caution, 'Ingen tips');
    }
    // 1) Allereie avgjort i verkelegheita?
    final decided = actual[finalMedalKey];
    if (decided != null) {
      return decided == team
          ? MedalEval(MedalFeas.achieved, 'Oppnådd – $medalLabel sikret')
          : MedalEval(MedalFeas.impossible, '$medalLabel gikk til $decided');
    }
    // 2) Slått ut?
    if (eliminated.contains(team)) {
      return MedalEval(MedalFeas.impossible, '$team er allerede ute');
    }
    // 3) Duplikat?
    final others = [
      for (final e in picks.entries)
        if (e.key != key) e.value
    ];
    if (others.contains(team)) {
      return const MedalEval(
          MedalFeas.impossible, 'Samme lag er tippet på flere medaljer');
    }
    // 4) Kvalifiserer laget i deltakeren si eiga projeksjon?
    if (!qualified.contains(team)) {
      return MedalEval(MedalFeas.caution,
          'Mulig, men dine tips har $team ute av gruppespillet');
    }
    // 5) Gull/sølv på samme halvdel (møtes før finalen) i eigne tips?
    if ((key == 'gold' || key == 'silver') && sameHalf) {
      return const MedalEval(MedalFeas.caution,
          'Gull og sølv havner på samme halvdel i dine tips – de møtes før finalen');
    }
    return const MedalEval(MedalFeas.ok, 'Mulig og i tråd med dine tips');
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

/// Midlertidige poeng ut fra live-stillinga (kampen pågår), eller null om
/// kampen ikke er live eller deltakeren ikke har tippet han.
int? liveTempPointsFor(Participant p, MatchInfo m, LiveInfo? li) {
  if (li == null || !li.inPlay || li.s1 == null || li.s2 == null) return null;
  final pred = p.forMatch(m.team1, m.team2);
  if (pred == null) return null;
  return matchPoints(
    pred1: pred[m.team1]!,
    pred2: pred[m.team2]!,
    act1: li.s1!,
    act2: li.s2!,
  );
}

/// Sum av midlertidige poeng over alle live-kamper for en deltaker.
int liveTempTotal(Participant p, List<MatchInfo> matches, Map<int, LiveInfo> live) {
  var sum = 0;
  for (final m in matches) {
    sum += liveTempPointsFor(p, m, live[m.num]) ?? 0;
  }
  return sum;
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

/// Monte Carlo: sjanse (%) for 1. plass per deltaker.
/// Tipsa er låste; berre uspilte kamp-resultat + sluttspel/medaljer er usikre.
/// Spelte kamper og manuelle overstyringar er fasit; resten vert simulert.
Map<String, double> simulateWinChances(
    List<Participant> ps, List<MatchInfo> matches, Overrides ovr,
    {int sims = 1000}) {
  if (ps.isEmpty) return {};
  final rnd = Random();
  final group = matches.where((m) => m.isGroup).toList();
  final koMatches = {for (final m in matches.where((m) => !m.isGroup)) m.num: m};
  final wins = {for (final p in ps) p.name: 0.0};

  int pois(double lam) {
    final l = exp(-lam);
    var k = 0;
    var p = 1.0;
    do {
      k++;
      p *= rnd.nextDouble();
    } while (p > l);
    return k - 1;
  }

  for (var s = 0; s < sims; s++) {
    // 1) Resultat for alle gruppekamper (fasit der spilt, elles simulert).
    final res = <int, List<int>>{};
    for (final m in group) {
      final a = actualResult(m, ovr);
      res[m.num] = a ?? [pois(1.35), pois(1.15)];
    }
    Map<String, int>? scoreFor(MatchInfo m) {
      final r = res[m.num];
      return r == null ? null : {m.team1: r[0], m.team2: r[1]};
    }
    // 2) Vinnar-side per sluttspelkamp (fasit der spilt, elles tilfeldig).
    final side = <int, int>{};
    int sideOf(int num) {
      final mi = koMatches[num];
      if (mi != null) {
        final w = winnerSideOf(mi, ovr);
        if (w == 1) return 1;
        if (w == 2) return 2;
      }
      return side.putIfAbsent(num, () => rnd.nextBool() ? 1 : 2);
    }
    final bracket = buildBracket(
      scoreFor: scoreFor,
      matches: matches,
      winnerSide: (m) => sideOf(m.num),
      requireComplete: true,
    );
    final byNum = {for (final km in bracket) km.num: km};
    // 3) Medaljar frå simulert finale/bronsefinale.
    String? gold, silver, bronze;
    final fin = byNum[_finalNum];
    if (fin != null && fin.home.resolved && fin.away.resolved) {
      final w = sideOf(_finalNum);
      gold = w == 1 ? fin.home.team : fin.away.team;
      silver = w == 1 ? fin.away.team : fin.home.team;
    }
    final br = byNum[_thirdNum];
    if (br != null && br.home.resolved && br.away.resolved) {
      bronze = sideOf(_thirdNum) == 1 ? br.home.team : br.away.team;
    }
    final med = {'gold': gold, 'silver': silver, 'bronze': bronze};
    // 4) Poengsum per deltaker = gruppepoeng + medaljepoeng.
    var best = -1;
    final leaders = <String>[];
    for (final p in ps) {
      var pts = medalPoints(p.medals, med);
      for (final m in group) {
        final pred = p.forMatch(m.team1, m.team2);
        if (pred == null) continue;
        final r = res[m.num]!;
        pts += matchPoints(
            pred1: pred[m.team1]!,
            pred2: pred[m.team2]!,
            act1: r[0],
            act2: r[1]);
      }
      if (pts > best) {
        best = pts;
        leaders
          ..clear()
          ..add(p.name);
      } else if (pts == best) {
        leaders.add(p.name);
      }
    }
    final share = 1.0 / leaders.length;
    for (final n in leaders) {
      wins[n] = wins[n]! + share;
    }
  }
  return wins.map((k, v) => MapEntry(k, v * 100 / sims));
}

/// Pen prosent: «24%», «<1%», «0%».
String _fmtPct(double v) {
  if (v <= 0) return '0%';
  if (v < 1) return '<1%';
  return '${v.round()}%';
}

// ---- Startskjerm: resultattavle ----

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<Participant> _participants = [];
  List<Participant> _official = [];
  Overrides? _ovr;
  List<MatchInfo> _raw = []; // openfootball (uendra)
  List<MatchInfo> _matches = []; // med live sluttresultat fletta inn
  Map<int, LiveInfo> _live = {};
  Timer? _liveTimer;
  bool _loading = true;
  String? _error;
  int _navIndex = 0;

  // Mål-pling.
  final AudioPlayer _player = AudioPlayer();
  bool _soundOn = true;
  bool _audioPrimed = false; // nettlesaren krev éi interaksjon før lyd
  static const _soundPrefKey = 'goal_sound';

  /// Låser opp lyd ved første trykk kvar som helst (stille avspeling).
  void _primeAudio() {
    if (_audioPrimed) return;
    _audioPrimed = true;
    _player.play(AssetSource('sounds/goal.wav'), volume: 0).catchError((_) {});
  }

  /// Navn på deltakere som er skjult i visninga (lagra lokalt).
  Set<String> _hidden = {};
  static const _hiddenPrefKey = 'hidden_participants';

  DateTime? _liveAt; // siste vellukka live-oppdatering

  // Vinnarsjanse (Monte Carlo), rekna på førespurnad.
  Map<String, double>? _winPct;
  bool _simBusy = false;

  Future<void> _runSim() async {
    setState(() => _simBusy = true);
    await Future.delayed(const Duration(milliseconds: 50));
    // Sjanse for 1. plass i HEILE den offisielle konkurransen (143).
    final pool = _official.isNotEmpty ? _official : _participants;
    final r = simulateWinChances(pool, _matches, _ovr!, sims: 1000);
    if (!mounted) return;
    setState(() {
      _winPct = r;
      _simBusy = false;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Når appen/fana kjem i forgrunnen igjen: hent live med ein gong.
    if (state == AppLifecycleState.resumed) _applyLive();
  }

  /// Mål sidan sist: liste med tekstar som "⚽ Mexico 2–0 Sør-Afrika".
  List<String> _goalEvents(Map<int, LiveInfo> old, Map<int, LiveInfo> fresh) {
    final byNum = {for (final m in _raw) m.num: m};
    final out = <String>[];
    for (final e in fresh.entries) {
      final n = old[e.key], f = e.value;
      if (f.s1 == null || f.s2 == null) continue;
      if (n == null || n.s1 == null || n.s2 == null) continue;
      if ((f.s1! + f.s2!) > (n.s1! + n.s2!)) {
        final m = byNum[e.key];
        if (m != null) out.add('⚽ ${m.team1} ${f.s1}–${f.s2} ${m.team2}');
      }
    }
    return out;
  }

  /// Hentar live-data og flettar ferdigspilt (post) gruppekamper inn som
  /// resultat, slik at tabeller, tre og poeng oppdaterer seg automatisk.
  Future<void> _applyLive() async {
    if (_raw.isEmpty) return;
    final live = await fetchLive(_raw);
    final goals = _goalEvents(_live, live);
    final merged = [
      for (final m in _raw)
        (m.isGroup &&
                !m.played &&
                live[m.num]?.finished == true &&
                live[m.num]!.s1 != null &&
                live[m.num]!.s2 != null)
            ? m.copyWith(score1: live[m.num]!.s1, score2: live[m.num]!.s2)
            : m
    ];
    if (!mounted) return;
    setState(() {
      _live = live;
      _matches = merged;
      _liveAt = DateTime.now();
    });
    if (goals.isNotEmpty) {
      if (_soundOn) {
        try {
          await _player.play(AssetSource('sounds/goal.wav'), volume: 1);
        } catch (_) {}
      }
      // Synleg MÅL-banner (sjølv om lyd er blokkert i nettlesaren).
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('MÅL!  ${goals.join('   ·   ')}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final participants = await Participant.loadAll();
      List<Participant> official = [];
      try {
        official = await Participant.loadOfficial();
      } catch (_) {/* offisiell liste er valfri */}
      final ovr = await Overrides.load();
      final matches = await fetchMatches();
      final prefs = await SharedPreferences.getInstance();
      final hidden = prefs.getStringList(_hiddenPrefKey)?.toSet() ?? <String>{};
      setState(() {
        _participants = participants;
        _official = official;
        _ovr = ovr;
        _raw = matches;
        _matches = matches;
        _hidden = hidden;
        _soundOn = prefs.getBool(_soundPrefKey) ?? true;
        _loading = false;
      });
      // Live-resultat: hent no, og oppdater hvert minutt.
      await _applyLive();
      _liveTimer?.cancel();
      _liveTimer =
          Timer.periodic(const Duration(seconds: 10), (_) => _applyLive());
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

  /// Deltakarar gruppert i lag (Chræs / Andre / IT). IT = alle andre.
  Map<String, List<Participant>> _participantGroups() {
    const chras = {'Britt Heidi', 'Svein Egil', 'Simen og Lina', 'Thea'};
    const andre = {'Liv Marit', 'Kenneth', 'Maja Emilie'};
    final out = <String, List<Participant>>{'Chræs': [], 'Andre': [], 'IT': []};
    for (final p in _participants) {
      if (chras.contains(p.name)) {
        out['Chræs']!.add(p);
      } else if (andre.contains(p.name)) {
        out['Andre']!.add(p);
      } else {
        out['IT']!.add(p);
      }
    }
    out.removeWhere((k, v) => v.isEmpty);
    return out;
  }

  /// Dialog med avkryssing, gruppert i lag, scrollbar.
  void _openFilter() {
    final groups = _participantGroups();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final hidden = {..._hidden};
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Widget groupSection(String name, List<Participant> members) {
              final visibleCount =
                  members.where((p) => !hidden.contains(p.name)).length;
              final all = visibleCount == members.length;
              final none = visibleCount == 0;
              return ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                childrenPadding: const EdgeInsets.only(left: 12),
                leading: Checkbox(
                  tristate: true,
                  value: all ? true : (none ? false : null),
                  onChanged: (_) => setLocal(() {
                    if (all) {
                      hidden.addAll(members.map((p) => p.name)); // skjul alle
                    } else {
                      hidden.removeAll(members.map((p) => p.name)); // vis alle
                    }
                  }),
                ),
                title: Text('$name ($visibleCount/${members.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                children: [
                  for (final p in members)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 8, right: 0),
                      controlAffinity: ListTileControlAffinity.leading,
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
                ],
              );
            }

            return AlertDialog(
              title: const Text('Vis deltakere'),
              content: SizedBox(
                width: 340,
                height: 420,
                child: ListView(
                  children: [
                    for (final e in groups.entries)
                      groupSection(e.key, e.value),
                    const Divider(),
                    TextButton(
                      onPressed: () => setLocal(hidden.clear),
                      child: const Text('Vis alle'),
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
                Text('Klarte ikke hente data:\n$_error',
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

    // Sorter på reelle poeng + live «temp»-poeng, så tavla flyttar seg
    // medan kampene går. Tiebreak: reell total, så navn.
    int effective(Standing s) =>
        s.total + liveTempTotal(s.p, _matches, _live);
    final standings = _visible
        .map((p) => standingFor(p, _matches, _ovr!))
        .toList()
      ..sort((a, b) {
        final c = effective(b).compareTo(effective(a));
        if (c != 0) return c;
        final t = b.total.compareTo(a.total);
        return t != 0 ? t : a.p.name.compareTo(b.p.name);
      });

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _primeAudio(),
      child: Scaffold(
      appBar: AppBar(
        title: const Text('VM Tipping 2026'),
        actions: [
          IconButton(
            tooltip: 'Filtrer deltakere',
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
          if (_liveAt != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'live ${_two(_liveAt!.hour)}:${_two(_liveAt!.minute)}:${_two(_liveAt!.second)}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          IconButton(
            tooltip: _soundOn ? 'Mål-pling på' : 'Mål-pling av',
            onPressed: () async {
              setState(() => _soundOn = !_soundOn);
              final p = await SharedPreferences.getInstance();
              await p.setBool(_soundPrefKey, _soundOn);
              _audioPrimed = true;
              if (_soundOn) {
                try {
                  await _player.play(AssetSource('sounds/goal.wav'), volume: 1);
                } catch (_) {}
              }
            },
            icon: Icon(_soundOn ? Icons.volume_up : Icons.volume_off),
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
                  ? GroupStageView(
                      matches: _matches, overrides: _ovr!, live: _live)
                  : _navIndex == 2
                      ? UpcomingMatchesView(
                          matches: _matches,
                          participants: _visible,
                          overrides: _ovr!,
                          live: _live,
                          official: _official,
                        )
                      : _navIndex == 3
                          ? KnockoutView(matches: _matches, overrides: _ovr!)
                          : OfficialView(
                              official: _official,
                              matches: _matches,
                              overrides: _ovr!,
                              winPct: _winPct,
                              simBusy: _simBusy,
                              onCompute: _runSim,
                            );

          // Smal skjerm (mobil): innhald i full breidde, meny kjem
          // som botnmeny under (se bottomNavigationBar).
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
                    label: Text('Kamper'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.account_tree_outlined),
                    selectedIcon: Icon(Icons.account_tree),
                    label: Text('Sluttspill'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.public_outlined),
                    selectedIcon: Icon(Icons.public),
                    label: Text('Offisiell'),
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
                  label: 'Kamper',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_tree_outlined),
                  selectedIcon: Icon(Icons.account_tree),
                  label: 'Sluttspill',
                ),
                NavigationDestination(
                  icon: Icon(Icons.public_outlined),
                  selectedIcon: Icon(Icons.public),
                  label: 'Offisiell',
                ),
              ],
            )
          : null,
      ),
    );
  }

  Widget _scoreboard(List<Standing> standings) {
    final scheme = Theme.of(context).colorScheme;
    final pride = kThemes[themeIndex.value].rainbow;
    final officialRank = _officialRanks();

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
              Text('$_playedGroupMatches av 72 gruppekamper spilt',
                  style: TextStyle(color: headerFg, shadows: shadows)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          child: Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _simBusy ? null : _runSim,
                icon: _simBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.casino_outlined, size: 18),
                label: Text(_simBusy ? 'Reknar …' : 'Rekn vinnarsjanse'),
              ),
              const SizedBox(width: 10),
              if (_winPct != null)
                Expanded(
                  child: Text(
                    'Sjanse for 1. plass i heile den offisielle konkurransen '
                    '(${_winPct!.length} stk, 1000 simuleringar).',
                    style: TextStyle(fontSize: 11, color: scheme.outline),
                  ),
                ),
            ],
          ),
        ),
        for (var i = 0; i < standings.length; i++)
          _standingTile(standings[i], i + 1, officialRank),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Offisiell plassering per offisielt namn (rangert som Offisiell-fana).
  Map<String, int> _officialRanks() {
    if (_official.isEmpty) return const {};
    final st = _official.map((p) => standingFor(p, _matches, _ovr!)).toList()
      ..sort((a, b) {
        final c = b.total.compareTo(a.total);
        return c != 0 ? c : a.p.name.compareTo(b.p.name);
      });
    return {for (var i = 0; i < st.length; i++) st[i].p.name: i + 1};
  }

  Widget _standingTile(Standing s, int rank, Map<String, int> officialRank) {
    final temp = liveTempTotal(s.p, _matches, _live);
    final offName = _internalToOfficial[s.p.name];
    final offRank = offName != null ? officialRank[offName] : null;
    final scheme = Theme.of(context).colorScheme;
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
      title: Row(
        children: [
          Flexible(
            child: Text(s.p.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (offRank != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Plass i offisiell konkurranse (av ${officialRank.length})',
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('💰 #$offRank',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary)),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
          'Gruppepoeng: ${s.group} · Medaljepoeng: ${s.medal}'
          '${_winPct != null && offName != null && _winPct!.containsKey(offName) ? ' · 🏆 ${_fmtPct(_winPct![offName] ?? 0)} sjanse' : ''}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (temp > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PulsingDot(size: 6),
                    const SizedBox(width: 4),
                    Text('+$temp',
                        style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
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
              live: _live,
            ),
          ),
        );
        if (mounted) setState(() {}); // overstyringar kan ha endra seg
      },
    );
  }
}

// ---- Kommende kamper (kronologisk, med alle sine tips) ----

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
// så vi kan bruke en fast offset.
const _osloOffset = 2;

/// Kamptidspunktet i norsk tid, eller null om tid/dato ikke kan tolkast.
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

/// Dato (ISO) i norsk tid – kan rulle over til neste dag for seine kamper.
String _osloDateIso(MatchInfo m) {
  final dt = _osloDateTime(m);
  if (dt == null) return m.date;
  return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
}

/// Sorteringsnøkkel: faktisk tidspunkt (UTC-instans), elles rå strenger.
String _sortKey(MatchInfo m) {
  final dt = _osloDateTime(m);
  if (dt == null) return '${m.date} ${m.time}';
  return dt.toIso8601String();
}

/// Liten pulserande prikk – signaliserer at kampen fortsatt pågår.
class _PulsingDot extends StatefulWidget {
  final double size;
  const _PulsingDot({this.size = 8});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 750))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.25).animate(_c),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
            color: Colors.red, shape: BoxShape.circle),
      ),
    );
  }
}

class UpcomingMatchesView extends StatefulWidget {
  final List<MatchInfo> matches;
  final List<Participant> participants;
  final Overrides overrides;
  final Map<int, LiveInfo> live;
  final List<Participant> official;
  const UpcomingMatchesView({
    super.key,
    required this.matches,
    required this.participants,
    required this.overrides,
    this.live = const {},
    this.official = const [],
  });

  @override
  State<UpcomingMatchesView> createState() => _UpcomingMatchesViewState();
}

class _UpcomingMatchesViewState extends State<UpcomingMatchesView> {
  bool _showUpcoming = true; // kommende
  bool _showPlayed = false; // tidligere
  bool _perGroup = false; // eigen modus: neste pr. gruppe

  @override
  Widget build(BuildContext context) {
    final ovr = widget.overrides;
    final all = [...widget.matches]
      ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));

    Widget body;
    if (_perGroup) {
      body = _nextPerGroupList(all, ovr);
    } else {
      final shown = all.where((m) {
        final played = actualResult(m, ovr) != null;
        return played ? _showPlayed : _showUpcoming;
      }).toList();
      body = shown.isEmpty
          ? const Center(child: Text('Ingen kamper å vise. Huk av eit filter.'))
          : ListView(children: _groupedByDay(shown));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('Kommende'),
                selected: !_perGroup && _showUpcoming,
                onSelected: (v) => setState(() {
                  _perGroup = false;
                  _showUpcoming = v;
                }),
              ),
              FilterChip(
                label: const Text('Tidligere'),
                selected: !_perGroup && _showPlayed,
                onSelected: (v) => setState(() {
                  _perGroup = false;
                  _showPlayed = v;
                }),
              ),
              FilterChip(
                avatar: const Icon(Icons.table_chart_outlined, size: 16),
                label: const Text('Neste pr. gruppe'),
                selected: _perGroup,
                onSelected: (v) => setState(() => _perGroup = v),
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  /// De neste (inntil 2) uspilt kampene i hver gruppe, under gruppe-overskrift.
  Widget _nextPerGroupList(List<MatchInfo> all, Overrides ovr) {
    final byGroup = <String, List<MatchInfo>>{};
    for (final m in all) {
      if (m.isGroup && actualResult(m, ovr) == null) {
        byGroup.putIfAbsent(m.group, () => []).add(m);
      }
    }
    final keys = byGroup.keys.toList()..sort();
    if (keys.isEmpty) {
      return const Center(child: Text('Ingen kommende gruppekamper.'));
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

  /// Byggjer lista med en dato-skiljelinje ("ny dag") føre hver nye dag.
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
          Text('$count ${count == 1 ? 'kamp' : 'kamper'}',
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

    // Hvem har tippet på denne kampen?
    final tippers = <Participant>[
      for (final p in widget.participants)
        if (p.forMatch(m.team1, m.team2) != null) p
    ];

    final li = widget.live[m.num];
    Widget trailing;
    if (li != null && li.inPlay) {
      // Live: rød LIVE-merke + stilling + spilt-minutt.
      trailing = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Padding(
                padding: EdgeInsets.only(right: 4),
                child: _PulsingDot(size: 7),
              ),
              Text('LIVE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.red)),
            ],
          ),
          Text('${li.s1 ?? 0}–${li.s2 ?? 0}',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
          if (li.detail.isNotEmpty)
            Text(li.detail,
                style: const TextStyle(fontSize: 9, color: Colors.red)),
        ],
      );
    } else if (act != null) {
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
          if (m.isGroup) ..._consensusRow(m),
          if (m.isGroup) ..._groupTableSection(m),
          if (tippers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                m.isGroup
                    ? 'Ingen har tippet denne kampen ennå.'
                    : 'Sluttspillkamper blir ikke tippet på resultat.',
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

  /// Gruppetabell (live-bevisst) for gruppa kampen høyrer til.
  List<Widget> _groupTableSection(MatchInfo m) {
    final score = _liveAwareScore(widget.overrides, widget.live);
    final tables = groupTables(score, widget.matches);
    final rows = tables[m.group];
    if (rows == null) return const [];
    final played = widget.matches
        .where((x) => x.group == m.group && score(x) != null)
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

  /// «Mest tippa»-rad: dei 3 vanlegaste resultata blant alle offisielle tips.
  List<Widget> _consensusRow(MatchInfo m) {
    if (widget.official.isEmpty) return const [];
    // Alle tippa stillingar (av dei 143 offisielle) -> kven tippa kvar.
    final byScore = <String, List<String>>{};
    var total = 0;
    for (final p in widget.official) {
      final pred = p.forMatch(m.team1, m.team2);
      if (pred == null) continue;
      final key = '${pred[m.team1]}–${pred[m.team2]}';
      byScore.putIfAbsent(key, () => []).add(p.name);
      total++;
    }
    if (total == 0) return const [];
    final entries = byScore.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final scheme = Theme.of(context).colorScheme;
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Row(children: [
          Text('💰 Alle tippa resultat',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary)),
          const SizedBox(width: 6),
          Text('(av $total) – trykk for å sjå kven',
              style: TextStyle(fontSize: 11, color: scheme.outline)),
        ]),
      ),
      for (final e in entries)
        Theme(
          // Fjern standard-dividerane i den nøsta ExpansionTile.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            dense: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 4, 8),
            title: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(e.key,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Text(
                    '${e.value.length}  ·  ${_fmtPct(e.value.length * 100 / total)}',
                    style: TextStyle(fontSize: 12, color: scheme.outline)),
              ],
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final name in e.value..sort())
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _ourOfficialNames.contains(name)
                              ? scheme.primary.withValues(alpha: 0.18)
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(name,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: _ourOfficialNames.contains(name)
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _tipRow(Participant p, MatchInfo m, List<int>? act) {
    final scheme = Theme.of(context).colorScheme;
    final pred = p.forMatch(m.team1, m.team2)!;
    final tip = '${pred[m.team1]}–${pred[m.team2]}';
    final tempPts = liveTempPointsFor(p, m, widget.live[m.num]);

    Color? bg;
    String? badge;
    Color badgeColor = scheme.outline;
    bool temp = false;
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
    } else if (tempPts != null) {
      // Live: midlertidige poeng ut fra stillinga akkurat no.
      temp = true;
      badge = 'temp $tempPts' 'p';
      badgeColor = Colors.red;
      if (tempPts == 3) {
        bg = Colors.green.withValues(alpha: 0.10);
      } else if (tempPts == 1) {
        bg = Colors.amber.withValues(alpha: 0.10);
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
            if (temp) ...[
              const _PulsingDot(size: 6),
              const SizedBox(width: 4),
            ],
            Text(badge,
                style: TextStyle(
                    fontSize: 12,
                    color: badgeColor,
                    fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }
}

// ---- Detaljside for éin deltaker ----

class ParticipantPage extends StatefulWidget {
  final Participant participant;
  final List<MatchInfo> matches;
  final Overrides overrides;
  final Map<int, LiveInfo> live;
  const ParticipantPage({
    super.key,
    required this.participant,
    required this.matches,
    required this.overrides,
    this.live = const {},
  });
  @override
  State<ParticipantPage> createState() => _ParticipantPageState();
}

class _ParticipantPageState extends State<ParticipantPage> {
  Participant get _p => widget.participant;
  Overrides get _ovr => widget.overrides;
  List<MatchInfo> get _matches => widget.matches;

  // Sluttspilltre-modus: true = faktiske resultat, false = denne deltakeren si
  // projeksjon (tipping). Treet skal i utgangspunktet vise resultata.
  bool _bracketResults = true;

  // Gruppetabell-modus: samme logikk – tabellen viser resultata som standard.
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
            Tab(text: 'Sluttspilltre'),
            Tab(text: 'Medaljer'),
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
                      ? 'Faktiske resultat. Plassene fyller seg etter hvert '
                          'som gruppene og kampene blir ferdigspilt.'
                      : '${_p.name} sin projeksjon ut fra tippingene.',
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
                ? 'Sluttspilltreet ut fra faktiske resultat. Medaljetipsene dine '
                    'er uthevet. Venstre og høyre halvdel møtes i finalen i '
                    'midten; ekte lag fyller inn etter hvert.'
                : '${_p.name} sin projeksjon ut fra tippingene. Medaljetipsene '
                    'er uthevet. Venstre og høyre halvdel møtes i finalen i midten.',
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
            'Fargeprikk = om medaljen fortsatt går an:\n'
            '🟢 grønn = mulig og i tråd med dine tips\n'
            '🟡 gul = mulig, men dine tips gir en konflikt (f.eks. gull og '
            'sølv på samme halvdel – da møtes de før finalen)\n'
            '🔴 rød = umulig (laget er allerede ute, eller medaljen er avgjort).\n'
            'Hold pekeren over prikken for forklaring.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Text(
            'Husk: gull og sølv må komme fra hver sin halvdel av treet '
            '(de møtes i finalen). Bronse er vinneren av bronsefinalen '
            '(taperen av en semifinale). Se «Sluttspilltre» for hvem som '
            'kan møte hvem.',
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
    // Resultat-modus: faktiske resultat (live-bevisst). Projeksjon: dine tips.
    final resultScore = _liveAwareScore(_ovr, widget.live);
    final tables = _groupResults
        ? groupTables(resultScore, _matches)
        : groupTables(_tipsScore(_p), _matches);
    // Tal kamper med resultat (ferdig/live) per gruppe (for status-fargen).
    final playedByGroup = <String, int>{};
    for (final m in _matches.where((m) => m.isGroup)) {
      if (resultScore(m) != null) {
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
                      ? 'Faktiske resultat. Poengene fyller seg etter hvert som '
                          'kampene blir spilt.'
                      : '${_p.name} sin projeksjon ut fra tippingene.',
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
    final actStr = act == null ? 'ikke spilt' : '${act[0]}–${act[1]}';

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
                decoration: const InputDecoration(labelText: 'Hjemme'),
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
            'Gruppespill: $group · Medaljer: $medal · $played kamper talt',
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

// ---- Sluttspilltre (to-sidig: venstre + høyre møtes i finalen i midten) ----

const double _cardW = 190;
const double _cardH = 64;
const double _vGap = 14;
const double _colGap = 52;
const double _leftPad = 24;
const double _topPad = 56;
const double _titleH = 18; // høgd til tittel over et kort

// Venstre halvdel (veks mot høyre): R32 -> R16 -> QF -> SF.
const _leftRounds = <List<int>>[
  [74, 77, 73, 75, 83, 84, 81, 82],
  [89, 90, 93, 94],
  [97, 98],
  [101],
];
// Høyre halvdel (veks mot venstre, spegla).
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
    final rc = _mkCenters(8); // høyre
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
                'Venstre og høyre halvdel møtes i finalen i midten. '
                    'Dra/scroll for å se heile treet; ekte lag fyller inn '
                    'etter hvert som kampene blir spilt.',
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
  final List<List<double>> lc, rc; // venstre/høyre senter per runde
  final double midY;
  final Color color;
  _ConnectorPainter(this.lc, this.rc, this.midY, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Et «merge»: to kort i ytre kolonne -> eitt i indre kolonne.
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
      // Venstre: ytre kolonne r-1 (høyrekant) -> indre kolonne r (venstrekant).
      merge(_colX(r - 1) + _cardW, _colX(r), lc[r - 1], lc[r]);
      // Høyre: ytre kolonne 8-(r-1) (venstrekant) -> indre 8-r (høyrekant).
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
