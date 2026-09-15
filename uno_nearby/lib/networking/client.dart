import 'dart:async';
import 'dart:io';
import '../core/constants/constants.dart';
import '../models/card_model.dart';
import '../models/game_model.dart';
import '../models/network_message.dart';
import '../models/room_model.dart';
import 'message_protocol.dart';

enum ClientConnectionStatus { connecting, connected, reconnecting, disconnected, rejected }

/// Runs on every device that is NOT the host. Talks to [HostServer] purely
/// over TCP — it never touches game rules directly and treats every
/// [GameState] it receives as read-only, display-only data.
class GameClient {
  final String hostIp;
  final String playerName;
  String? playerId; // assigned by the host on join
  String? _lastKnownGameId;

  FramedSocket? _framed;
  Timer? _heartbeat;
  Timer? _reconnectTimer;
  int _outSequence = 0;
  bool _manuallyClosed = false;

  final _statusController = StreamController<ClientConnectionStatus>.broadcast();
  final _roomController = StreamController<Room>.broadcast();
  final _stateController = StreamController<GameState>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _gameStartController = StreamController<void>.broadcast();

  Stream<ClientConnectionStatus> get status => _statusController.stream;
  Stream<Room> get roomUpdates => _roomController.stream;
  Stream<GameState> get stateUpdates => _stateController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<void> get gameStarted => _gameStartController.stream;

  GameClient({required this.hostIp, required this.playerName});

  Future<void> connect() async {
    _manuallyClosed = false;
    _statusController.add(ClientConnectionStatus.connecting);
    try {
      final socket = await Socket.connect(hostIp, AppConstants.gamePort,
          timeout: const Duration(seconds: 8));
      _framed = FramedSocket(socket);
      _framed!.messages.listen(_onMessage, onDone: _onDisconnected, onError: (_) => _onDisconnected());

      _framed!.send(NetworkMessage(
        type: MessageType.joinRoom,
        gameId: _lastKnownGameId ?? '',
        playerId: playerId ?? '',
        sequence: _outSequence++,
        payload: {'name': playerName, if (playerId != null) 'playerId': playerId},
      ));

      _startHeartbeat();
    } catch (e) {
      _statusController.add(ClientConnectionStatus.disconnected);
      _errorController.add('Could not reach host: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(milliseconds: AppConstants.heartbeatIntervalMs), (_) {
      _framed?.send(NetworkMessage(
        type: MessageType.ping,
        gameId: _lastKnownGameId ?? '',
        playerId: playerId ?? '',
        sequence: _outSequence++,
      ));
    });
  }

  void _onMessage(NetworkMessage msg) {
    switch (msg.type) {
      case MessageType.joinAccepted:
        playerId = msg.payload['playerId'] as String;
        _lastKnownGameId = msg.gameId;
        _statusController.add(ClientConnectionStatus.connected);
        _roomController.add(Room.fromJson(msg.payload['room'] as Map<String, dynamic>));
        break;
      case MessageType.joinRejected:
        _statusController.add(ClientConnectionStatus.rejected);
        _errorController.add(msg.payload['reason'] as String? ?? 'Join rejected.');
        break;
      case MessageType.playerJoined:
      case MessageType.playerLeft:
        _roomController.add(Room.fromJson(msg.payload['room'] as Map<String, dynamic>));
        break;
      case MessageType.gameStart:
        _gameStartController.add(null);
        break;
      case MessageType.gameState:
        _stateController.add(GameState.fromJson(msg.payload));
        break;
      case MessageType.error:
        _errorController.add(msg.payload['message'] as String? ?? 'Unknown error.');
        break;
      case MessageType.pong:
        break;
      default:
        break;
    }
  }

  void _onDisconnected() {
    if (_manuallyClosed) return;
    _statusController.add(ClientConnectionStatus.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (!_manuallyClosed) connect();
    });
  }

  void playCard({required String cardId, CardColor? chosenColor}) {
    _send(MessageType.playCard, {
      'cardId': cardId,
      if (chosenColor != null) 'chosenColor': chosenColor.name,
    });
  }

  void chooseColor(CardColor color) => _send(MessageType.chooseColor, {'color': color.name});
  void drawCard() => _send(MessageType.drawCard, {});
  void callUno() => _send(MessageType.uno, {});

  void _send(MessageType type, Map<String, dynamic> payload) {
    if (playerId == null) return;
    _framed?.send(NetworkMessage(
      type: type,
      gameId: _lastKnownGameId ?? '',
      playerId: playerId!,
      sequence: _outSequence++,
      payload: payload,
    ));
  }

  Future<void> disconnect() async {
    _manuallyClosed = true;
    _heartbeat?.cancel();
    _reconnectTimer?.cancel();
    _send(MessageType.disconnect, {});
    await _framed?.close();
    await _statusController.close();
    await _roomController.close();
    await _stateController.close();
    await _errorController.close();
    await _gameStartController.close();
  }
}
