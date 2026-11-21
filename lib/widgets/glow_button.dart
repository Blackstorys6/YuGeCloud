import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'flux_loader.dart';

class GlowButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  const GlowButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return AnimatedOpacity(
      opacity: onPressed == null ? 0.55 : 1,
      duration: const Duration(milliseconds: 250),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.accent,
              palette.accentSoft,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 50),
            backgroundColor: Colors.transparent,
            foregroundColor: palette.surface,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: onPressed,
          child: isLoading
              ? SizedBox(
                  height: 22,
                  width: 22,
                  child: FluxLoader(
                    size: 22,
                    color: palette.surface,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: palette.surface),
                      const SizedBox(width: 9),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: palette.surface,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
