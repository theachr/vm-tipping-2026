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
      setState(() {
        _participants = participants;
        _ovr = ovr;
        _matches = matches;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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

    final standings = _participants
        .map((p) => standingFor(p, _matches, _ovr!))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return Scaffold(
      appBar: AppBar(
        title: const Text('VM Tipping 2026'),
        actions: [
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
              : UpcomingMatchesView(
                  matches: _matches,
                  participants: _participants,
                  overrides: _ovr!,
                );

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
                    icon: Icon(Icons.event_outlined),
                    selectedIcon: Icon(Icons.event),
                    label: Text('Kampar'),
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
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event),
                  label: 'Kampar',
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

/// Sorteringsnøkkel: dato + tid (begge tekstsorterbare i openfootball).
String _sortKey(MatchInfo m) => '${m.date} ${m.time}';

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

class _UpcomingMatchesViewState extends State<UpcomingMatchesView> {
  bool _onlyUpcoming = true;

  @override
  Widget build(BuildContext context) {
    final ovr = widget.overrides;
    final all = [...widget.matches]
      ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
    final shown = _onlyUpcoming
        ? all.where((m) => actualResult(m, ovr) == null).toList()
        : all;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Kommande')),
              ButtonSegment(value: false, label: Text('Alle')),
            ],
            selected: {_onlyUpcoming},
            onSelectionChanged: (s) =>
                setState(() => _onlyUpcoming = s.first),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text('Ingen kampar å vise.'))
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (_, i) => _matchTile(shown[i]),
                ),
        ),
      ],
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
      trailing = Text(m.time,
          style: TextStyle(color: scheme.outline, fontWeight: FontWeight.w600));
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        title: Row(
          children: [
            Text(flagFor(m.team1), style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Expanded(
              child: Text('${m.team1} – ${m.team2}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 6),
            Text(flagFor(m.team2), style: const TextStyle(fontSize: 16)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('${_prettyDate(m.date)} · $label'),
        ),
        trailing: trailing,
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
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
      participant: _p,
      matches: _matches,
      winnerSide: (m) => winnerSideOf(m, _ovr),
    );
    return BracketView(
      matches: ko,
      highlight: _p.medals.values.toSet(),
    );
  }

  Widget _medalTab() {
    final actual = actualMedals(_matches, _ovr);
    return ListView(
      children: [
        _MedalCard(
          picks: _p.medals,
          actual: actual,
          points: medalPoints(_p.medals, actual),
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
    return ListView(
      children: [
        for (final g in keys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(g,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
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
      title: Text('${m.team1} – ${m.team2}'),
      subtitle: Text('${m.date} · ${m.ground}'
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
  final int points;
  const _MedalCard(
      {required this.picks, required this.actual, required this.points});

  @override
  Widget build(BuildContext context) {
    Widget row(String emoji, String place, String key) {
      final pick = picks[key] ?? '';
      final act = actual[key];
      final correct = act != null && act == pick;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
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

// ---- Sluttspeltre ----

const double _cardW = 200;
const double _cardH = 64;
const double _vGap = 16;
const double _colGap = 64;
const double _leftPad = 88;
const double _topPad = 48;

// Kampnummer per runde, ordna vertikalt slik at treet koplar seg pent.
const _rounds = <List<int>>[
  [74, 77, 73, 75, 83, 84, 81, 82, 76, 78, 79, 80, 86, 88, 85, 87],
  [89, 90, 93, 94, 91, 92, 95, 96],
  [97, 98, 99, 100],
  [101, 102],
  [104],
];
const _roundTitles = ['32-del', '16-del', 'Kvartfinale', 'Semifinale', 'Finale'];
const _thirdNum = 103;

double _colLeft(int r) => _leftPad + r * (_cardW + _colGap);

class BracketView extends StatelessWidget {
  final List<KoMatch> matches;
  final Set<String> highlight;
  const BracketView({super.key, required this.matches, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final byNum = {for (final m in matches) m.num: m};

    // Vertikale senter per runde.
    final centers = <List<double>>[];
    centers.add([
      for (var i = 0; i < 16; i++) _topPad + _cardH / 2 + i * (_cardH + _vGap)
    ]);
    for (var r = 1; r < _rounds.length; r++) {
      final prev = centers[r - 1];
      centers.add([
        for (var k = 0; k < _rounds[r].length; k++)
          (prev[2 * k] + prev[2 * k + 1]) / 2
      ]);
    }

    final totalH = _topPad + 16 * (_cardH + _vGap) + 90;
    final totalW = _colLeft(_rounds.length - 1) + _cardW + 40;
    final scheme = Theme.of(context).colorScheme;

    final cards = <Widget>[];
    for (var r = 0; r < _rounds.length; r++) {
      for (var k = 0; k < _rounds[r].length; k++) {
        final km = byNum[_rounds[r][k]];
        if (km == null) continue;
        cards.add(Positioned(
          left: _colLeft(r),
          top: centers[r][k] - _cardH / 2,
          child: _MatchCard(km: km, highlight: highlight),
        ));
      }
    }

    // Bronsefinale, plassert under finalen.
    final third = byNum[_thirdNum];
    if (third != null) {
      cards.add(Positioned(
        left: _colLeft(_rounds.length - 1),
        top: _topPad + 16 * (_cardH + _vGap) + 16,
        child: _MatchCard(km: third, highlight: highlight, title: '🥉 Bronsefinale'),
      ));
    }

    // Rundetitlar.
    final headers = <Widget>[
      for (var r = 0; r < _rounds.length; r++)
        Positioned(
          left: _colLeft(r),
          top: 10,
          width: _cardW,
          child: Text(_roundTitles[r],
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
        ),
    ];

    // Halvdel-merker i venstre marg.
    Widget halfLabel(int firstLeaf, String text, Color c) => Positioned(
          left: 0,
          top: centers[0][firstLeaf] - _cardH / 2,
          width: _leftPad - 10,
          height: 8 * (_cardH + _vGap),
          child: Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(text,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: c)),
            ),
          ),
        );

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: scheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: const Text(
            'Laga er dine tippa gruppevinnarar/2-arar. Spania, Frankrike og '
            'Argentina er utheva. Dra/scroll for å sjå heile treet — ekte lag '
            'fyller inn etter kvart som kampane blir spelt.',
            style: TextStyle(fontSize: 12),
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
                        painter: _ConnectorPainter(
                            centers, scheme.outlineVariant),
                      ),
                    ),
                    halfLabel(0, 'ØVRE HALVDEL', scheme.primary),
                    halfLabel(8, 'NEDRE HALVDEL', scheme.tertiary),
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
  final List<List<double>> centers;
  final Color color;
  _ConnectorPainter(this.centers, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (var r = 1; r < _rounds.length; r++) {
      final prevRight = _colLeft(r - 1) + _cardW;
      final curLeft = _colLeft(r);
      final midX = (prevRight + curLeft) / 2;
      for (var k = 0; k < _rounds[r].length; k++) {
        final yTop = centers[r - 1][2 * k];
        final yBot = centers[r - 1][2 * k + 1];
        final yCur = centers[r][k];
        canvas.drawLine(Offset(prevRight, yTop), Offset(midX, yTop), paint);
        canvas.drawLine(Offset(prevRight, yBot), Offset(midX, yBot), paint);
        canvas.drawLine(Offset(midX, yTop), Offset(midX, yBot), paint);
        canvas.drawLine(Offset(midX, yCur), Offset(curLeft, yCur), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) =>
      old.centers != centers || old.color != color;
}
