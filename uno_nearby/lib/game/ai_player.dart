import 'dart:math';
import '../models/card_model.dart';
import '../models/game_model.dart';
import '../models/player_model.dart';
import 'game_engine.dart';
import 'game_rules.dart';

/// Rule-based (non-networked) AI. Runs locally inside the host process for
/// any seat whose [Player.kind] is [PlayerKind.ai] — the AI is just another
/// "caller" of [GameEngine], obeying the exact same validation as a human
/// or remote client. It never bends the rules.
class AiPlayer {
  final Random _random;
  AiPlayer({Random? random}) : _random = random ?? Random();

  /// Decides and executes this AI's turn against [engine]. Safe to call
  /// repeatedly; it is a no-op if it isn't this player's turn.
  void takeTurn(GameEngine engine, String aiPlayerId) {
    final state = engine.state;
    final player = state.players.firstWhere((p) => p.id == aiPlayerId);
    if (player.seat != state.currentPlayerSeat) return;
    if (state.status != GameStatus.inProgress) return;

    if (state.pendingWildPlayerId == aiPlayerId) {
      engine.chooseColor(playerId: aiPlayerId, color: _bestColorFor(player));
      return;
    }

    final playable = player.hand
        .where((c) => GameRules.isPlayable(c, state.topCard, state.currentColor))
        .where((c) {
      if (state.drawStackCount == 0) return true;
      return c.type == CardType.drawTwo || c.type == CardType.wildDrawFour;
    }).toList();

    if (playable.isEmpty) {
      engine.drawCard(playerId: aiPlayerId);
      // If a card can now be played immediately (playImmediately rule),
      // a follow-up takeTurn call (triggered by the host loop) will play it.
      return;
    }

    final chosen = _chooseBestCard(playable, player.hand.length);
    final needsColor = chosen.isWild;
    // Wilds are played with no color yet — the engine parks them in
    // pendingWildPlayerId, resolved by the chooseColor call just below.
    engine.playCard(playerId: aiPlayerId, cardId: chosen.id);

    if (needsColor) {
      engine.chooseColor(playerId: aiPlayerId, color: _bestColorFor(player, excluding: chosen));
    }

    // Auto-call UNO the instant the AI reaches one card, so it's never
    // caught by the penalty rule itself.
    final updated = engine.state.players.firstWhere((p) => p.id == aiPlayerId);
    if (updated.hand.length == 1 && !updated.hasCalledUno) {
      engine.callUno(playerId: aiPlayerId);
    }
  }

  /// Preference order: action cards first (to disrupt opponents), then
  /// highest-value number cards, keeping wilds in reserve for when the AI
  /// has no colored alternative.
  UnoCard _chooseBestCard(List<UnoCard> playable, int handSize) {
    final nonWild = playable.where((c) => !c.isWild).toList();
    final pool = nonWild.isNotEmpty ? nonWild : playable;

    pool.sort((a, b) {
      int rank(UnoCard c) {
        switch (c.type) {
          case CardType.wildDrawFour:
            return 0;
          case CardType.drawTwo:
            return 1;
          case CardType.skip:
          case CardType.reverse:
            return 2;
          case CardType.wild:
            return 3;
          case CardType.number:
            return 4;
        }
      }
      return rank(a).compareTo(rank(b));
    });
    return pool.first;
  }

  /// Chooses the color the AI holds the most of (a simple but effective
  /// heuristic), excluding a card it just played.
  CardColor _bestColorFor(Player player, {UnoCard? excluding}) {
    final counts = <CardColor, int>{
      CardColor.red: 0,
      CardColor.blue: 0,
      CardColor.green: 0,
      CardColor.yellow: 0,
    };
    for (final c in player.hand) {
      if (c == excluding || c.isWild) continue;
      counts[c.color] = (counts[c.color] ?? 0) + 1;
    }
    final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    return best.value > 0 ? best.key : CardColor.values[_random.nextInt(4)];
  }
}
