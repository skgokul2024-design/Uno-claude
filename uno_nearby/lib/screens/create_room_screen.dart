import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/constants.dart';
import '../providers/room_provider.dart';
import '../providers/settings_provider.dart';
import 'lobby_screen.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  final bool vsComputer;
  const CreateRoomScreen({super.key, this.vsComputer = false});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  late final TextEditingController _nameController;
  int _playerCount = 4;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: ref.read(settingsProvider).playerName);
  }

  Future<void> _create() async {
    final name = _nameController.text.trim().isEmpty ? 'Player' : _nameController.text.trim();
    setState(() => _creating = true);
    final settings = ref.read(settingsProvider);
    await ref.read(roomProvider.notifier).createRoom(
          hostName: name,
          maxPlayers: _playerCount,
          unoPenalty: settings.unoPenalty,
          drawRule: settings.drawRule,
        );
    if (widget.vsComputer) {
      ref.read(roomProvider.notifier).fillWithAi();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LobbyScreen(isHost: true, vsComputer: widget.vsComputer)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.vsComputer ? 'Play With Computer' : 'Create Game')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Player Name', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              maxLength: 16,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'e.g. Gokul'),
            ),
            const SizedBox(height: 20),
            const Text('Number of Players', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (int n = AppConstants.minPlayers; n <= AppConstants.maxPlayers; n++)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text('$n'),
                      selected: _playerCount == n,
                      onSelected: (_) => setState(() => _playerCount = n),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Game Mode', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Classic UNO', style: TextStyle(color: Colors.grey)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _creating ? null : _create,
                child: _creating
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('CREATE ROOM'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
