import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _Logo(),
              const SizedBox(height: 12),
              Text(
                'Play Anywhere.\nPlay Together.\nNo Internet Required.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600, height: 1.4),
              ),
              const Spacer(flex: 3),
              _MenuButton(
                label: 'CREATE GAME',
                color: AppColors.red,
                icon: Icons.add_circle_outline,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
                ),
              ),
              const SizedBox(height: 14),
              _MenuButton(
                label: 'JOIN GAME',
                color: AppColors.blue,
                icon: Icons.wifi_tethering,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
                ),
              ),
              const SizedBox(height: 14),
              _MenuButton(
                label: 'PLAY WITH COMPUTER',
                color: AppColors.green,
                icon: Icons.smart_toy_outlined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateRoomScreen(vsComputer: true)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _SmallButton(
                      label: 'Statistics',
                      icon: Icons.bar_chart,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SmallButton(
                      label: 'Settings',
                      icon: Icons.settings_outlined,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.red,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: AppColors.red.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: const Text('UNO',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 44, letterSpacing: 2)),
        ),
        const SizedBox(height: 6),
        const Text('N E A R B Y',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: 6)),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _MenuButton({required this.label, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SmallButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
    );
  }
}
