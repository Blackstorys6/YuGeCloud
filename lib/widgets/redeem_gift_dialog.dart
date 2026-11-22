import 'dart:ui';
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../services/v2board_api.dart';

class RedeemGiftDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const RedeemGiftDialog({super.key, required this.onSuccess});

  @override
  State<RedeemGiftDialog> createState() => _RedeemGiftDialogState();
}

class _RedeemGiftDialogState extends State<RedeemGiftDialog>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _breatheAnim;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _breatheAnim = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final api = V2BoardApi();
      final success = await api.redeemGiftCard(code);

      if (success) {
        // Refresh user info
        await api.getUserInfo();

        if (mounted) {
          widget.onSuccess();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.redeemSuccess ??
                  'Redeem success'),
              backgroundColor: context.appPalette.success,
            ),
          );
        }
      } else {
        setState(() => _errorText =
            AppLocalizations.of(context)?.invalidCode ?? 'Invalid code');
      }
    } catch (e) {
      setState(() => _errorText =
          '${AppLocalizations.of(context)?.redeemFailed ?? "Redeem failed"}: ${e.toString().replaceAll("Exception:", "")}');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _breatheAnim,
          builder: (context, child) {
            return Container(
              width: 340,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: palette.border,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                  // Breathing Glow
                  BoxShadow(
                    color: palette.accent
                        .withValues(alpha: _breatheAnim.value * 0.22),
                    blurRadius: 20 + (_breatheAnim.value * 10),
                    spreadRadius: -5 + (_breatheAnim.value * 5),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon Header with gentle pulse
                    AnimatedBuilder(
                      animation: _breatheAnim,
                      builder: (context, _) => Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(
                              alpha: 0.10 + (_breatheAnim.value * 0.05)),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: palette.accent
                                  .withValues(alpha: _breatheAnim.value * 0.16),
                              blurRadius: 16,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Icon(
                          Icons.card_giftcard_rounded,
                          color: palette.accent,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      AppLocalizations.of(context)?.redeemGiftCard ??
                          'Redeem Gift Card',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: palette.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)?.enterCode ??
                          'Enter your code',
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Input Field
                    TextField(
                      controller: _controller,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: palette.accent,
                      decoration: InputDecoration(
                        hintText: 'ABCD-1234-EFGH-5678',
                        hintStyle: TextStyle(
                          color: palette.textSecondary.withValues(alpha: 0.65),
                          fontSize: 15,
                        ),
                        filled: true,
                        fillColor: palette.surfaceAlt,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: palette.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: palette.accent,
                          ),
                        ),
                        errorText: _errorText,
                        errorMaxLines: 5,
                        errorStyle: TextStyle(color: palette.danger),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              foregroundColor: palette.textSecondary,
                            ),
                            child: Text(AppLocalizations.of(context)?.cancel ??
                                'Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              // SILVER GRADIENT Black & Silver Theme
                              color: palette.accent,
                              boxShadow: [
                                BoxShadow(
                                  color: palette.accent.withValues(alpha: 0.20),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: palette.accent,
                                foregroundColor: palette.background,
                                disabledBackgroundColor:
                                    palette.accent.withValues(alpha: 0.5),
                                shadowColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isSubmitting
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: palette.background,
                                      ),
                                    )
                                  : Text(
                                      AppLocalizations.of(context)?.redeemNow ??
                                          'Redeem Now',
                                      style: TextStyle(
                                        color: palette.background,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
