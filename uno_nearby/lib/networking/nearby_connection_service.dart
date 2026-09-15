import 'dart:async';
import 'package:network_info_plus/network_info_plus.dart';
import '../core/constants/constants.dart';
import '../models/card_model.dart';
import '../models/game_model.dart';
import '../models/room_model.dart';
import 'client.dart';
import 'discovery.dart';
import 'host_server.dart';

enum DeviceRole { none, host, client }

/// The single entry point the rest of the app (providers/screens) talks to
/// for anything network-related. It hides whether this device is acting as
/// the authoritative host or as a client behind one API, per the "game
/// engine must not depend directly on Android networking implementation"
/// requirement.
///
/// Implementation notes (see README "Networking Architecture" for the
/// full rationale):
///  - Room discovery: UDP broadcast on the local subnet (works over a
///    shared Wi-Fi network or a phone's mobile hotspot; no internet used).
///  - Gameplay traffic: TCP, host-authoritative, newline-delimited JSON.
///  - No Wi-Fi Direct plugin is used — see README for why.
class NearbyConnectionService {
  DeviceRole role = DeviceRole.none;
  HostServer? _host;
  GameClient? _client;
  RoomScanner? _scanner;

  final _roomController = StreamController<Room>.broadcast();
  final _stateController = StreamController<GameState>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _gameStartController = StreamController<void>.broadcast();
  final _discoveredController = StreamController<Room>.broadcast();

  Stream<Room> get roomUpdates => _roomController.stream;
  Stream<GameState> get stateUpdates => _stateController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<void> get gameStarted => _gameStartController.stream;
  Stream<Room> get discoveredRooms => _discoveredController.stream;

  /// This device's own player id, regardless of whether it's hosting or
  /// has joined as a client. Used by the UI to know which hand/seat is
  /// "mine" versus an opponent's.
  String? get myPlayerId => role == DeviceRole.host ? _host?.hostPlayerId : _client?.playerId;

  Future<String> _localIp() async {
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    return ip ?? '0.0.0.0';
  }

  // --------------------------- HOST PATH ---------------------------
  Future<Room> createRoom({
    required String hostName,
    int maxPlayers = AppConstants.maxPlayers,
    UnoPenaltyRule unoPenalty = UnoPenaltyRule.drawTwo,
    DrawRule drawRule = DrawRule.playImmediately,
  }) async {
    role = DeviceRole.host;
    _host = HostServer(
      hostPlayerName: hostName,
      maxPlayers: maxPlayers,
      unoPenalty: unoPenalty,
      drawRule: drawRule,
    );
    _host!.roomUpdates.listen(_roomController.add);
    _host!.stateUpdates.listen(_stateController.add);
    _host!.errors.listen(_errorController.add);

    final ip = await _localIp();
    await _host!.start(localIp: ip);
    return _host!.room;
  }

  void fillRemainingWithAi() => _host?.fillWithAi();
  void startGame() {
    _host?.startGame();
    _gameStartController.add(null);
  }

  void startNextRound() => _host?.startNextRound();

  // --------------------------- CLIENT PATH ---------------------------
  Future<void> startScanning() async {
    _scanner = RoomScanner();
    _scanner!.roomsFound.listen(_discoveredController.add);
    await _scanner!.start();
  }

  Future<void> stopScanning() async {
    await _scanner?.stop();
    _scanner = null;
  }

  Future<void> joinRoom({required String hostIp, required String playerName}) async {
    role = DeviceRole.client;
    _client = GameClient(hostIp: hostIp, playerName: playerName);
    _client!.roomUpdates.listen(_roomController.add);
    _client!.stateUpdates.listen(_stateController.add);
    _client!.errors.listen(_errorController.add);
    _client!.gameStarted.listen(_gameStartController.add);
    await _client!.connect();
  }

  // --------------------------- SHARED ACTIONS ---------------------------
  // On the host device, actions apply directly to the local engine. On a
  // client device, they're sent to the host over the network. Callers
  // (providers) don't need to know which.

  void playCard(String playerId, String cardId, {CardColor? chosenColor}) {
    if (role == DeviceRole.host) {
      // The host's own human player also goes through the same validated
      // engine path as a remote client's action would.
      _host?.handleLocalPlayCard(playerId, cardId, chosenColor);
    } else {
      _client?.playCard(cardId: cardId, chosenColor: chosenColor);
    }
  }

  void chooseColor(String playerId, CardColor color) {
    if (role == DeviceRole.host) {
      _host?.handleLocalChooseColor(playerId, color);
    } else {
      _client?.chooseColor(color);
    }
  }

  void drawCard(String playerId) {
    if (role == DeviceRole.host) {
      _host?.handleLocalDrawCard(playerId);
    } else {
      _client?.drawCard();
    }
  }

  void callUno(String playerId) {
    if (role == DeviceRole.host) {
      _host?.handleLocalCallUno(playerId);
    } else {
      _client?.callUno();
    }
  }

  Future<void> leave() async {
    await _host?.closeRoom();
    await _client?.disconnect();
    await stopScanning();
    role = DeviceRole.none;
  }
}
