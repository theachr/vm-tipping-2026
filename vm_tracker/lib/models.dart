/// Datamodellar for VM 2026-kampar (kjelde: openfootball/worldcup.json).
class MatchInfo {
  final int num;
  final String round, date, time, group, ground, team1, team2;
  final int? score1, score2; // full tid (90 min)
  final int? score1et, score2et; // etter ekstraomgangar
  final int? score1p, score2p; // straffer

  const MatchInfo({
    required this.num,
    required this.round,
    required this.date,
    required this.time,
    required this.group,
    required this.ground,
    required this.team1,
    required this.team2,
    this.score1,
    this.score2,
    this.score1et,
    this.score2et,
    this.score1p,
    this.score2p,
  });

  bool get isGroup => group.startsWith('Group');
  bool get played => score1 != null && score2 != null;

  MatchInfo copyWith({int? score1, int? score2}) => MatchInfo(
        num: num,
        round: round,
        date: date,
        time: time,
        group: group,
        ground: ground,
        team1: team1,
        team2: team2,
        score1: score1 ?? this.score1,
        score2: score2 ?? this.score2,
        score1et: score1et,
        score2et: score2et,
        score1p: score1p,
        score2p: score2p,
      );

  /// 1 = team1 vinn, 2 = team2 vinn, 0 = uavgjort (berre gruppespel). null = ikkje spelt.
  int? get winnerSide {
    if (score1p != null && score2p != null) {
      if (score1p! > score2p!) return 1;
      if (score2p! > score1p!) return 2;
    }
    if (score1et != null && score2et != null && score1et! != score2et!) {
      return score1et! > score2et! ? 1 : 2;
    }
    if (score1 != null && score2 != null) {
      if (score1! > score2!) return 1;
      if (score2! > score1!) return 2;
      return 0;
    }
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  // openfootball lagrar resultat som eit nøsta objekt:
  // "score": {"ft":[a,b], "ht":[a,b], "et":[a,b], "p":[a,b]}
  // ft = full tid, et = etter ekstraomgangar (kumulativt), p = straffer.
  static int? _side(dynamic score, String key, int idx) {
    if (score is Map && score[key] is List) {
      final list = score[key] as List;
      if (idx < list.length) return _toInt(list[idx]);
    }
    return null;
  }

  factory MatchInfo.fromJson(Map<String, dynamic> j) {
    final score = j['score'];
    return MatchInfo(
      num: _toInt(j['num']) ?? 0,
      round: (j['round'] ?? '').toString(),
      date: (j['date'] ?? '').toString(),
      time: (j['time'] ?? '').toString(),
      group: (j['group'] ?? '').toString(),
      ground: (j['ground'] ?? '').toString(),
      team1: (j['team1'] ?? '').toString(),
      team2: (j['team2'] ?? '').toString(),
      score1: _side(score, 'ft', 0),
      score2: _side(score, 'ft', 1),
      score1et: _side(score, 'et', 0),
      score2et: _side(score, 'et', 1),
      score1p: _side(score, 'p', 0),
      score2p: _side(score, 'p', 1),
    );
  }
}
