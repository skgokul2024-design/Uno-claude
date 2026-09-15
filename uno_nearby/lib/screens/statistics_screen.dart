import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../providers/settings_provider.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = ref.read(settingsProvider).playerName;
    // Local player statistics are keyed by name here for simplicity, since
    // a device may not always reuse the same generated player id across
    // sessions. All data stays in the on-device SQLite database.
    final stats = await DatabaseHelper.instance.getStatistics(name);
    setState(() => _stats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final played = s?['games_played'] as int? ?? 0;
    final wins = s?['wins'] as int? ?? 0;
    final losses = s?['losses'] as int? ?? 0;
    final winRate = played == 0 ? 0 : ((wins / played) * 100).round();
    final highScore = s?['highest_score'] as int? ?? 0;
    final unoCalls = s?['uno_calls'] as int? ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Games Played', value: '$played')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Win Rate', value: '$winRate%')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Wins', value: '$wins')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Losses', value: '$losses')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Highest Score', value: '$highScore')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'UNO Calls', value: '$unoCalls')),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              final name = ref.read(settingsProvider).playerName;
              await DatabaseHelper.instance.resetStatistics(name);
              _load();
            },
            child: const Text('RESET'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
