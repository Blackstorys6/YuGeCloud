import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../models/plan.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

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
    final palette = context.appPalette;
    final prices = _prices();
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    final body = TextStyle(
      fontSize: 15,
      height: 1.65,
      color: palette.textPrimary.withValues(alpha: 0.9),
    );
    final content = (plan.content ?? '').trim();
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: Text('套餐详情')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: palette.border.withValues(alpha: 0.75)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.name,
                              style: TextStyle(
                                color: palette.textPrimary,
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
                              color: palette.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              Formatters.formatBytes(plan.transferEnable),
                              style: TextStyle(
                                color: palette.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (prices.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          '价格',
                          style: TextStyle(
                            color: palette.textSecondary,
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
                                  color: palette.surfaceAlt,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.key,
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '¥${Formatters.formatCurrency(p.value)}',
                                      style: TextStyle(
                                        color: palette.textPrimary,
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
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: palette.border.withValues(alpha: 0.75)),
                  ),
                  child: content.isEmpty
                      ? Text(
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
                              color: palette.textPrimary,
                            ),
                            a: body.copyWith(color: palette.accent),
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
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    '立即购买',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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
