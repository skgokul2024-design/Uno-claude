import 'package:flutter_test/flutter_test.dart';
import 'package:uno_nearby/game/game_rules.dart';
import 'package:uno_nearby/models/card_model.dart';
import 'package:uno_nearby/models/game_model.dart';

UnoCard _num(CardColor c, int n) => UnoCard(color: c, type: CardType.number, number: n);

void main() {
  group('GameRules.isPlayable', () {
    test('any card is playable on an empty table (first card)', () {
      expect(GameRules.isPlayable(_num(CardColor.red, 5), null, CardColor.red), isTrue);
    });

    test('same color is always playable', () {
      final top = _num(CardColor.blue, 3);
      expect(GameRules.isPlayable(_num(CardColor.blue, 9), top, CardColor.blue), isTrue);
    });

    test('same number, different color, is playable', () {
      final top = _num(CardColor.blue, 7);
      expect(GameRules.isPlayable(_num(CardColor.green, 7), top, CardColor.blue), isTrue);
    });

    test('different color and number is NOT playable', () {
      final top = _num(CardColor.blue, 7);
      expect(GameRules.isPlayable(_num(CardColor.green, 3), top, CardColor.blue), isFalse);
    });

    test('wild is always playable', () {
      final top = _num(CardColor.blue, 7);
      final wild = UnoCard(color: CardColor.wild, type: CardType.wild);
      expect(GameRules.isPlayable(wild, top, CardColor.blue), isTrue);
    });

    test('same action type across colors is playable', () {
      final top = UnoCard(color: CardColor.red, type: CardType.skip);
      final skip = UnoCard(color: CardColor.green, type: CardType.skip);
      expect(GameRules.isPlayable(skip, top, CardColor.red), isTrue);
    });
  });

  group('GameRules.nextSeat', () {
    test('clockwise advances by 1', () {
      expect(GameRules.nextSeat(0, 4, Direction.clockwise), 1);
      expect(GameRules.nextSeat(3, 4, Direction.clockwise), 0);
    });

    test('counter-clockwise advances backward', () {
      expect(GameRules.nextSeat(0, 4, Direction.counterClockwise), 3);
      expect(GameRules.nextSeat(2, 4, Direction.counterClockwise), 1);
    });

    test('skip advances by 2', () {
      expect(GameRules.nextSeat(0, 4, Direction.clockwise, advance: 2), 2);
      expect(GameRules.nextSeat(3, 4, Direction.clockwise, advance: 2), 1);
    });
  });

  group('GameRules.isWildDrawFourClean', () {
    test('is clean when hand has no card matching current color', () {
      final hand = [_num(CardColor.blue, 4), _num(CardColor.green, 2)];
      expect(GameRules.isWildDrawFourClean(hand, CardColor.red), isTrue);
    });

    test('is not clean when hand has a matching color card', () {
      final hand = [_num(CardColor.red, 4), _num(CardColor.green, 2)];
      expect(GameRules.isWildDrawFourClean(hand, CardColor.red), isFalse);
    });
  });
}
