import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/constants.dart';
import '../models/room_model.dart';
import '../networking/nearby_connection_service.dart';

final connectionServiceProvider = Provider<NearbyConnectionService>((ref) {
  final service = NearbyConnectionService();
  ref.onDispose(() => service.leave());
  return service;
});

/// Current lobby room state (null until a room is created or joined).
final roomProvider = StateNotifierProvider<RoomNotifier, Room?>((ref) {
  return RoomNotifier(ref.watch(connectionServiceProvider));
});

class RoomNotifier extends StateNotifier<Room?> {
  final NearbyConnectionService _service;
  RoomNotifier(this._service) : super(null) {
    _service.roomUpdates.listen((room) => state = room);
  }

  Future<void> createRoom({
    required String hostName,
    required int maxPlayers,
    UnoPenaltyRule unoPenalty = UnoPenaltyRule.drawTwo,
    DrawRule drawRule = DrawRule.playImmediately,
  }) async {
    state = await _service.createRoom(
      hostName: hostName,
      maxPlayers: maxPlayers,
      unoPenalty: unoPenalty,
      drawRule: drawRule,
    );
  }

  Future<void> joinRoom({required String hostIp, required String playerName}) async {
    await _service.joinRoom(hostIp: hostIp, playerName: playerName);
  }

  void fillWithAi() => _service.fillRemainingWithAi();
  void startGame() => _service.startGame();

  Future<void> leave() async {
    await _service.leave();
    state = null;
  }
}

/// Rooms discovered via local UDP broadcast on the "Join Game" screen.
final discoveredRoomsProvider = StreamProvider.autoDispose<List<Room>>((ref) {
  final service = ref.watch(connectionServiceProvider);
  final rooms = <String, Room>{};
  late final Stream<List<Room>> mapped;

  service.startScanning();
  ref.onDispose(() => service.stopScanning());

  mapped = service.discoveredRooms.map((room) {
    rooms[room.roomId] = room;
    return rooms.values.where((r) => r.isOpen).toList();
  });
  return mapped;
});
