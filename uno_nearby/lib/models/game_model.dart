import 'card_model.dart';
import 'player_model.dart';

enum GameStatus { lobby, inProgress, roundEnd, gameOver }

enum Direction { clockwise, counterClockwise }

/// The single source of truth for a game in progress. The HOST owns the
/// canonical instance. Clients only ever hold the sanitized copy they
/// receive from [GameState.toClientJson] — they cannot construct or mutate
/// authoritative state themselves.
class GameState {
  final String gameId;
  final int round;
  final List<Player> players;
  final int currentPlayerSeat;
  final Direction direction;
  final CardColor currentColor;
  final UnoCard? topCard;
  final int deckCount;
  final List<UnoCard> discardPile;
  final GameStatus status;
  final int stateVersion; // monotonically increasing; clients reject stale versions
  final String? winnerId;
  final String? pendingWildPlayerId; // player who must choose a color
  final int drawStackCount; // accumulated +2/+4 stack to be resolved

  const GameState({
    required this.gameId,
    required this.round,
    required this.players,
    required this.currentPlayerSeat,
    required this.direction,
    required this.currentColor,
    required this.topCard,
    required this.deckCount,
    required this.discardPile,
    required this.status,
    required this.stateVersion,
    this.winnerId,
    this.pendingWildPlayerId,
    this.drawStackCount = 0,
  });

  Player get currentPlayer => players.firstWhere((p) => p.seat == currentPlayerSeat);

  GameState copyWith({
    int? round,
    List<Player>? players,
    int? currentPlayerSeat,
    Direction? direction,
    CardColor? currentColor,
    UnoCard? topCard,
    int? deckCount,
    List<UnoCard>? discardPile,
    GameStatus? status,
    int? stateVersion,
    String? winnerId,
    String? pendingWildPlayerId,
    bool clearPendingWild = false,
    int? drawStackCount,
  }) =>
      GameState(
        gameId: gameId,
        round: round ?? this.round,
        players: players ?? this.players,
        currentPlayerSeat: currentPlayerSeat ?? this.currentPlayerSeat,
        direction: direction ?? this.direction,
        currentColor: currentColor ?? this.currentColor,
        topCard: topCard ?? this.topCard,
        deckCount: deckCount ?? this.deckCount,
        discardPile: discardPile ?? this.discardPile,
        status: status ?? this.status,
        stateVersion: stateVersion ?? this.stateVersion,
        winnerId: winnerId ?? this.winnerId,
        pendingWildPlayerId:
            clearPendingWild ? null : (pendingWildPlayerId ?? this.pendingWildPlayerId),
        drawStackCount: drawStackCount ?? this.drawStackCount,
      );

  /// Full JSON including every player's private hand. Used only for the
  /// host's local persistence / the specific player it belongs to.
  Map<String, dynamic> toHostJson() => {
        'gameId': gameId,
        'round': round,
        'players': players.map((p) => p.toPrivateJson()).toList(),
        'currentPlayerSeat': currentPlayerSeat,
        'direction': direction.name,
        'currentColor': currentColor.name,
        'topCard': topCard?.toJson(),
        'deckCount': deckCount,
        'discardPile': discardPile.map((c) => c.toJson()).toList(),
        'status': status.name,
        'stateVersion': stateVersion,
        'winnerId': winnerId,
        'pendingWildPlayerId': pendingWildPlayerId,
        'drawStackCount': drawStackCount,
      };

  /// Sanitized copy sent to a specific client: every OTHER player's hand is
  /// redacted to just a count, so no client can ever see another player's
  /// cards. [forPlayerId] gets to see their own hand.
  Map<String, dynamic> toClientJson(String forPlayerId) => {
        'gameId': gameId,
        'round': round,
        'players': players
            .map((p) => p.id == forPlayerId ? p.toPrivateJson() : p.toPublicJson())
            .toList(),
        'currentPlayerSeat': currentPlayerSeat,
        'direction': direction.name,
        'currentColor': currentColor.name,
        'topCard': topCard?.toJson(),
        'deckCount': deckCount,
        'discardPile': discardPile.isEmpty ? [] : [discardPile.last.toJson()],
        'status': status.name,
        'stateVersion': stateVersion,
        'winnerId': winnerId,
        'pendingWildPlayerId': pendingWildPlayerId,
        'drawStackCount': drawStackCount,
      };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
        gameId: json['gameId'] as String,
        round: json['round'] as int,
        players: (json['players'] as List<dynamic>)
            .map((p) => Player.fromPrivateJson(p as Map<String, dynamic>))
            .toList(),
        currentPlayerSeat: json['currentPlayerSeat'] as int,
        direction: Direction.values.byName(json['direction'] as String),
        currentColor: CardColor.values.byName(json['currentColor'] as String),
        topCard:
            json['topCard'] != null ? UnoCard.fromJson(json['topCard'] as Map<String, dynamic>) : null,
        deckCount: json['deckCount'] as int,
        discardPile: (json['discardPile'] as List<dynamic>)
            .map((c) => UnoCard.fromJson(c as Map<String, dynamic>))
            .toList(),
        status: GameStatus.values.byName(json['status'] as String),
        stateVersion: json['stateVersion'] as int,
        winnerId: json['winnerId'] as String?,
        pendingWildPlayerId: json['pendingWildPlayerId'] as String?,
        drawStackCount: json['drawStackCount'] as int? ?? 0,
      );
}
