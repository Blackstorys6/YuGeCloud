import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'flux_loader.dart';

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final enabled = onPressed != null;
    final foreground = enabled
        ? palette.accent
        : palette.textSecondary.withValues(alpha: 0.55);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.surfaceAlt.withValues(
                  alpha: enabled ? 0.95 : 0.55,
                ),
                palette.surface.withValues(
                  alpha: enabled ? 0.9 : 0.6,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: (enabled ? palette.accent : palette.border)
                  .withValues(alpha: enabled ? 0.24 : 0.55),
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: FluxLoader(size: 20, color: foreground),
                )
              else
                Icon(
                  icon,
                  size: 18,
                  color: foreground,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
