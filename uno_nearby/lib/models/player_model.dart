import 'card_model.dart';

enum PlayerConnectionState { connected, reconnecting, disconnected }

enum PlayerKind { human, ai }

class Player {
  final String id; // stable across reconnects
  final String name;
  final PlayerKind kind;
  final int seat; // turn order index

  final List<UnoCard> hand;
  final bool hasCalledUno;
  final int roundScore;
  final int totalScore;
  final PlayerConnectionState connectionState;

  const Player({
    required this.id,
    required this.name,
    required this.seat,
    this.kind = PlayerKind.human,
    this.hand = const [],
    this.hasCalledUno = false,
    this.roundScore = 0,
    this.totalScore = 0,
    this.connectionState = PlayerConnectionState.connected,
  });

  int get cardCount => hand.length;
  bool get isAi => kind == PlayerKind.ai;

  Player copyWith({
    String? name,
    List<UnoCard>? hand,
    bool? hasCalledUno,
    int? roundScore,
    int? totalScore,
    PlayerConnectionState? connectionState,
  }) =>
      Player(
        id: id,
        name: name ?? this.name,
        seat: seat,
        kind: kind,
        hand: hand ?? this.hand,
        hasCalledUno: hasCalledUno ?? this.hasCalledUno,
        roundScore: roundScore ?? this.roundScore,
        totalScore: totalScore ?? this.totalScore,
        connectionState: connectionState ?? this.connectionState,
      );

  /// Public view of this player — safe to send to every client. Hides the
  /// actual hand contents, exposing only the count.
  Map<String, dynamic> toPublicJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'seat': seat,
        'cardCount': cardCount,
        'hasCalledUno': hasCalledUno,
        'roundScore': roundScore,
        'totalScore': totalScore,
        'connectionState': connectionState.name,
      };

  /// Full private view — only ever sent to the player themselves (or kept
  /// server-side on the host).
  Map<String, dynamic> toPrivateJson() => {
        ...toPublicJson(),
        'hand': hand.map((c) => c.toJson()).toList(),
      };

  factory Player.fromPrivateJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['name'] as String,
        seat: json['seat'] as int,
        kind: PlayerKind.values.byName(json['kind'] as String? ?? 'human'),
        hand: (json['hand'] as List<dynamic>? ?? [])
            .map((c) => UnoCard.fromJson(c as Map<String, dynamic>))
            .toList(),
        hasCalledUno: json['hasCalledUno'] as bool? ?? false,
        roundScore: json['roundScore'] as int? ?? 0,
        totalScore: json['totalScore'] as int? ?? 0,
        connectionState:
            PlayerConnectionState.values.byName(json['connectionState'] as String? ?? 'connected'),
      );
}
