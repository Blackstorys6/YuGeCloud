import 'package:flutter/material.dart';
import '../models/server_node.dart';
import '../utils/node_utils.dart';
import '../theme/app_colors.dart';

/// 节点信息卡片组件
class NodeInfoCard extends StatelessWidget {
  final ServerNode node;

  const NodeInfoCard({
    super.key,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    final latencyColor = node.latency == null
        ? AppColors.textSecondary
        : node.latency! < 100
            ? AppColors.success
            : node.latency! < 300
                ? AppColors.warning
                : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF7F5FC),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
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
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    NodeUtils.extractCountry(node.name, context: context),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
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
                        fontSize: 14,
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
