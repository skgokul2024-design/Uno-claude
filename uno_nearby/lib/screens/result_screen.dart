import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/game_model.dart';
import '../providers/settings_provider.dart';
import 'home_screen.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final GameState state;
  const ResultScreen({super.key, required this.state});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _persistResult();
  }

  /// Writes the finished match to the local SQLite database so the
  /// Statistics screen has real data. Statistics are keyed by player name,
  /// matching how StatisticsScreen reads them back — player ids are
  /// regenerated per session, so they aren't a stable key across games.
  Future<void> _persistResult() async {
    if (_saved) return;
    _saved = true;

    final state = widget.state;
    final sorted = [...state.players]..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    final placements = <Map<String, dynamic>>[];
    for (int i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      placements.add({
        'playerId': p.name, // keyed by name — see doc comment above
        'playerName': p.name,
        'placement': i + 1,
        'score': p.totalScore,
        'won': p.id == state.winnerId || i == 0,
        'unoCalls': p.hasCalledUno ? 1 : 0,
        'cardsPlayed': 0,
      });
    }

    try {
      await DatabaseHelper.instance.recordGameResult(
        gameId: state.gameId,
        roomCode: '',
        placements: placements,
        mode: state.players.any((p) => p.isAi) ? 'vs_computer' : 'multiplayer',
      );
    } catch (_) {
      // Statistics are a nice-to-have; a persistence failure must never
      // block the player from leaving the results screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final sorted = [...state.players]..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final winner = sorted.first;
    final myName = ref.watch(settingsProvider).playerName;

    return Scaffold(
      appBar: AppBar(title: const Text('Game Over'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Icon(Icons.emoji_events, color: Colors.amber, size: 72),
            const SizedBox(height: 8),
            Text(
              winner.name == myName ? 'You Win!' : '${winner.name} Wins!',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) {
                  final p = sorted[i];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(p.name),
                    subtitle: p.isAi ? const Text('Computer') : null,
                    trailing: Text('${p.totalScore} pts',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false),
                child: const Text('BACK TO HOME'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
