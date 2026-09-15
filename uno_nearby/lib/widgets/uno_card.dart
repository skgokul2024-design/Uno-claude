import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/card_model.dart';

/// Renders a single UNO card face. Purely presentational — all game logic
/// lives in the engine/providers; this widget only knows how to draw a
/// [UnoCard] and report taps.
class UnoCardWidget extends StatelessWidget {
  final UnoCard card;
  final bool faceDown;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;
  final double width;

  const UnoCardWidget({
    super.key,
    required this.card,
    this.faceDown = false,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
    this.width = 72,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * 1.5;
    final color = faceDown ? AppColors.wildDark : AppColors.forCardColor(card.effectiveColor == CardColor.wild ? card.color : card.effectiveColor);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: selected ? (Matrix4.identity()..translate(0.0, -14.0)) : Matrix4.identity(),
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: faceDown ? AppColors.wildDark : Colors.white,
          borderRadius: BorderRadius.circular(width * 0.16),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.35 : 0.2),
              blurRadius: selected ? 10 : 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Opacity(
          opacity: dimmed ? 0.45 : 1.0,
          child: faceDown
              ? Center(
                  child: Text('UNO',
                      style: TextStyle(
                          color: AppColors.red,
                          fontWeight: FontWeight.w900,
                          fontSize: width * 0.18)),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(width * 0.13),
                  child: Container(
                    color: color,
                    alignment: Alignment.center,
                    child: Text(
                      card.displayLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: card.color == CardColor.yellow ? Colors.black87 : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: card.type.name == 'number' ? width * 0.42 : width * 0.19,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
