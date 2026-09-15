import 'package:flutter_test/flutter_test.dart';
import 'package:uno_nearby/models/card_model.dart';
import 'package:uno_nearby/models/network_message.dart';
import 'package:uno_nearby/models/player_model.dart';
import 'package:uno_nearby/models/game_model.dart';

void main() {
  group('UnoCard JSON round-trip', () {
    test('number card', () {
      final card = UnoCard(color: CardColor.red, type: CardType.number, number: 7);
      final back = UnoCard.fromJson(card.toJson());
      expect(back.id, card.id);
      expect(back.color, CardColor.red);
      expect(back.number, 7);
    });

    test('wild card with chosen color', () {
      final card = UnoCard(color: CardColor.wild, type: CardType.wildDrawFour, chosenColor: CardColor.green);
      final back = UnoCard.fromJson(card.toJson());
      expect(back.chosenColor, CardColor.green);
      expect(back.effectiveColor, CardColor.green);
    });
  });

  group('NetworkMessage', () {
    test('encode/decode round-trip preserves fields', () {
      final msg = NetworkMessage(
        type: MessageType.playCard,
        gameId: 'game-1',
        playerId: 'player-1',
        sequence: 5,
        payload: {'cardId': 'abc123'},
      );
      final decoded = NetworkMessage.tryDecode(msg.encode());
      expect(decoded, isNotNull);
      expect(decoded!.type, MessageType.playCard);
      expect(decoded.gameId, 'game-1');
      expect(decoded.sequence, 5);
      expect(decoded.payload['cardId'], 'abc123');
    });

    test('tryDecode returns null for malformed JSON instead of throwing', () {
      expect(NetworkMessage.tryDecode('{not valid json'), isNull);
    });

    test('isNewerThan correctly rejects stale/replayed sequence numbers', () {
      final msg = NetworkMessage(type: MessageType.ping, gameId: 'g', playerId: 'p', sequence: 5);
      expect(msg.isNewerThan(4), isTrue);
      expect(msg.isNewerThan(5), isFalse);
      expect(msg.isNewerThan(6), isFalse);
    });
  });

  group('GameState client sanitization', () {
    test('toClientJson hides other players\' hands but reveals own hand', () {
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [UnoCard(color: CardColor.red, type: CardType.number, number: 1)]),
        Player(id: 'b', name: 'B', seat: 1, hand: [
          UnoCard(color: CardColor.blue, type: CardType.number, number: 2),
          UnoCard(color: CardColor.green, type: CardType.number, number: 3),
        ]),
      ];
      final state = GameState(
        gameId: 'g',
        round: 1,
        players: players,
        currentPlayerSeat: 0,
        direction: Direction.clockwise,
        currentColor: CardColor.red,
        topCard: null,
        deckCount: 90,
        discardPile: const [],
        status: GameStatus.inProgress,
        stateVersion: 1,
      );

      final json = state.toClientJson('a');
      final playerJsonList = json['players'] as List<dynamic>;
      final aJson = playerJsonList.firstWhere((p) => p['id'] == 'a') as Map<String, dynamic>;
      final bJson = playerJsonList.firstWhere((p) => p['id'] == 'b') as Map<String, dynamic>;

      expect(aJson.containsKey('hand'), isTrue); // own hand visible
      expect(bJson.containsKey('hand'), isFalse); // opponent hand hidden
      expect(bJson['cardCount'], 2); // but count is visible
    });
  });
}
