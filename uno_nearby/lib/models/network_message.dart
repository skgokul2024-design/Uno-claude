import 'dart:convert';

enum MessageType {
  createRoom,
  roomCreated,
  discoverRoom,
  roomAdvertisement, // UDP broadcast payload
  joinRoom,
  joinAccepted,
  joinRejected,
  playerJoined,
  playerLeft,
  gameStart,
  gameState,
  playCard,
  drawCard,
  uno,
  chooseColor,
  turnChanged,
  roundEnd,
  gameOver,
  ping,
  pong,
  disconnect,
  reconnect,
  error,
}

/// Envelope for every message sent over the TCP game connection (and, for
/// [MessageType.roomAdvertisement], the UDP discovery broadcast).
///
/// [sequence] is a strictly-increasing per-sender counter. Recipients must
/// discard any message whose sequence is not greater than the last one seen
/// from that sender, which prevents replay/out-of-order application of
/// stale messages (see NetworkMessage.isNewerThan).
class NetworkMessage {
  final MessageType type;
  final String gameId;
  final String playerId;
  final int sequence;
  final int timestamp;
  final Map<String, dynamic> payload;

  NetworkMessage({
    required this.type,
    required this.gameId,
    required this.playerId,
    required this.sequence,
    int? timestamp,
    this.payload = const {},
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  bool isNewerThan(int lastSeenSequence) => sequence > lastSeenSequence;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'gameId': gameId,
        'playerId': playerId,
        'sequence': sequence,
        'timestamp': timestamp,
        'payload': payload,
      };

  String encode() => jsonEncode(toJson());

  factory NetworkMessage.fromJson(Map<String, dynamic> json) => NetworkMessage(
        type: MessageType.values.byName(json['type'] as String),
        gameId: json['gameId'] as String? ?? '',
        playerId: json['playerId'] as String? ?? '',
        sequence: json['sequence'] as int? ?? 0,
        timestamp: json['timestamp'] as int?,
        payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      );

  static NetworkMessage? tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return NetworkMessage.fromJson(decoded);
    } catch (_) {
      return null; // malformed message: caller should ignore, never crash
    }
  }
}
