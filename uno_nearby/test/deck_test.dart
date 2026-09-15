import 'package:flutter_test/flutter_test.dart';
import 'package:uno_nearby/game/deck.dart';
import 'package:uno_nearby/models/card_model.dart';

void main() {
  group('Deck', () {
    test('builds exactly 108 cards', () {
      expect(Deck.buildFullDeck().length, 108);
    });

    test('has 4 colors x 25 cards + 8 wild cards', () {
      final deck = Deck.buildFullDeck();
      for (final color in [CardColor.red, CardColor.blue, CardColor.green, CardColor.yellow]) {
        expect(deck.where((c) => c.color == color).length, 25);
      }
      expect(deck.where((c) => c.color == CardColor.wild).length, 8);
    });

    test('has exactly one 0 per color and two of each 1-9', () {
      final deck = Deck.buildFullDeck();
      for (final color in [CardColor.red, CardColor.blue, CardColor.green, CardColor.yellow]) {
        expect(deck.where((c) => c.color == color && c.number == 0).length, 1);
        for (int n = 1; n <= 9; n++) {
          expect(deck.where((c) => c.color == color && c.number == n).length, 2);
        }
      }
    });

    test('has 4 Wild and 4 Wild Draw Four cards', () {
      final deck = Deck.buildFullDeck();
      expect(deck.where((c) => c.type == CardType.wild).length, 4);
      expect(deck.where((c) => c.type == CardType.wildDrawFour).length, 4);
    });

    test('shuffled() preserves composition but changes order with overwhelming probability', () {
      final a = Deck.buildFullDeck();
      final b = Deck.shuffled();
      expect(b.length, a.length);
      expect(b.map((c) => c.id).toSet().length, 108); // all unique ids
      // Extremely unlikely a fresh shuffle matches build order exactly.
      final sameOrder = List.generate(a.length, (i) => a[i].color == b[i].color && a[i].type == b[i].type)
          .every((eq) => eq);
      expect(sameOrder, isFalse);
    });
  });
}
