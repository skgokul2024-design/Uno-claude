import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';
import '../providers/room_provider.dart';
import 'game_screen.dart';
import 'home_screen.dart';

class LobbyScreen extends ConsumerWidget {
  final bool isHost;
  final bool vsComputer;
  const LobbyScreen({super.key, required this.isHost, this.vsComputer = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomProvider);

    ref.listen(gameStateProvider, (prev, next) {
      if (next != null) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen()));
      }
    });

    if (room == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Created'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              await ref.read(roomProvider.notifier).leave();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Room Code', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(room.roomCode,
                style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 6)),
            const SizedBox(height: 4),
            Text('Your IP: ${room.hostIp}  (share this if auto-discovery fails)',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            Text('Host: ${room.hostName}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text('Players', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final p in room.players)
                    ListTile(
                      leading: const Icon(Icons.circle, color: Colors.green, size: 14),
                      title: Text(p.name),
                      trailing: p.isAi ? const Icon(Icons.smart_toy_outlined) : null,
                    ),
                  for (int i = room.players.length; i < room.maxPlayers; i++)
                    const ListTile(
                      leading: Icon(Icons.circle_outlined, color: Colors.grey, size: 14),
                      title: Text('Waiting...', style: TextStyle(color: Colors.grey)),
                    ),
                ],
              ),
            ),
            if (isHost) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: room.canStart ? () => ref.read(roomProvider.notifier).startGame() : null,
                  child: const Text('START GAME'),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () async {
                  await ref.read(roomProvider.notifier).leave();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
                  }
                },
                child: const Text('CLOSE ROOM'),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Waiting for the host to start the game…',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}
