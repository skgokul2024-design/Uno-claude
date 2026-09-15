import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/constants.dart';
import '../database/database_helper.dart';

class AppSettings {
  final String playerName;
  final bool soundEnabled;
  final bool musicEnabled;
  final bool vibrationEnabled;
  final bool animationsEnabled;
  final bool darkMode;
  final UnoPenaltyRule unoPenalty;
  final DrawRule drawRule;

  const AppSettings({
    this.playerName = '',
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.vibrationEnabled = true,
    this.animationsEnabled = true,
    this.darkMode = false,
    this.unoPenalty = UnoPenaltyRule.drawTwo,
    this.drawRule = DrawRule.playImmediately,
  });

  AppSettings copyWith({
    String? playerName,
    bool? soundEnabled,
    bool? musicEnabled,
    bool? vibrationEnabled,
    bool? animationsEnabled,
    bool? darkMode,
    UnoPenaltyRule? unoPenalty,
    DrawRule? drawRule,
  }) =>
      AppSettings(
        playerName: playerName ?? this.playerName,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        musicEnabled: musicEnabled ?? this.musicEnabled,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
        animationsEnabled: animationsEnabled ?? this.animationsEnabled,
        darkMode: darkMode ?? this.darkMode,
        unoPenalty: unoPenalty ?? this.unoPenalty,
        drawRule: drawRule ?? this.drawRule,
      );
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier()..load();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());
  final _db = DatabaseHelper.instance;

  Future<void> load() async {
    final name = await _db.getSetting('playerName') ?? '';
    final sound = await _db.getSetting('soundEnabled');
    final music = await _db.getSetting('musicEnabled');
    final vibration = await _db.getSetting('vibrationEnabled');
    final animations = await _db.getSetting('animationsEnabled');
    final dark = await _db.getSetting('darkMode');
    final penalty = await _db.getSetting('unoPenalty');
    final draw = await _db.getSetting('drawRule');

    state = AppSettings(
      playerName: name,
      soundEnabled: sound != 'false',
      musicEnabled: music != 'false',
      vibrationEnabled: vibration != 'false',
      animationsEnabled: animations != 'false',
      darkMode: dark == 'true',
      unoPenalty: penalty != null
          ? UnoPenaltyRule.values.byName(penalty)
          : UnoPenaltyRule.drawTwo,
      drawRule: draw != null ? DrawRule.values.byName(draw) : DrawRule.playImmediately,
    );
  }

  Future<void> update(AppSettings next) async {
    state = next;
    await _db.setSetting('playerName', next.playerName);
    await _db.setSetting('soundEnabled', next.soundEnabled.toString());
    await _db.setSetting('musicEnabled', next.musicEnabled.toString());
    await _db.setSetting('vibrationEnabled', next.vibrationEnabled.toString());
    await _db.setSetting('animationsEnabled', next.animationsEnabled.toString());
    await _db.setSetting('darkMode', next.darkMode.toString());
    await _db.setSetting('unoPenalty', next.unoPenalty.name);
    await _db.setSetting('drawRule', next.drawRule.name);
  }
}
