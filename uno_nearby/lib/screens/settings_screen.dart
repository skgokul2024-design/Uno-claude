import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/constants.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: ref.read(settingsProvider).playerName);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Player Name', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            maxLength: 16,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (v) => notifier.update(settings.copyWith(playerName: v)),
          ),
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('Sound'),
            value: settings.soundEnabled,
            onChanged: (v) => notifier.update(settings.copyWith(soundEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('Music'),
            value: settings.musicEnabled,
            onChanged: (v) => notifier.update(settings.copyWith(musicEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('Vibration'),
            value: settings.vibrationEnabled,
            onChanged: (v) => notifier.update(settings.copyWith(vibrationEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('Animations'),
            value: settings.animationsEnabled,
            onChanged: (v) => notifier.update(settings.copyWith(animationsEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: settings.darkMode,
            onChanged: (v) => notifier.update(settings.copyWith(darkMode: v)),
          ),
          const Divider(height: 32),
          const Text('UNO Penalty', style: TextStyle(fontWeight: FontWeight.w600)),
          RadioListTile<UnoPenaltyRule>(
            title: const Text('Draw 2 cards'),
            value: UnoPenaltyRule.drawTwo,
            groupValue: settings.unoPenalty,
            onChanged: (v) => notifier.update(settings.copyWith(unoPenalty: v)),
          ),
          RadioListTile<UnoPenaltyRule>(
            title: const Text('Draw 4 cards'),
            value: UnoPenaltyRule.drawFour,
            groupValue: settings.unoPenalty,
            onChanged: (v) => notifier.update(settings.copyWith(unoPenalty: v)),
          ),
          RadioListTile<UnoPenaltyRule>(
            title: const Text('Off'),
            value: UnoPenaltyRule.off,
            groupValue: settings.unoPenalty,
            onChanged: (v) => notifier.update(settings.copyWith(unoPenalty: v)),
          ),
          const Divider(height: 32),
          const Text('Draw Rule', style: TextStyle(fontWeight: FontWeight.w600)),
          RadioListTile<DrawRule>(
            title: const Text('Play immediately if legal'),
            value: DrawRule.playImmediately,
            groupValue: settings.drawRule,
            onChanged: (v) => notifier.update(settings.copyWith(drawRule: v)),
          ),
          RadioListTile<DrawRule>(
            title: const Text('Always pass after drawing'),
            value: DrawRule.passAfterDraw,
            groupValue: settings.drawRule,
            onChanged: (v) => notifier.update(settings.copyWith(drawRule: v)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => notifier.update(settings.copyWith(playerName: _nameController.text)),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}
