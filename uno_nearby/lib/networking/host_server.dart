import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../core/constants/constants.dart';
import '../game/ai_player.dart';
import '../game/game_engine.dart';
import '../models/card_model.dart';
import '../models/game_model.dart';
import '../models/network_message.dart';
import '../models/player_model.dart';
import '../models/room_model.dart';
import 'discovery.dart';
import 'message_protocol.dart';

const _uuid = Uuid();

/// Runs on the device that created the room. Owns the authoritative
/// [GameEngine], accepts client TCP connections, validates every inbound
/// action, and fans out sanitized state to each connected client.
///
/// This class is the only place in the whole app allowed to construct or
/// mutate a live [GameEngine] — see section 26 (host authority / never
/// trust the client) of the design spec.
class HostServer {
  final String hostPlayerId;
  final String hostPlayerName;
  final int maxPlayers;
  final UnoPenaltyRule unoPenalty;
  final DrawRule drawRule;

  ServerSocket? _serverSocket;
  final RoomAdvertiser _advertiser = RoomAdvertiser();
  final AiPlayer _ai = AiPlayer();

  final Map<String, FramedSocket> _sockets = {}; // playerId -> connection
  final Map<String, int> _lastSeenSequence = {}; // playerId -> last accepted seq
  final Map<String, Timer> _reconnectGrace = {};
  int _outSequence = 0;

  Room _room;
  GameEngine? _engine;

  final _roomController = StreamController<Room>.broadcast();
  final _stateController = StreamController<GameState>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<Room> get roomUpdates => _roomController.stream;
  Stream<GameState> get stateUpdates => _stateController.stream;
  Stream<String> get errors => _errorController.stream;
  Room get room => _room;

  HostServer({
    required this.hostPlayerName,
    this.maxPlayers = AppConstants.maxPlayers,
    this.unoPenalty = UnoPenaltyRule.drawTwo,
    this.drawRule = DrawRule.playImmediately,
    String? hostPlayerId,
  })  : hostPlayerId = hostPlayerId ?? _uuid.v4(),
        _room = Room(
          roomId: _uuid.v4(),
          roomCode: _generateRoomCode(),
          hostName: hostPlayerName,
          hostIp: '',
          maxPlayers: maxPlayers,
          players: const [],
        );

  static String _generateRoomCode() {
    final rng = Random.secure();
    return List.generate(
      AppConstants.roomCodeLength,
      (_) => AppConstants.roomCodeChars[rng.nextInt(AppConstants.roomCodeChars.length)],
    ).join();
  }

  /// Starts listening for client connections and begins advertising the
  /// room over local UDP. Returns the LAN IP clients should connect to
  /// (found by the caller via network_info_plus and passed in), purely for
  /// display on the "Room Created" screen.
  Future<void> start({required String localIp}) async {
    _room = _room.copyWith(players: [
      Player(id: hostPlayerId, name: hostPlayerName, seat: 0, kind: PlayerKind.human),
    ]);
    _room = Room(
      roomId: _room.roomId,
      roomCode: _room.roomCode,
      hostName: hostPlayerName,
      hostIp: localIp,
      maxPlayers: maxPlayers,
      players: _room.players,
    );

    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, AppConstants.gamePort);
    _serverSocket!.listen(_handleNewConnection, onError: (_) {});

    await _advertiser.start(() => _room);
    _roomController.add(_room);
  }

  void _handleNewConnection(Socket socket) {
    final framed = FramedSocket(socket);
    // Player identity is established by the first JOIN_ROOM message; until
    // then this socket is unassociated.
    late final StreamSubscription sub;
    sub = framed.messages.listen((msg) {
      if (msg.type == MessageType.joinRoom) {
        sub.cancel();
        _onJoinRequest(framed, msg);
      }
    });
  }

  void _onJoinRequest(FramedSocket framed, NetworkMessage msg) {
    final requestedName = (msg.payload['name'] as String? ?? 'Player').trim();
    final reconnectingId = msg.payload['playerId'] as String?;

    // Reconnection path: same playerId rejoining within the grace window.
    if (reconnectingId != null && _room.players.any((p) => p.id == reconnectingId)) {
      _reconnectGrace.remove(reconnectingId)?.cancel();
      _sockets[reconnectingId] = framed;
      _lastSeenSequence[reconnectingId] = _lastSeenSequence[reconnectingId] ?? 0;
      _setConnectionState(reconnectingId, PlayerConnectionState.connected);
      _attachSocketListener(framed, reconnectingId);
      framed.send(_envelope(MessageType.joinAccepted, reconnectingId, {
        'playerId': reconnectingId,
        'room': _room.toJson(),
      }));
      if (_engine != null) _pushStateTo(reconnectingId);
      return;
    }

    if (!_room.isOpen) {
      framed.send(_envelope(MessageType.joinRejected, '', {'reason': 'Game already started.'}));
      framed.close();
      return;
    }
    if (_room.isFull) {
      framed.send(_envelope(MessageType.joinRejected, '', {'reason': 'Room is full.'}));
      framed.close();
      return;
    }
    if (_room.players.any((p) => p.name.toLowerCase() == requestedName.toLowerCase())) {
      framed.send(_envelope(MessageType.joinRejected, '', {'reason': 'Name already taken in this room.'}));
      framed.close();
      return;
    }

    final newPlayerId = _uuid.v4();
    final seat = _room.players.length;
    final newPlayer = Player(id: newPlayerId, name: requestedName, seat: seat, kind: PlayerKind.human);

    _room = _room.copyWith(players: [..._room.players, newPlayer]);
    _sockets[newPlayerId] = framed;
    _lastSeenSequence[newPlayerId] = 0;
    _attachSocketListener(framed, newPlayerId);

    framed.send(_envelope(MessageType.joinAccepted, newPlayerId, {
      'playerId': newPlayerId,
      'room': _room.toJson(),
    }));
    _broadcast(MessageType.playerJoined, {'player': newPlayer.toPublicJson(), 'room': _room.toJson()});
    _roomController.add(_room);
  }

  void _attachSocketListener(FramedSocket framed, String playerId) {
    framed.messages.listen(
      (msg) => _handleClientMessage(playerId, msg),
      onDone: () => _handleDisconnect(playerId),
      onError: (_) => _handleDisconnect(playerId),
    );
  }

  void _handleDisconnect(String playerId) {
    _sockets.remove(playerId);
    if (_engine == null) {
      // Still in lobby: just remove the seat.
      _room = _room.copyWith(players: _room.players.where((p) => p.id != playerId).toList());
      _roomController.add(_room);
      _broadcast(MessageType.playerLeft, {'playerId': playerId, 'room': _room.toJson()});
      return;
    }

    _setConnectionState(playerId, PlayerConnectionState.reconnecting);
    _reconnectGrace[playerId] = Timer(const Duration(milliseconds: AppConstants.reconnectGraceMs), () {
      _setConnectionState(playerId, PlayerConnectionState.disconnected);
      _errorController.add('$playerId could not reconnect in time.');
    });
  }

  void _setConnectionState(String playerId, PlayerConnectionState cs) {
    if (_engine == null) return;
    final players = _engine!.state.players
        .map((p) => p.id == playerId ? p.copyWith(connectionState: cs) : p)
        .toList();
    _engine!.state = _engine!.state.copyWith(players: players, stateVersion: _engine!.state.stateVersion + 1);
    _broadcastState();
  }

  void _handleClientMessage(String playerId, NetworkMessage msg) {
    final lastSeq = _lastSeenSequence[playerId] ?? 0;
    if (!msg.isNewerThan(lastSeq) && msg.type != MessageType.ping) {
      return; // stale/replayed message — ignore per section 26/12
    }
    _lastSeenSequence[playerId] = msg.sequence;

    switch (msg.type) {
      case MessageType.ping:
        _sockets[playerId]?.send(_envelope(MessageType.pong, playerId, {}));
        break;
      case MessageType.playCard:
        _requireEngine((engine) {
          final colorRaw = msg.payload['chosenColor'] as String?;
          final result = engine.playCard(
            playerId: playerId,
            cardId: msg.payload['cardId'] as String,
            chosenColor: colorRaw != null ? CardColor.values.byName(colorRaw) : null,
          );
          _afterAction(result, playerId);
        });
        break;
      case MessageType.drawCard:
        _requireEngine((engine) => _afterAction(engine.drawCard(playerId: playerId), playerId));
        break;
      case MessageType.chooseColor:
        _requireEngine((engine) => _afterAction(
              engine.chooseColor(
                playerId: playerId,
                color: CardColor.values.byName(msg.payload['color'] as String),
              ),
              playerId,
            ));
        break;
      case MessageType.uno:
        _requireEngine((engine) => _afterAction(engine.callUno(playerId: playerId), playerId));
        break;
      case MessageType.disconnect:
        _handleDisconnect(playerId);
        break;
      default:
        break;
    }
  }

  void _requireEngine(void Function(GameEngine engine) fn) {
    final engine = _engine;
    if (engine == null) return;
    fn(engine);
  }

  void _afterAction(EngineResult result, String actingPlayerId) {
    if (!result.ok) {
      _sockets[actingPlayerId]?.send(_envelope(MessageType.error, actingPlayerId, {'message': result.error}));
      return;
    }
    _broadcastState();
    _maybeRunAiTurns();
  }

  /// After every state change, let any AI seats whose turn it now is act,
  /// looping until control returns to a human or the round ends. This runs
  /// synchronously on the host so AI turns feel instant but never race with
  /// a human action arriving concurrently (Dart is single-threaded here).
  void _maybeRunAiTurns() {
    final engine = _engine;
    if (engine == null) return;
    int guard = 0;
    while (engine.state.status == GameStatus.inProgress && guard < 100) {
      final current = engine.state.currentPlayer;
      if (!current.isAi) break;
      _ai.takeTurn(engine, current.id);
      guard++;
    }
    _broadcastState();
  }

  // ---------------------------------------------------------------------
  // LOCAL ACTIONS (the host device's own human player)
  //
  // The host device doesn't open a TCP connection to itself — its own UI
  // calls straight into these, which route through the exact same
  // GameEngine validation as every remote client's action. This keeps a
  // single source of truth: there is no "trusted" shortcut for the host's
  // own moves.
  // ---------------------------------------------------------------------

  void handleLocalPlayCard(String playerId, String cardId, CardColor? chosenColor) {
    _requireEngine((engine) {
      final result = engine.playCard(playerId: playerId, cardId: cardId, chosenColor: chosenColor);
      _afterAction(result, playerId);
    });
  }

  void handleLocalChooseColor(String playerId, CardColor color) {
    _requireEngine((engine) => _afterAction(engine.chooseColor(playerId: playerId, color: color), playerId));
  }

  void handleLocalDrawCard(String playerId) {
    _requireEngine((engine) => _afterAction(engine.drawCard(playerId: playerId), playerId));
  }

  void handleLocalCallUno(String playerId) {
    _requireEngine((engine) => _afterAction(engine.callUno(playerId: playerId), playerId));
  }

  // ---------------------------------------------------------------------
  // GAME LIFECYCLE
  // ---------------------------------------------------------------------

  void updateRules({UnoPenaltyRule? unoPenalty, DrawRule? drawRule}) {
    _room = _room.copyWith(unoPenalty: unoPenalty, drawRule: drawRule);
    _roomController.add(_room);
  }

  /// Fills remaining seats with AI players (used by "Play with Computer"
  /// and by hosts who want to backfill an under-filled human room).
  void fillWithAi() {
    var players = [..._room.players];
    while (players.length < maxPlayers) {
      players.add(Player(
        id: _uuid.v4(),
        name: 'CPU ${players.length}',
        seat: players.length,
        kind: PlayerKind.ai,
      ));
    }
    _room = _room.copyWith(players: players);
    _roomController.add(_room);
  }

  void startGame() {
    if (!_room.canStart) return;
    _room = _room.copyWith(isOpen: false);
    _engine = GameEngine.startNewGame(
      gameId: _room.roomId,
      players: _room.players,
      unoPenalty: _room.unoPenalty,
      drawRule: _room.drawRule,
    );
    _roomController.add(_room);
    _broadcast(MessageType.gameStart, {'room': _room.toJson()});
    _broadcastState();
    _maybeRunAiTurns();
  }

  void startNextRound() {
    _engine?.startNextRound();
    _broadcastState();
    _maybeRunAiTurns();
  }

  void _broadcastState() {
    final engine = _engine;
    if (engine == null) return;
    _stateController.add(engine.state);
    for (final playerId in _sockets.keys) {
      _pushStateTo(playerId);
    }
    // Also feed the host's own local UI via the state stream above.
  }

  void _pushStateTo(String playerId) {
    final engine = _engine;
    if (engine == null) return;
    _sockets[playerId]?.send(NetworkMessage(
      type: MessageType.gameState,
      gameId: engine.state.gameId,
      playerId: hostPlayerId,
      sequence: _outSequence++,
      payload: engine.state.toClientJson(playerId),
    ));
  }

  NetworkMessage _envelope(MessageType type, String targetPlayerId, Map<String, dynamic> payload) =>
      NetworkMessage(
        type: type,
        gameId: _engine?.state.gameId ?? _room.roomId,
        playerId: hostPlayerId,
        sequence: _outSequence++,
        payload: payload,
      );

  void _broadcast(MessageType type, Map<String, dynamic> payload) {
    for (final entry in _sockets.entries) {
      entry.value.send(_envelope(type, entry.key, payload));
    }
  }

  /// The host's own "local" game state, used by the host device's own UI
  /// since the host doesn't connect to itself over TCP.
  GameState? get localHostView => _engine?.state;

  Future<void> closeRoom() async {
    _room = _room.copyWith(isOpen: false);
    await _advertiser.stop();
    for (final s in _sockets.values) {
      await s.close();
    }
    _sockets.clear();
    for (final t in _reconnectGrace.values) {
      t.cancel();
    }
    await _serverSocket?.close();
    await _roomController.close();
    await _stateController.close();
    await _errorController.close();
  }
}
