import 'dart:math';
import '../core/constants/constants.dart';
import '../models/card_model.dart';
import '../models/game_model.dart';
import '../models/player_model.dart';
import 'deck.dart';
import 'game_rules.dart';

class EngineResult {
  final GameState state;
  final String? error; // non-null when the requested action was rejected
  const EngineResult(this.state, {this.error});
  bool get ok => error == null;
}

/// The single authoritative game engine. Only the HOST ever holds and
/// mutates a live instance of this class — clients never construct one.
/// Every public method validates the request against [state] before
/// applying it, and returns a rejection instead of throwing so the host can
/// send the caller an ERROR message rather than crash.
class GameEngine {
  GameState state;
  final List<UnoCard> _drawPile = [];
  final Random _random;
  final UnoPenaltyRule unoPenalty;
  final DrawRule drawRule;

  GameEngine({
    required this.state,
    UnoPenaltyRule? unoPenalty,
    DrawRule? drawRule,
    Random? random,
    List<UnoCard>? initialDrawPile,
  })  : unoPenalty = unoPenalty ?? UnoPenaltyRule.drawTwo,
        drawRule = drawRule ?? DrawRule.playImmediately,
        _random = random ?? Random.secure() {
    // initialDrawPile exists purely so unit tests can construct an engine
    // with a fully known, deterministic state (hands + draw pile) without
    // going through the random deal in startNewGame(). Production code
    // never passes this — it always goes through startNewGame().
    if (initialDrawPile != null) _drawPile.addAll(initialDrawPile);
  }

  /// Builds a fresh round: shuffles a new deck, deals [AppConstants.
  /// startingHandSize] cards to every player, and flips the first card
  /// (redrawing if it's a Wild Draw Four, and applying the effect if it's
  /// an action card, per standard house rules).
  static GameEngine startNewGame({
    required String gameId,
    required List<Player> players,
    UnoPenaltyRule unoPenalty = UnoPenaltyRule.drawTwo,
    DrawRule drawRule = DrawRule.playImmediately,
    Random? random,
  }) {
    final rng = random ?? Random.secure();
    final engine = GameEngine(
      state: GameState(
        gameId: gameId,
        round: 1,
        players: players,
        currentPlayerSeat: 0,
        direction: Direction.clockwise,
        currentColor: CardColor.red,
        topCard: null,
        deckCount: 0,
        discardPile: const [],
        status: GameStatus.inProgress,
        stateVersion: 0,
      ),
      unoPenalty: unoPenalty,
      drawRule: drawRule,
      random: rng,
    );
    engine._dealNewRound();
    return engine;
  }

  void _dealNewRound() {
    _drawPile
      ..clear()
      ..addAll(Deck.shuffled(_random));

    var players = state.players
        .map((p) => p.copyWith(hand: const [], hasCalledUno: false, roundScore: 0))
        .toList();

    for (int i = 0; i < AppConstants.startingHandSize; i++) {
      for (int s = 0; s < players.length; s++) {
        final card = _drawPile.removeLast();
        players[s] = players[s].copyWith(hand: [...players[s].hand, card]);
      }
    }

    // Flip the first discard. Redraw on Wild Draw Four (invalid opener).
    UnoCard first = _drawPile.removeLast();
    while (first.type == CardType.wildDrawFour) {
      _drawPile.insert(0, first);
      first = _drawPile.removeLast();
    }

    CardColor startColor = first.effectiveColor;
    Direction direction = Direction.clockwise;
    int startSeat = 0;

    // Apply opener's action effect per standard house rules.
    switch (first.type) {
      case CardType.reverse:
        direction = Direction.counterClockwise;
        startSeat = GameRules.nextSeat(0, players.length, direction);
        break;
      case CardType.skip:
        startSeat = GameRules.nextSeat(0, players.length, direction, advance: 2);
        break;
      case CardType.drawTwo:
        final victim = GameRules.nextSeat(0, players.length, direction);
        players[victim] = players[victim].copyWith(
          hand: [...players[victim].hand, _drawPile.removeLast(), _drawPile.removeLast()],
        );
        startSeat = GameRules.nextSeat(victim, players.length, direction);
        break;
      case CardType.wild:
        startColor = CardColor.values[_random.nextInt(4)]; // engine auto-picks for the opener
        break;
      default:
        break;
    }

    state = state.copyWith(
      players: players,
      currentPlayerSeat: startSeat,
      direction: direction,
      currentColor: startColor,
      topCard: first,
      deckCount: _drawPile.length,
      discardPile: [first],
      status: GameStatus.inProgress,
      stateVersion: state.stateVersion + 1,
      clearPendingWild: true,
      drawStackCount: 0,
    );
  }

  Player _playerById(String id) => state.players.firstWhere((p) => p.id == id,
      orElse: () => throw StateError('Unknown player $id'));

  // ---------------------------------------------------------------------
  // PLAY CARD
  // ---------------------------------------------------------------------
  EngineResult playCard({required String playerId, required String cardId, CardColor? chosenColor}) {
    if (state.status != GameStatus.inProgress) {
      return EngineResult(state, error: 'Game is not in progress.');
    }
    final player = _playerById(playerId);
    if (player.seat != state.currentPlayerSeat) {
      return EngineResult(state, error: 'It is not your turn.');
    }
    if (state.pendingWildPlayerId != null) {
      return EngineResult(state, error: 'Waiting for a color choice.');
    }

    final card = player.hand.firstWhere((c) => c.id == cardId,
        orElse: () => throw StateError('not found'));
    if (!player.hand.contains(card)) {
      return EngineResult(state, error: 'You do not hold that card.');
    }
    if (!GameRules.isPlayable(card, state.topCard, state.currentColor)) {
      return EngineResult(state, error: 'That card cannot be played right now.');
    }

    // Draw-stack rule: if a +2/+4 is pending, only a stackable card of the
    // same escalation type may be played; otherwise the player must draw.
    if (state.drawStackCount > 0) {
      final stackable = (card.type == CardType.drawTwo || card.type == CardType.wildDrawFour);
      if (!stackable) {
        return EngineResult(state, error: 'You must draw ${state.drawStackCount} cards or stack a Draw card.');
      }
    }

    var players = [...state.players];
    final newHand = [...player.hand]..removeWhere((c) => c.id == cardId);
    players[player.seat] = player.copyWith(hand: newHand, hasCalledUno: newHand.length == 1 ? player.hasCalledUno : false);

    var discard = [...state.discardPile, card];
    var direction = state.direction;
    int nextSeat = state.currentPlayerSeat;
    CardColor color = card.effectiveColor;
    int drawStack = state.drawStackCount;
    String? pendingWild;

    // A Wild Draw Four's +4 is accumulated as soon as the card hits the
    // table, independently of whether the color has been chosen yet — the
    // pending-color path below must not swallow it.
    if (card.type == CardType.wildDrawFour) drawStack += 4;

    if (card.isWild && chosenColor == null) {
      // Client must send a follow-up chooseColor message before the turn
      // advances. We persist state now so the UI reflects the played card.
      pendingWild = playerId;
      color = state.currentColor; // unresolved yet
    } else {
      if (card.isWild) color = chosenColor!;

      switch (card.type) {
        case CardType.skip:
          nextSeat = GameRules.nextSeat(state.currentPlayerSeat, players.length, direction, advance: 2);
          break;
        case CardType.reverse:
          direction = GameRules.reversedDirection(direction);
          // In a 2-player game, Reverse behaves like Skip.
          final advance = players.length == 2 ? 2 : 1;
          nextSeat = GameRules.nextSeat(state.currentPlayerSeat, players.length, direction, advance: advance);
          break;
        case CardType.drawTwo:
          drawStack += 2;
          nextSeat = GameRules.nextSeat(state.currentPlayerSeat, players.length, direction);
          break;
        case CardType.wildDrawFour:
          // +4 already accumulated above, before the pending-color branch.
          nextSeat = GameRules.nextSeat(state.currentPlayerSeat, players.length, direction);
          break;
        default:
          nextSeat = GameRules.nextSeat(state.currentPlayerSeat, players.length, direction);
      }
    }

    state = state.copyWith(
      players: players,
      topCard: card,
      discardPile: discard,
      direction: direction,
      currentColor: color,
      currentPlayerSeat: pendingWild != null ? state.currentPlayerSeat : nextSeat,
      pendingWildPlayerId: pendingWild,
      clearPendingWild: pendingWild == null,
      drawStackCount: drawStack,
      stateVersion: state.stateVersion + 1,
    );

    // UNO penalty check: if the player now has exactly 1 card and never
    // called UNO for it, apply the configured penalty immediately.
    if (newHand.length == 1 && !player.hasCalledUno && unoPenalty != UnoPenaltyRule.off) {
      _applyUnoPenalty(playerId);
    }

    if (newHand.isEmpty) {
      _finishRound(winnerId: playerId);
    }

    return EngineResult(state);
  }

  EngineResult chooseColor({required String playerId, required CardColor color}) {
    if (state.pendingWildPlayerId != playerId) {
      return EngineResult(state, error: 'No color choice is pending for you.');
    }
    if (color == CardColor.wild) {
      return EngineResult(state, error: 'Choose a real color.');
    }
    final player = _playerById(playerId);
    // Both Wild and Wild Draw Four advance one seat here; the Draw Four's
    // +4 was already pushed onto drawStackCount when the card was played,
    // and the next player resolves it by drawing.
    final nextSeat =
        GameRules.nextSeat(state.currentPlayerSeat, state.players.length, state.direction);

    state = state.copyWith(
      currentColor: color,
      currentPlayerSeat: nextSeat,
      clearPendingWild: true,
      stateVersion: state.stateVersion + 1,
    );

    if (player.hand.isEmpty) {
      _finishRound(winnerId: playerId);
    }

    return EngineResult(state);
  }

  // ---------------------------------------------------------------------
  // DRAW CARD
  // ---------------------------------------------------------------------
  EngineResult drawCard({required String playerId}) {
    if (state.status != GameStatus.inProgress) {
      return EngineResult(state, error: 'Game is not in progress.');
    }
    final player = _playerById(playerId);
    if (player.seat != state.currentPlayerSeat) {
      return EngineResult(state, error: 'It is not your turn.');
    }

    final toDraw = state.drawStackCount > 0 ? state.drawStackCount : 1;
    final drawn = <UnoCard>[];
    for (int i = 0; i < toDraw; i++) {
      drawn.add(_drawCardFromPile());
    }

    var players = [...state.players];
    players[player.seat] = player.copyWith(hand: [...player.hand, ...drawn]);

    final resolvedStack = state.drawStackCount > 0;
    final nextSeat = resolvedStack || drawRule == DrawRule.passAfterDraw
        ? GameRules.nextSeat(state.currentPlayerSeat, players.length, state.direction)
        : state.currentPlayerSeat; // playImmediately: same player may now play the drawn card

    state = state.copyWith(
      players: players,
      deckCount: _drawPile.length,
      drawStackCount: 0,
      currentPlayerSeat: nextSeat,
      stateVersion: state.stateVersion + 1,
    );

    return EngineResult(state);
  }

  UnoCard _drawCardFromPile() {
    if (_drawPile.isEmpty) _reshuffleDiscardIntoDrawPile();
    return _drawPile.removeLast();
  }

  void _reshuffleDiscardIntoDrawPile() {
    if (state.discardPile.length <= 1) {
      // Degenerate case: nothing to reshuffle. Should not normally happen
      // with a 108-card deck, but guard against an infinite loop.
      return;
    }
    final top = state.discardPile.last;
    final rest = state.discardPile.sublist(0, state.discardPile.length - 1);
    _drawPile.addAll(rest.map((c) => c.isWild ? c.copyWith() : c));
    _drawPile.shuffle(_random);
    state = state.copyWith(discardPile: [top]);
  }

  // ---------------------------------------------------------------------
  // UNO CALL
  // ---------------------------------------------------------------------
  EngineResult callUno({required String playerId}) {
    final player = _playerById(playerId);
    var players = [...state.players];
    players[player.seat] = player.copyWith(hasCalledUno: true);
    state = state.copyWith(players: players, stateVersion: state.stateVersion + 1);
    return EngineResult(state);
  }

  /// Called by the host when another player "catches" someone with one
  /// card who never called UNO (or automatically, immediately after the
  /// triggering play — see [playCard]).
  void _applyUnoPenalty(String playerId) {
    final penaltyCount = unoPenalty == UnoPenaltyRule.drawFour ? 4 : 2;
    final player = _playerById(playerId);
    final drawn = List.generate(penaltyCount, (_) => _drawCardFromPile());
    var players = [...state.players];
    players[player.seat] = player.copyWith(hand: [...player.hand, ...drawn]);
    state = state.copyWith(players: players, deckCount: _drawPile.length, stateVersion: state.stateVersion + 1);
  }

  // ---------------------------------------------------------------------
  // ROUND / GAME END
  // ---------------------------------------------------------------------
  void _finishRound({required String winnerId}) {
    final points = state.players
        .where((p) => p.id != winnerId)
        .fold<int>(0, (sum, p) => sum + p.hand.fold(0, (s, c) => s + c.scoreValue));

    var players = state.players.map((p) {
      if (p.id == winnerId) {
        return p.copyWith(roundScore: points, totalScore: p.totalScore + points);
      }
      return p;
    }).toList();

    // Standard house rule: first to 500 total points wins the match.
    final matchWinner = players.where((p) => p.totalScore >= 500).toList()
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    state = state.copyWith(
      players: players,
      status: matchWinner.isNotEmpty ? GameStatus.gameOver : GameStatus.roundEnd,
      winnerId: winnerId,
      stateVersion: state.stateVersion + 1,
    );
  }

  /// Starts the next round after a [GameStatus.roundEnd], rotating the
  /// starting dealer seat by one.
  void startNextRound() {
    state = state.copyWith(round: state.round + 1, winnerId: null, clearPendingWild: true);
    _dealNewRound();
  }
}
