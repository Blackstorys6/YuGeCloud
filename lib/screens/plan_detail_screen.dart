import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../models/plan.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'orders_screen.dart';

/// 套餐详情页：Markdown 介绍 + 各周期价格 + 立即购买
class PlanDetailScreen extends StatelessWidget {
  final Plan plan;
  const PlanDetailScreen({super.key, required this.plan});

  List<MapEntry<String, int>> _prices() {
    final all = <MapEntry<String, int?>>[
      MapEntry('月付', plan.monthPrice),
      MapEntry('季付', plan.quarterPrice),
      MapEntry('半年付', plan.halfYearPrice),
      MapEntry('年付', plan.yearPrice),
      MapEntry('两年付', plan.twoYearPrice),
      MapEntry('三年付', plan.threeYearPrice),
      MapEntry('一次性', plan.onetimePrice),
      MapEntry('重置流量', plan.resetPrice),
    ];
    return [
      for (final e in all)
        if (e.value != null) MapEntry(e.key, e.value!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final prices = _prices();
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    final body = TextStyle(
      fontSize: 15,
      height: 1.65,
      color: AppColors.textPrimary.withValues(alpha: 0.88),
    );
    final content = (plan.content ?? '').trim();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('套餐详情')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              Formatters.formatBytes(plan.transferEnable),
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (prices.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const Text(
                          '价格',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final p in prices)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.key,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '¥${Formatters.formatCurrency(p.value)}',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: content.isEmpty
                      ? const Text(
                          '暂无套餐介绍',
                          style: TextStyle(color: AppColors.textSecondary),
                        )
                      : MarkdownBody(
                          data: content,
                          styleSheet: base.copyWith(
                            p: body,
                            h1: body.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                            h2: body.copyWith(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                            h3: body.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                            strong: body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            a: body.copyWith(color: AppColors.accent),
                            listBullet: body,
                            blockquote: body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => OrdersScreen(selectedPlan: plan),
                      ),
                    );
                    if (result == true && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    '立即购买',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
