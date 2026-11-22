import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final double? width;
  final double? height;
  final bool enableHover;
  final bool enableBreathing;
  final bool useSolidBackground;
  final double shadowIntensity;
  final Duration animationDuration;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.width,
    this.height,
    this.enableHover = true,
    this.enableBreathing = true,
    this.useSolidBackground = false,
    this.shadowIntensity = 1.0,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _breathingController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _breathingAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    _hoverController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _hoverController,
        curve: Curves.easeOutCubic,
      ),
    );

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _breathingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.enableBreathing) {
      _breathingController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.enableHover) {
      setState(() => _isHovered = true);
      _hoverController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.enableHover) {
      setState(() => _isHovered = false);
      _hoverController.reverse();
    }
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (widget.enableHover) {
      setState(() => _isHovered = false);
      _hoverController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final shadowIntensity = Theme.of(context).brightness == Brightness.light
        ? 0.35
        : widget.shadowIntensity;

    return GestureDetector(
      onTapDown: widget.onTap != null ? _handleTapDown : null,
      onTapUp: widget.onTap != null ? _handleTapUp : null,
      onTapCancel: widget.onTap != null ? _handleTapCancel : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _hoverController,
          _breathingController,
        ]),
        builder: (context, child) {
          final breathValue =
              widget.enableBreathing ? _breathingAnimation.value : 0.0;
          final glowOpacity =
              (0.025 + (breathValue * 0.055)) * widget.shadowIntensity;
          final borderOpacity = 0.35 + (breathValue * 0.25);

          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: widget.useSolidBackground ? palette.surface : null,
                gradient: widget.useSolidBackground
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          palette.surface,
                          Color.lerp(
                            palette.surface,
                            palette.surfaceAlt,
                            breathValue * 0.35,
                          )!,
                        ],
                      ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color:
                      (_isHovered ? palette.accent : palette.border).withValues(
                    alpha: _isHovered ? 0.8 : borderOpacity,
                  ),
                  width: _isHovered ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: glowOpacity),
                    blurRadius:
                        (18 + (breathValue * 8)) * widget.shadowIntensity,
                    spreadRadius: -2 * widget.shadowIntensity,
                  ),
                  BoxShadow(
                    color: palette.shadow
                        .withValues(alpha: 0.45 * shadowIntensity),
                    blurRadius: 14 * shadowIntensity,
                    offset: Offset(0, 6 * shadowIntensity),
                  ),
                  if (_isHovered)
                    BoxShadow(
                      color: palette.accent
                          .withValues(alpha: 0.12 * widget.shadowIntensity),
                      blurRadius: 24 * widget.shadowIntensity,
                      offset: Offset(0, 7 * widget.shadowIntensity),
                    ),
                ],
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}
