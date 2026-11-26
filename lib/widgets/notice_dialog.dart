import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/notice.dart';
import '../theme/app_colors.dart';

AppPalette _noticePalette(BuildContext context) =>
    Theme.of(context).extension<AppPalette>() ?? AppPalette.dark;

Future<void> showNoticeDialog(BuildContext context, Notice notice) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const SizedBox();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );

      return ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1.0).animate(curve),
        child: FadeTransition(
          opacity: animation,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: LogNoticeDialog(notice: notice),
          ),
        ),
      );
    },
  );
}

class LogNoticeDialog extends StatelessWidget {
  final Notice notice;

  const LogNoticeDialog({super.key, required this.notice});

  Future<void> _dismissForever(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_read_notice_id', notice.id);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _noticePalette(context);
    final maxH = MediaQuery.of(context).size.height * 0.72;
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    final bodyStyle = TextStyle(
      fontSize: 15,
      height: 1.65,
      color: palette.textPrimary.withValues(alpha: 0.88),
    );

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: 400, maxHeight: maxH),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        notice.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (notice.imgUrl != null && notice.imgUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              notice.imgUrl!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      MarkdownBody(
                        data: notice.content,
                        styleSheet: base.copyWith(
                          p: bodyStyle,
                          h1: bodyStyle.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                          h2: bodyStyle.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                          h3: bodyStyle.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                          strong: bodyStyle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                          a: bodyStyle.copyWith(color: palette.accent),
                          listBullet: bodyStyle,
                          blockquote: bodyStyle.copyWith(
                            color: palette.textSecondary,
                          ),
                          code: bodyStyle.copyWith(
                            fontFamily: 'monospace',
                            backgroundColor: palette.surfaceAlt,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _dismissForever(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.textSecondary,
                          side: BorderSide(color: palette.border),
                          shape: const StadiumBorder(),
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text('不再提示'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.accent,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: Text(
                          AppLocalizations.of(context)?.gotIt ?? '我知道了',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
