import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';

class GlassNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const GlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette =
        Theme.of(context).extension<AppPalette>() ?? AppPalette.dark;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 18,
        left: 18,
        right: 18,
      ),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: palette.border.withValues(alpha: 0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: 24,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _item(context, palette, 0, Icons.dashboard_rounded,
                l?.connect ?? '连接'),
            _item(context, palette, 1, Icons.layers_rounded,
                l?.subscription ?? '订阅'),
            _item(
                context, palette, 2, Icons.person_rounded, l?.profile ?? '我的'),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    AppPalette palette,
    int index,
    IconData icon,
    String label,
  ) {
    final selected = selectedIndex == index;
    final color = selected ? palette.accent : palette.textSecondary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onDestinationSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected
                ? palette.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? Border.all(
                    color: palette.accent.withValues(alpha: 0.12),
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
