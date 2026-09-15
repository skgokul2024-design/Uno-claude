import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum CardColor { red, blue, green, yellow, wild }

enum CardType {
  number, // value 0-9
  skip,
  reverse,
  drawTwo,
  wild,
  wildDrawFour,
}

/// A single UNO-style card. Immutable value object — every mutation (e.g.
/// choosing a color for a wild card) returns a new instance via [copyWith].
class UnoCard {
  final String id;
  final CardColor color;
  final CardType type;
  final int? number; // only meaningful when type == CardType.number

  /// For wild cards that have been played, the color the player chose.
  /// Null until chosen.
  final CardColor? chosenColor;

  UnoCard({
    String? id,
    required this.color,
    required this.type,
    this.number,
    this.chosenColor,
  }) : id = id ?? _uuid.v4();

  bool get isWild => color == CardColor.wild;
  bool get isAction =>
      type == CardType.skip || type == CardType.reverse || type == CardType.drawTwo;

  /// The color to use for matching purposes — the chosen color if this is a
  /// played wild card, otherwise the card's own color.
  CardColor get effectiveColor => chosenColor ?? color;

  UnoCard copyWith({CardColor? chosenColor}) => UnoCard(
        id: id,
        color: color,
        type: type,
        number: number,
        chosenColor: chosenColor ?? this.chosenColor,
      );

  /// Point value used for scoring the loser's remaining hand (standard UNO
  /// scoring): number cards = face value, action cards = 20, wilds = 50.
  int get scoreValue {
    switch (type) {
      case CardType.number:
        return number ?? 0;
      case CardType.skip:
      case CardType.reverse:
      case CardType.drawTwo:
        return 20;
      case CardType.wild:
      case CardType.wildDrawFour:
        return 50;
    }
  }

  String get displayLabel {
    switch (type) {
      case CardType.number:
        return '${number ?? 0}';
      case CardType.skip:
        return 'SKIP';
      case CardType.reverse:
        return 'REVERSE';
      case CardType.drawTwo:
        return '+2';
      case CardType.wild:
        return 'WILD';
      case CardType.wildDrawFour:
        return 'WILD +4';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'color': color.name,
        'type': type.name,
        'number': number,
        'chosenColor': chosenColor?.name,
      };

  factory UnoCard.fromJson(Map<String, dynamic> json) => UnoCard(
        id: json['id'] as String,
        color: CardColor.values.byName(json['color'] as String),
        type: CardType.values.byName(json['type'] as String),
        number: json['number'] as int?,
        chosenColor: json['chosenColor'] != null
            ? CardColor.values.byName(json['chosenColor'] as String)
            : null,
      );

  @override
  String toString() => 'UnoCard(${color.name} $displayLabel)';

  @override
  bool operator ==(Object other) => other is UnoCard && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
