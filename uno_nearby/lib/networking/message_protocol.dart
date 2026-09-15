import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/network_message.dart';

/// Wraps a raw [Socket] with newline-delimited JSON framing so partial TCP
/// reads/writes never corrupt a message. Each [NetworkMessage] is encoded
/// as a single line of JSON terminated by '\n'.
class FramedSocket {
  final Socket socket;
  final _controller = StreamController<NetworkMessage>.broadcast();
  final _buffer = StringBuffer();
  StreamSubscription<List<int>>? _sub;

  FramedSocket(this.socket) {
    socket.setOption(SocketOption.tcpNoDelay, true);
    _sub = socket.cast<List<int>>().transform(utf8.decoder).listen(
      _onData,
      onDone: () => _controller.close(),
      onError: (Object _, StackTrace __) => _controller.close(),
      cancelOnError: true,
    );
  }

  Stream<NetworkMessage> get messages => _controller.stream;

  void _onData(String chunk) {
    _buffer.write(chunk);
    final content = _buffer.toString();
    final lines = content.split('\n');
    // Keep the last (possibly incomplete) fragment in the buffer.
    _buffer
      ..clear()
      ..write(lines.last);

    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final msg = NetworkMessage.tryDecode(line);
      if (msg != null) _controller.add(msg);
      // Malformed frames are silently dropped rather than crashing the
      // connection — a single bad packet should never take the app down.
    }
  }

  void send(NetworkMessage message) {
    try {
      socket.write('${message.encode()}\n');
    } catch (_) {
      // Socket already closed / unreachable — caller's heartbeat logic
      // will notice the resulting silence and mark the peer disconnected.
    }
  }

  Future<void> close() async {
    await _sub?.cancel();
    await _controller.close();
    await socket.close();
  }
}
