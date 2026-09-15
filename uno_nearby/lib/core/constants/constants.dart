/// App-wide constants. Nothing here reaches out to the network or cloud —
/// all values are local/offline configuration.
class AppConstants {
  AppConstants._();

  static const String appName = 'UNO Nearby';
  static const String tagline = 'Play Anywhere. Play Together. No Internet Required.';

  /// TCP port the host listens on for gameplay traffic.
  static const int gamePort = 58910;

  /// UDP port used for local room-discovery broadcasts.
  static const int discoveryPort = 58911;

  static const int minPlayers = 2;
  static const int maxPlayers = 4;

  static const int startingHandSize = 7;

  /// How often (ms) the host broadcasts its presence via UDP so clients on
  /// the "Join Game" screen can find it without a manual room code.
  static const int discoveryBroadcastIntervalMs = 1500;

  /// Heartbeat interval for detecting silently-dropped connections.
  static const int heartbeatIntervalMs = 2000;
  static const int heartbeatTimeoutMs = 7000;

  /// How long the host waits for a disconnected player to reconnect
  /// before marking their seat permanently vacated.
  static const int reconnectGraceMs = 60000;

  static const String roomCodeChars = '0123456789';
  static const int roomCodeLength = 6;
}

enum UnoPenaltyRule {
  /// Player must draw 2 cards if caught without calling UNO in time.
  drawTwo,
  /// Player must draw 4 cards if caught without calling UNO in time.
  drawFour,
  /// No penalty enforced.
  off,
}

enum DrawRule {
  /// Player may immediately play a card they just drew, if legal.
  playImmediately,
  /// Turn always passes after a forced draw.
  passAfterDraw,
}
