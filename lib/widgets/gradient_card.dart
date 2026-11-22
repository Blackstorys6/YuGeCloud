import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const GradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: palette.border.withValues(alpha: 0.85),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withValues(
                  alpha: isLightTheme ? 0.1575 : 0.65,
                ),
                blurRadius: isLightTheme ? 4.9 : 18,
                offset:
                    isLightTheme ? const Offset(0, 2.1) : const Offset(0, 7),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                colors: [
                  palette.glassOverlay.withValues(alpha: 0.42),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
