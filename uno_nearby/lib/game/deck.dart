import 'dart:math';
import '../models/card_model.dart';

/// Builds and shuffles a standard 108-card UNO-style deck.
///
/// Composition (standard rules):
///  - 4 colors x (one 0, two of each 1-9)               = 4 x 19 = 76
///  - 4 colors x (two Skip, two Reverse, two Draw Two)   = 4 x 6  = 24
///  - 4 Wild + 4 Wild Draw Four                          = 8
///  Total                                                = 108
class Deck {
  static const _colors = [CardColor.red, CardColor.blue, CardColor.green, CardColor.yellow];

  static List<UnoCard> buildFullDeck() {
    final cards = <UnoCard>[];

    for (final color in _colors) {
      cards.add(UnoCard(color: color, type: CardType.number, number: 0));
      for (int n = 1; n <= 9; n++) {
        cards.add(UnoCard(color: color, type: CardType.number, number: n));
        cards.add(UnoCard(color: color, type: CardType.number, number: n));
      }
      for (int i = 0; i < 2; i++) {
        cards.add(UnoCard(color: color, type: CardType.skip));
        cards.add(UnoCard(color: color, type: CardType.reverse));
        cards.add(UnoCard(color: color, type: CardType.drawTwo));
      }
    }

    for (int i = 0; i < 4; i++) {
      cards.add(UnoCard(color: CardColor.wild, type: CardType.wild));
      cards.add(UnoCard(color: CardColor.wild, type: CardType.wildDrawFour));
    }

    return cards;
  }

  static List<UnoCard> shuffled([Random? random]) {
    final rng = random ?? Random.secure();
    final cards = buildFullDeck();
    cards.shuffle(rng);
    return cards;
  }
}
