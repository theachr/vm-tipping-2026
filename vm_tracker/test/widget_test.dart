import 'package:flutter_test/flutter_test.dart';
import 'package:vm_tracker/scoring.dart';
import 'package:vm_tracker/models.dart';

void main() {
  group('matchPoints', () {
    test('eksakt resultat gir 3', () {
      expect(matchPoints(pred1: 2, pred2: 1, act1: 2, act2: 1), 3);
      expect(matchPoints(pred1: 1, pred2: 1, act1: 1, act2: 1), 3);
    });
    test('riktig vinnar feil siffer gir 1', () {
      expect(matchPoints(pred1: 2, pred2: 1, act1: 3, act2: 0), 1);
      expect(matchPoints(pred1: 0, pred2: 2, act1: 1, act2: 3), 1);
    });
    test('riktig uavgjort feil siffer gir 1', () {
      expect(matchPoints(pred1: 1, pred2: 1, act1: 2, act2: 2), 1);
    });
    test('feil utfall gir 0', () {
      expect(matchPoints(pred1: 2, pred2: 1, act1: 0, act2: 1), 0);
      expect(matchPoints(pred1: 1, pred2: 1, act1: 2, act2: 0), 0);
    });
  });

  group('medalPoints', () {
    final picks = {'gold': 'Spain', 'silver': 'France', 'bronze': 'Argentina'};
    test('alt riktig gir 9', () {
      expect(
          medalPoints(picks,
              {'gold': 'Spain', 'silver': 'France', 'bronze': 'Argentina'}),
          9);
    });
    test('riktig lag feil plassering gir 1 kvar', () {
      // Spania tar sølv, Frankrike gull -> begge feil plass men medalje = 1+1; Argentina bronse riktig = 3
      expect(
          medalPoints(picks,
              {'gold': 'France', 'silver': 'Spain', 'bronze': 'Argentina'}),
          5);
    });
    test('lag heilt utanfor gir 0', () {
      expect(
          medalPoints(picks,
              {'gold': 'Brazil', 'silver': 'England', 'bronze': 'Portugal'}),
          0);
    });
    test('venter (null) gir 0', () {
      expect(medalPoints(picks, {'gold': null, 'silver': null, 'bronze': null}),
          0);
    });
  });

  group('MatchInfo', () {
    test('parsar og reknar vinnar etter straffer', () {
      final m = MatchInfo.fromJson({
        'num': 104,
        'round': 'Final',
        'team1': 'Spain',
        'team2': 'France',
        'group': '',
        'score': {
          'ft': [1, 1],
          'et': [1, 1],
          'p': [4, 2],
        },
      });
      expect(m.played, true);
      expect(m.winnerSide, 1);
    });
    test('uavgjort i gruppespel', () {
      final m = MatchInfo.fromJson({
        'num': 1,
        'team1': 'A',
        'team2': 'B',
        'group': 'Group A',
        'score': {
          'ft': [0, 0],
        },
      });
      expect(m.winnerSide, 0);
      expect(m.isGroup, true);
    });
  });
}
