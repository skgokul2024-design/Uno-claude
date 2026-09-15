import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/constants/constants.dart';
import '../models/room_model.dart';

/// Broadcasts this device's open room over local UDP so nearby devices on
/// the same Wi-Fi/hotspot network can list it without typing a room code.
/// Purely local-subnet traffic — never leaves the LAN, no internet used.
class RoomAdvertiser {
  Timer? _timer;
  RawDatagramSocket? _socket;

  Future<void> start(Room Function() currentRoom) async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.broadcastEnabled = true;

    _timer = Timer.periodic(
      const Duration(milliseconds: AppConstants.discoveryBroadcastIntervalMs),
      (_) {
        final room = currentRoom();
        if (!room.isOpen) return;
        final payload = utf8.encode(jsonEncode({
          'kind': 'UNO_NEARBY_ROOM',
          'room': room.toJson(),
        }));
        _socket?.send(payload, InternetAddress('255.255.255.255'), AppConstants.discoveryPort);
      },
    );
  }

  Future<void> stop() async {
    _timer?.cancel();
    _socket?.close();
  }
}

/// Listens for [RoomAdvertiser] broadcasts and surfaces discovered rooms to
/// the "Join Game" screen in real time.
class RoomScanner {
  RawDatagramSocket? _socket;
  final _controller = StreamController<Room>.broadcast();
  final Map<String, DateTime> _lastSeen = {};
  Timer? _pruneTimer;

  Stream<Room> get roomsFound => _controller.stream;

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, AppConstants.discoveryPort);
    _socket!.readEventsEnabled = true;
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket!.receive();
      if (datagram == null) return;
      try {
        final decoded = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
        if (decoded['kind'] != 'UNO_NEARBY_ROOM') return;
        final room = Room.fromJson(decoded['room'] as Map<String, dynamic>);
        _lastSeen[room.roomId] = DateTime.now();
        _controller.add(room);
      } catch (_) {
        // Ignore malformed / foreign UDP traffic on this port.
      }
    });
  }

  Future<void> stop() async {
    _pruneTimer?.cancel();
    _socket?.close();
    await _controller.close();
  }
}
