import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:uno_nearby/core/constants/constants.dart';
import 'package:uno_nearby/game/game_engine.dart';
import 'package:uno_nearby/models/card_model.dart';
import 'package:uno_nearby/models/game_model.dart';
import 'package:uno_nearby/models/player_model.dart';

UnoCard _num(CardColor c, int n) => UnoCard(color: c, type: CardType.number, number: n);

List<Player> _players(int count) => List.generate(
    count, (i) => Player(id: 'p$i', name: 'Player $i', seat: i, kind: PlayerKind.human));

void main() {
  group('GameEngine.startNewGame', () {
    test('deals startingHandSize cards to every player', () {
      final engine = GameEngine.startNewGame(
        gameId: 'g1',
        players: _players(4),
        random: Random(42),
      );
      for (final p in engine.state.players) {
        expect(p.hand.length, AppConstants.startingHandSize);
      }
    });

    test('flips exactly one top card and it is never a Wild Draw Four', () {
      for (int seed = 0; seed < 20; seed++) {
        final engine = GameEngine.startNewGame(gameId: 'g', players: _players(3), random: Random(seed));
        expect(engine.state.topCard, isNotNull);
        expect(engine.state.topCard!.type, isNot(CardType.wildDrawFour));
      }
    });

    test('game status starts inProgress with stateVersion incremented', () {
      final engine = GameEngine.startNewGame(gameId: 'g', players: _players(2), random: Random(1));
      expect(engine.state.status, GameStatus.inProgress);
      expect(engine.state.stateVersion, greaterThan(0));
    });
  });

  group('GameEngine.playCard validation', () {
    late GameEngine engine;

    GameEngine buildEngine({required List<Player> players, required UnoCard top, required CardColor color}) {
      return GameEngine(
        state: GameState(
          gameId: 'g',
          round: 1,
          players: players,
          currentPlayerSeat: 0,
          direction: Direction.clockwise,
          currentColor: color,
          topCard: top,
          deckCount: 20,
          discardPile: [top],
          status: GameStatus.inProgress,
          stateVersion: 0,
        ),
        initialDrawPile: List.generate(20, (_) => _num(CardColor.red, 1)),
      );
    }

    test('rejects a play when it is not the player\'s turn', () {
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [_num(CardColor.red, 5)]),
        Player(id: 'b', name: 'B', seat: 1, hand: [_num(CardColor.red, 3)]),
      ];
      engine = buildEngine(players: players, top: _num(CardColor.blue, 2), color: CardColor.blue);
      final result = engine.playCard(playerId: 'b', cardId: players[1].hand.first.id);
      expect(result.ok, isFalse);
      expect(result.error, contains('not your turn'));
    });

    test('rejects an illegal (mismatched) card', () {
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [_num(CardColor.green, 9)]),
        Player(id: 'b', name: 'B', seat: 1, hand: [_num(CardColor.red, 3)]),
      ];
      engine = buildEngine(players: players, top: _num(CardColor.blue, 2), color: CardColor.blue);
      final result = engine.playCard(playerId: 'a', cardId: players[0].hand.first.id);
      expect(result.ok, isFalse);
    });

    test('accepts a legal same-color play and advances the turn', () {
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [_num(CardColor.blue, 9)]),
        Player(id: 'b', name: 'B', seat: 1, hand: [_num(CardColor.red, 3)]),
      ];
      engine = buildEngine(players: players, top: _num(CardColor.blue, 2), color: CardColor.blue);
      final result = engine.playCard(playerId: 'a', cardId: players[0].hand.first.id);
      expect(result.ok, isTrue);
      expect(result.state.currentPlayerSeat, 1);
    });

    test('Skip card causes the following player to be skipped', () {
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [UnoCard(color: CardColor.blue, type: CardType.skip)]),
        Player(id: 'b', name: 'B', seat: 1, hand: [_num(CardColor.red, 3)]),
        Player(id: 'c', name: 'C', seat: 2, hand: [_num(CardColor.red, 3)]),
      ];
      engine = buildEngine(players: players, top: _num(CardColor.blue, 2), color: CardColor.blue);
      final result = engine.playCard(playerId: 'a', cardId: players[0].hand.first.id);
      expect(result.ok, isTrue);
      expect(result.state.currentPlayerSeat, 2); // seat 1 (b) was skipped
    });

    test('Reverse flips direction', () {
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [UnoCard(color: CardColor.blue, type: CardType.reverse)]),
        Player(id: 'b', name: 'B', seat: 1, hand: [_num(CardColor.red, 3)]),
        Player(id: 'c', name: 'C', seat: 2, hand: [_num(CardColor.red, 3)]),
      ];
      engine = buildEngine(players: players, top: _num(CardColor.blue, 2), color: CardColor.blue);
      final result = engine.playCard(playerId: 'a', cardId: players[0].hand.first.id);
      expect(result.ok, isTrue);
      expect(result.state.direction, Direction.counterClockwise);
      expect(result.state.currentPlayerSeat, 2); // moves backward from seat 0 -> seat 2
    });

    test('Reverse in a 2-player game acts like Skip (same player goes again)', () {
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [UnoCard(color: CardColor.blue, type: CardType.reverse)]),
        Player(id: 'b', name: 'B', seat: 1, hand: [_num(CardColor.red, 3)]),
      ];
      engine = buildEngine(players: players, top: _num(CardColor.blue, 2), color: CardColor.blue);
      final result = engine.playCard(playerId: 'a', cardId: players[0].hand.first.id);
      expect(result.ok, isTrue);
      expect(result.state.currentPlayerSeat, 0); // stays with A
    });

    test('Draw Two accumulates a draw stack instead of immediately drawing', () {
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [UnoCard(color: CardColor.blue, type: CardType.drawTwo)]),
        Player(id: 'b', name: 'B', seat: 1, hand: [_num(CardColor.red, 3)]),
      ];
      engine = buildEngine(players: players, top: _num(CardColor.blue, 2), color: CardColor.blue);
      final result = engine.playCard(playerId: 'a', cardId: players[0].hand.first.id);
      expect(result.ok, isTrue);
      expect(result.state.drawStackCount, 2);
      expect(result.state.currentPlayerSeat, 1);
    });

    test('drawCard resolves the pending draw stack and passes the turn', () {
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [UnoCard(color: CardColor.blue, type: CardType.drawTwo)]),
        Player(id: 'b', name: 'B', seat: 1, hand: [_num(CardColor.red, 3)]),
      ];
      engine = buildEngine(players: players, top: _num(CardColor.blue, 2), color: CardColor.blue);
      engine.playCard(playerId: 'a', cardId: players[0].hand.first.id);
      final result = engine.drawCard(playerId: 'b');
      expect(result.ok, isTrue);
      final b = result.state.players.firstWhere((p) => p.id == 'b');
      expect(b.hand.length, 3); // original 1 + 2 drawn
      expect(result.state.drawStackCount, 0);
      expect(result.state.currentPlayerSeat, 0);
    });

    test('Wild card play requires a subsequent chooseColor before the turn advances', () {
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [UnoCard(color: CardColor.wild, type: CardType.wild)]),
        Player(id: 'b', name: 'B', seat: 1, hand: [_num(CardColor.red, 3)]),
      ];
      engine = buildEngine(players: players, top: _num(CardColor.blue, 2), color: CardColor.blue);
      final playResult = engine.playCard(playerId: 'a', cardId: players[0].hand.first.id);
      expect(playResult.ok, isTrue);
      expect(playResult.state.pendingWildPlayerId, 'a');
      expect(playResult.state.currentPlayerSeat, 0); // has not advanced yet

      final colorResult = engine.chooseColor(playerId: 'a', color: CardColor.green);
      expect(colorResult.ok, isTrue);
      expect(colorResult.state.currentColor, CardColor.green);
      expect(colorResult.state.pendingWildPlayerId, isNull);
      expect(colorResult.state.currentPlayerSeat, 1);
    });

    test('Wild Draw Four accumulates +4 even before its color is chosen', () {
      // Regression: the +4 used to be applied only in the branch taken when
      // a color was supplied up-front, so a WD4 played through the normal
      // pending-color flow silently dealt no penalty at all.
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [
          UnoCard(color: CardColor.wild, type: CardType.wildDrawFour),
          _num(CardColor.red, 1),
        ]),
        Player(id: 'b', name: 'B', seat: 1, hand: [_num(CardColor.red, 3)]),
      ];
      engine = buildEngine(players: players, top: _num(CardColor.blue, 2), color: CardColor.blue);

      final play = engine.playCard(playerId: 'a', cardId: players[0].hand.first.id);
      expect(play.ok, isTrue);
      expect(play.state.drawStackCount, 4, reason: '+4 must apply as soon as the card is played');

      final pick = engine.chooseColor(playerId: 'a', color: CardColor.green);
      expect(pick.state.drawStackCount, 4, reason: 'choosing a color must not clear the stack');
      expect(pick.state.currentPlayerSeat, 1);

      final drew = engine.drawCard(playerId: 'b');
      final b = drew.state.players.firstWhere((p) => p.id == 'b');
      expect(b.hand.length, 1 + 4);
      expect(drew.state.drawStackCount, 0);
    });

    test('rejects a color choice from a player with no pending wild', () {
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [_num(CardColor.blue, 5)]),
        Player(id: 'b', name: 'B', seat: 1, hand: [_num(CardColor.red, 3)]),
      ];
      engine = buildEngine(players: players, top: _num(CardColor.blue, 2), color: CardColor.blue);
      final result = engine.chooseColor(playerId: 'a', color: CardColor.red);
      expect(result.ok, isFalse);
    });

    test('playing the last card wins the round and scores opponents\' hands', () {
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [_num(CardColor.blue, 9)]),
        Player(id: 'b', name: 'B', seat: 1, hand: [_num(CardColor.red, 5), _num(CardColor.green, 3)]),
      ];
      engine = buildEngine(players: players, top: _num(CardColor.blue, 2), color: CardColor.blue);
      final result = engine.playCard(playerId: 'a', cardId: players[0].hand.first.id);
      expect(result.ok, isTrue);
      expect(result.state.status, GameStatus.roundEnd);
      expect(result.state.winnerId, 'a');
      final winner = result.state.players.firstWhere((p) => p.id == 'a');
      expect(winner.roundScore, 8); // 5 + 3 from B's remaining hand
    });

    test('rejects playing a card the player does not hold', () {
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [_num(CardColor.blue, 9)]),
        Player(id: 'b', name: 'B', seat: 1, hand: [_num(CardColor.red, 3)]),
      ];
      engine = buildEngine(players: players, top: _num(CardColor.blue, 2), color: CardColor.blue);
      expect(
        () => engine.playCard(playerId: 'a', cardId: 'not-a-real-card-id'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('UNO penalty', () {
    test('auto-penalizes a player who reaches one card without calling UNO', () {
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [_num(CardColor.blue, 9), _num(CardColor.blue, 4)]),
        Player(id: 'b', name: 'B', seat: 1, hand: [_num(CardColor.red, 3)]),
      ];
      final engine = GameEngine(
        state: GameState(
          gameId: 'g',
          round: 1,
          players: players,
          currentPlayerSeat: 0,
          direction: Direction.clockwise,
          currentColor: CardColor.blue,
          topCard: _num(CardColor.blue, 2),
          deckCount: 20,
          discardPile: [_num(CardColor.blue, 2)],
          status: GameStatus.inProgress,
          stateVersion: 0,
        ),
        initialDrawPile: List.generate(20, (_) => _num(CardColor.yellow, 1)),
        unoPenalty: UnoPenaltyRule.drawTwo,
      );

      final result = engine.playCard(playerId: 'a', cardId: players[0].hand.first.id);
      final a = result.state.players.firstWhere((p) => p.id == 'a');
      // Played one of two cards (now holds 1), never called UNO -> penalized 2 cards.
      expect(a.hand.length, 1 + 2);
    });

    test('no penalty when the player calls UNO first', () {
      final players = [
        Player(id: 'a', name: 'A', seat: 0, hand: [_num(CardColor.blue, 9), _num(CardColor.blue, 4)]),
        Player(id: 'b', name: 'B', seat: 1, hand: [_num(CardColor.red, 3)]),
      ];
      final engine = GameEngine(
        state: GameState(
          gameId: 'g',
          round: 1,
          players: players,
          currentPlayerSeat: 0,
          direction: Direction.clockwise,
          currentColor: CardColor.blue,
          topCard: _num(CardColor.blue, 2),
          deckCount: 20,
          discardPile: [_num(CardColor.blue, 2)],
          status: GameStatus.inProgress,
          stateVersion: 0,
        ),
        initialDrawPile: List.generate(20, (_) => _num(CardColor.yellow, 1)),
        unoPenalty: UnoPenaltyRule.drawTwo,
      );
      engine.callUno(playerId: 'a');
      final result = engine.playCard(playerId: 'a', cardId: players[0].hand.first.id);
      final a = result.state.players.firstWhere((p) => p.id == 'a');
      expect(a.hand.length, 1); // no penalty applied
    });
  });
}
