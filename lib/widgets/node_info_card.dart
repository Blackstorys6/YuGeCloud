import 'package:flutter/material.dart';

import '../models/server_node.dart';
import '../utils/node_utils.dart';
import '../theme/app_colors.dart';

class NodeInfoCard extends StatelessWidget {
  final ServerNode node;

  const NodeInfoCard({
    super.key,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final latencyColor = node.latency == null
        ? palette.textSecondary
        : node.latency! < 100
            ? palette.success
            : node.latency! < 300
                ? palette.warning
                : palette.danger;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.surface,
              palette.surfaceAlt,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: palette.border.withValues(alpha: 0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(
                alpha: 0.6,
              ),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: palette.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    NodeUtils.extractCountry(node.name, context: context),
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (node.latency != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.speed_rounded,
                      size: 16,
                      color: latencyColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${node.latency}ms',
                      style: TextStyle(
                        fontSize: 13,
                        color: latencyColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
