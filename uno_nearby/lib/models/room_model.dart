import 'player_model.dart';
import '../core/constants/constants.dart';

/// Lobby-phase room info, before a GameState exists. Also what gets
/// broadcast over UDP so nearby devices can list open rooms on the
/// "Join Game" screen without typing a code.
class Room {
  final String roomId;
  final String roomCode;
  final String hostName;
  final String hostIp;
  final int maxPlayers;
  final List<Player> players;
  final bool isOpen; // false once the host starts the game or closes the room
  final UnoPenaltyRule unoPenalty;
  final DrawRule drawRule;

  const Room({
    required this.roomId,
    required this.roomCode,
    required this.hostName,
    required this.hostIp,
    required this.maxPlayers,
    required this.players,
    this.isOpen = true,
    this.unoPenalty = UnoPenaltyRule.drawTwo,
    this.drawRule = DrawRule.playImmediately,
  });

  bool get isFull => players.length >= maxPlayers;
  bool get canStart => players.length >= AppConstants.minPlayers && isOpen;

  Room copyWith({
    List<Player>? players,
    bool? isOpen,
    UnoPenaltyRule? unoPenalty,
    DrawRule? drawRule,
  }) =>
      Room(
        roomId: roomId,
        roomCode: roomCode,
        hostName: hostName,
        hostIp: hostIp,
        maxPlayers: maxPlayers,
        players: players ?? this.players,
        isOpen: isOpen ?? this.isOpen,
        unoPenalty: unoPenalty ?? this.unoPenalty,
        drawRule: drawRule ?? this.drawRule,
      );

  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'roomCode': roomCode,
        'hostName': hostName,
        'hostIp': hostIp,
        'maxPlayers': maxPlayers,
        'players': players.map((p) => p.toPublicJson()).toList(),
        'isOpen': isOpen,
        'unoPenalty': unoPenalty.name,
        'drawRule': drawRule.name,
      };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        roomId: json['roomId'] as String,
        roomCode: json['roomCode'] as String,
        hostName: json['hostName'] as String,
        hostIp: json['hostIp'] as String,
        maxPlayers: json['maxPlayers'] as int,
        players: (json['players'] as List<dynamic>)
            .map((p) => Player.fromPrivateJson(p as Map<String, dynamic>))
            .toList(),
        isOpen: json['isOpen'] as bool? ?? true,
        unoPenalty:
            UnoPenaltyRule.values.byName(json['unoPenalty'] as String? ?? 'drawTwo'),
        drawRule: DrawRule.values.byName(json['drawRule'] as String? ?? 'playImmediately'),
      );
}
