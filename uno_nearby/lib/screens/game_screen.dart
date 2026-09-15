import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../models/card_model.dart';
import '../models/game_model.dart';
import '../models/player_model.dart';
import '../providers/game_provider.dart';
import '../widgets/uno_card.dart';
import 'home_screen.dart';
import 'result_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  String? _selectedCardId;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameStateProvider);
    final myId = ref.watch(myPlayerIdProvider);

    ref.listen(gameStateProvider, (prev, next) {
      if (next != null && next.status == GameStatus.gameOver) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ResultScreen(state: next)),
        );
      }
      if (next != null &&
          next.pendingWildPlayerId == myId &&
          prev?.pendingWildPlayerId != myId) {
        _showColorPicker(context, myId!);
      }
    });

    if (state == null || myId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final me = state.players.firstWhere((p) => p.id == myId);
    final opponents = state.players.where((p) => p.id != myId).toList();
    final isMyTurn = state.currentPlayer.id == myId && state.pendingWildPlayerId == null;
    final canDraw = isMyTurn;

    return Scaffold(
      backgroundColor: const Color(0xFF0B6E4F),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onExit: () => _confirmExit(context)),
            Expanded(
              flex: 2,
              child: _OpponentsRow(opponents: opponents, currentPlayerId: state.currentPlayer.id),
            ),
            Expanded(
              flex: 3,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (state.topCard != null)
                      UnoCardWidget(card: state.topCard!, width: 90, faceDown: false),
                    const SizedBox(width: 28),
                    GestureDetector(
                      onTap: canDraw ? () => ref.read(gameStateProvider.notifier).drawCard(myId) : null,
                      child: Opacity(
                        opacity: canDraw ? 1 : 0.5,
                        child: Column(
                          children: [
                            UnoCardWidget(
                              card: UnoCard(color: CardColor.wild, type: CardType.wild),
                              faceDown: true,
                              width: 90,
                            ),
                            const SizedBox(height: 4),
                            Text('${state.deckCount}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _StatusBar(state: state, isMyTurn: isMyTurn),
            _MyHand(
              player: me,
              isMyTurn: isMyTurn,
              topCard: state.topCard,
              currentColor: state.currentColor,
              drawStackCount: state.drawStackCount,
              selectedCardId: _selectedCardId,
              onSelect: (id) => setState(() => _selectedCardId = id == _selectedCardId ? null : id),
              onConfirmPlay: (card) {
                if (card.isWild) {
                  _showColorPicker(context, myId, pendingCardId: card.id);
                } else {
                  ref.read(gameStateProvider.notifier).playCard(myId, card.id);
                  setState(() => _selectedCardId = null);
                }
              },
            ),
            _ActionRow(
              canCallUno: me.cardCount == 2 && !me.hasCalledUno,
              onCallUno: () => ref.read(gameStateProvider.notifier).callUno(myId),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, String myId, {String? pendingCardId}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Choose a Color'),
        content: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [CardColor.red, CardColor.blue, CardColor.green, CardColor.yellow].map((c) {
            return GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                if (pendingCardId != null) {
                  ref.read(gameStateProvider.notifier).playCard(myId, pendingCardId, chosenColor: c);
                  setState(() => _selectedCardId = null);
                } else {
                  ref.read(gameStateProvider.notifier).chooseColor(myId, c);
                }
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: AppColors.forCardColor(c),
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Game?'),
        content: const Text('You can try to reconnect if you leave by accident.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true && context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
    }
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onExit;
  const _TopBar({required this.onExit});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            IconButton(onPressed: onExit, icon: const Icon(Icons.menu, color: Colors.white)),
            const Spacer(),
            const Icon(Icons.wifi, color: Colors.white70, size: 18),
          ],
        ),
      );
}

class _OpponentsRow extends StatelessWidget {
  final List<Player> opponents;
  final String currentPlayerId;
  const _OpponentsRow({required this.opponents, required this.currentPlayerId});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      runSpacing: 12,
      children: opponents.map((p) {
        final isTurn = p.id == currentPlayerId;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: isTurn ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: isTurn ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(p.isAi ? Icons.smart_toy : Icons.person, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text('${p.cardCount} cards', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (p.connectionState.name != 'connected')
                const Text('reconnecting…', style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final GameState state;
  final bool isMyTurn;
  const _StatusBar({required this.state, required this.isMyTurn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                    color: AppColors.forCardColor(state.currentColor), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('Current Color: ${state.currentColor.name.toUpperCase()}',
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
          Text(
            isMyTurn ? 'Your Turn' : "${state.currentPlayer.name}'s Turn",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: isMyTurn ? 18 : 14),
          ),
          if (state.drawStackCount > 0)
            Text('Draw ${state.drawStackCount} pending!',
                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _MyHand extends StatelessWidget {
  final Player player;
  final bool isMyTurn;
  final UnoCard? topCard;
  final CardColor currentColor;
  final int drawStackCount;
  final String? selectedCardId;
  final ValueChanged<String> onSelect;
  final ValueChanged<UnoCard> onConfirmPlay;

  const _MyHand({
    required this.player,
    required this.isMyTurn,
    required this.topCard,
    required this.currentColor,
    required this.drawStackCount,
    required this.selectedCardId,
    required this.onSelect,
    required this.onConfirmPlay,
  });

  bool _isPlayable(UnoCard c) {
    if (!isMyTurn) return false;
    if (drawStackCount > 0) {
      return c.type == CardType.drawTwo || c.type == CardType.wildDrawFour;
    }
    if (topCard == null) return true;
    if (c.isWild) return true;
    if (c.color == currentColor) return true;
    if (c.type == CardType.number && topCard!.type == CardType.number && c.number == topCard!.number) {
      return true;
    }
    if (c.type != CardType.number && c.type == topCard!.type) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: player.hand.map((c) {
          final playable = _isPlayable(c);
          final selected = c.id == selectedCardId;
          return GestureDetector(
            onTap: !playable
                ? null
                : () {
                    onSelect(c.id);
                    if (!selected) {
                      onConfirmPlay(c);
                    }
                  },
            child: UnoCardWidget(card: c, width: 78, selected: selected, dimmed: !playable),
          );
        }).toList(),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final bool canCallUno;
  final VoidCallback onCallUno;
  const _ActionRow({required this.canCallUno, required this.onCallUno});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: AnimatedOpacity(
        opacity: canCallUno ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !canCallUno,
          child: ElevatedButton(
            onPressed: onCallUno,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: const Text('UNO!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ),
        ),
      ),
    );
  }
}
