import '../models/card_model.dart';
import '../models/game_model.dart';

/// Stateless rules helpers. The [GameEngine] is the only thing allowed to
/// apply these to authoritative state, but keeping them pure and separate
/// makes them trivial to unit test in isolation.
class GameRules {
  GameRules._();

  /// A card is playable on top of [topCard] with the table's current
  /// [currentColor] when:
  ///   - it's a wild card (always legal to play, subject to WD4 restriction
  ///     enforced separately in the engine), OR
  ///   - its color matches the current color, OR
  ///   - its number matches the top card's number (number cards only), OR
  ///   - its action type matches the top card's action type
  static bool isPlayable(UnoCard card, UnoCard? topCard, CardColor currentColor) {
    if (topCard == null) return true; // first card of the game
    if (card.isWild) return true;

    if (card.color == currentColor) return true;

    if (card.type == CardType.number &&
        topCard.type == CardType.number &&
        card.number == topCard.number) {
      return true;
    }

    if (card.isAction && card.type == topCard.type) return true;

    return false;
  }

  /// Wild Draw Four is only legal, under strict tournament rules, if the
  /// player has no other card matching the current color in hand. We
  /// implement the commonly-used "trust" variant: it's always playable,
  /// but flagged here so the engine/UI can optionally challenge it. This
  /// keeps games from stalling on edge cases while still tracking whether
  /// the play was "clean" for anti-cheat/statistics purposes.
  static bool isWildDrawFourClean(List<UnoCard> hand, CardColor currentColor) {
    return !hand.any((c) => !c.isWild && c.color == currentColor);
  }

  static Direction reversedDirection(Direction d) =>
      d == Direction.clockwise ? Direction.counterClockwise : Direction.clockwise;

  /// Computes the next seat index given [currentSeat], [playerCount],
  /// [direction], and how many seats to [advance] by (2 for a Skip / an
  /// effective double-step in 2-player Reverse, 1 otherwise).
  static int nextSeat(int currentSeat, int playerCount, Direction direction, {int advance = 1}) {
    final step = direction == Direction.clockwise ? 1 : -1;
    int seat = currentSeat;
    for (int i = 0; i < advance; i++) {
      seat = (seat + step) % playerCount;
      if (seat < 0) seat += playerCount;
    }
    return seat;
  }
}
