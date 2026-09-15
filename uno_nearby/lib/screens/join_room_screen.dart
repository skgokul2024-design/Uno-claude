import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room_model.dart';
import '../providers/room_provider.dart';
import '../providers/settings_provider.dart';
import 'lobby_screen.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _ipController = TextEditingController();
  final _nameController = TextEditingController();
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = ref.read(settingsProvider).playerName;
  }

  Future<void> _join(String hostIp) async {
    final name = _nameController.text.trim().isEmpty ? 'Player' : _nameController.text.trim();
    setState(() => _joining = true);
    await ref.read(roomProvider.notifier).joinRoom(hostIp: hostIp, playerName: name);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LobbyScreen(isHost: false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discovered = ref.watch(discoveredRoomsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Join Game')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Name', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              maxLength: 16,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('Nearby Games', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: discovered.when(
                data: (rooms) => rooms.isEmpty
                    ? _EmptyState(onRetry: () => setState(() {}))
                    : ListView.separated(
                        itemCount: rooms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _RoomTile(
                          room: rooms[i],
                          onJoin: _joining ? null : () => _join(rooms[i].hostIp),
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _EmptyState(onRetry: () => setState(() {})),
              ),
            ),
            const Divider(height: 32),
            const Text('Connect by IP Address', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              "If a room isn't discovered automatically, enter the host device's local IP "
              '(shown on their "Room Created" screen) — both devices must be on the same '
              'Wi-Fi network or hotspot.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(), hintText: '192.168.1.23'),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _joining || _ipController.text.trim().isEmpty
                      ? null
                      : () => _join(_ipController.text.trim()),
                  child: const Text('JOIN'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final Room room;
  final VoidCallback? onJoin;
  const _RoomTile({required this.room, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('${room.hostName}\'s Room'),
        subtitle: Text('Players: ${room.players.length}/${room.maxPlayers} • Code ${room.roomCode}'),
        trailing: ElevatedButton(
          onPressed: room.isFull ? null : onJoin,
          child: Text(room.isFull ? 'FULL' : 'JOIN'),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_find, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('No nearby games found.', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Check:\n• Wi-Fi is on and shared with the host\n• Nearby-device permission is granted\n• Device visibility\n• Distance between devices',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('SEARCH AGAIN')),
        ],
      ),
    );
  }
}
