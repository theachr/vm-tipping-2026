// Poenglogikk for tippekupongen.
// Reglar: riktig resultat = 3, riktig vinnar (feil siffer) = 1, elles 0.
// Medaljar: riktig lag + plassering = 3, riktig lag men feil plassering = 1.

int _sign(int a, int b) => a == b ? 0 : (a > b ? 1 : -1);

/// Poeng for éin kamp. Tippa og faktiske mål må vere orientert likt (team1, team2).
int matchPoints({
  required int pred1,
  required int pred2,
  required int act1,
  required int act2,
}) {
  if (pred1 == act1 && pred2 == act2) return 3;
  if (_sign(pred1, pred2) == _sign(act1, act2)) return 1;
  return 0;
}

/// Poeng for medaljar. picks/actual har nøklane 'gold','silver','bronze'.
/// actual-verdiar kan vere null før sluttspelet er avgjort.
int medalPoints(Map<String, String> picks, Map<String, String?> actual) {
  final actualMedalists =
      actual.values.whereType<String>().toSet();
  var total = 0;
  for (final place in const ['gold', 'silver', 'bronze']) {
    final pick = picks[place];
    if (pick == null) continue;
    if (actual[place] == pick) {
      total += 3;
    } else if (actualMedalists.contains(pick)) {
      total += 1;
    }
  }
  return total;
}
