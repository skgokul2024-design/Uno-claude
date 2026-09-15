import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/card_model.dart';
import '../models/game_model.dart';
import '../networking/nearby_connection_service.dart';
import 'room_provider.dart';

/// Live [GameState] as seen by this device, updated every time the host
/// broadcasts a new authoritative snapshot. Null before the game starts.
final gameStateProvider = StateNotifierProvider<GameStateNotifier, GameState?>((ref) {
  return GameStateNotifier(ref.watch(connectionServiceProvider));
});

class GameStateNotifier extends StateNotifier<GameState?> {
  final NearbyConnectionService _service;
  GameStateNotifier(this._service) : super(null) {
    _service.stateUpdates.listen((incoming) {
      // Section 12: reject stale/out-of-order snapshots.
      if (state == null || incoming.stateVersion > state!.stateVersion) {
        state = incoming;
      }
    });
  }

  void playCard(String playerId, String cardId, {CardColor? chosenColor}) =>
      _service.playCard(playerId, cardId, chosenColor: chosenColor);

  void chooseColor(String playerId, CardColor color) => _service.chooseColor(playerId, color);

  void drawCard(String playerId) => _service.drawCard(playerId);

  void callUno(String playerId) => _service.callUno(playerId);

  void startNextRound() => _service.startNextRound();
}

/// This device's own player id (host or client), for telling "my hand"
/// apart from opponents' seats in the UI.
final myPlayerIdProvider = Provider<String?>((ref) => ref.watch(connectionServiceProvider).myPlayerId);

/// Connectivity/error toasts surfaced from the networking layer.
final networkErrorProvider = StreamProvider.autoDispose<String>((ref) {
  return ref.watch(connectionServiceProvider).errors;
});
