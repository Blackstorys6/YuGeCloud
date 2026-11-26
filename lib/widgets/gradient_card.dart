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

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 20,
          sigmaY: 20,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: palette.surface.withValues(
              alpha: 0.78,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: palette.border.withValues(
                alpha: 0.72,
              ),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withValues(
                  alpha: 0.52,
                ),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                colors: [
                  palette.glassOverlay.withValues(
                    alpha: 0.48,
                  ),
                  palette.glassOverlay.withValues(
                    alpha: 0.04,
                  ),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.38, 1.0],
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
