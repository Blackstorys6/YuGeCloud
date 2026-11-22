import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'flux_loader.dart';

class StatusMessageCard extends StatelessWidget {
  final String message;
  final bool isLoading;
  final IconData? icon;
  final Color? iconColor;

  const StatusMessageCard({
    super.key,
    required this.message,
    this.isLoading = false,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();

    final palette = context.appPalette;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: palette.surfaceAlt.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: palette.border.withValues(alpha: 0.85),
          ),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(
                alpha: isLightTheme ? 0.1575 : 0.35,
              ),
              blurRadius: isLightTheme ? 4.9 : 10,
              offset: isLightTheme ? const Offset(0, 2.1) : const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: FluxLoader(size: 24, color: palette.accent),
              )
            else if (icon != null)
              Icon(
                icon,
                size: 16,
                color: iconColor ?? palette.accent,
              ),
            if (icon != null || isLoading) const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  height: 1.35,
                  letterSpacing: 0.15,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
