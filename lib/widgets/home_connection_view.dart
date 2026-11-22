import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/server_node.dart';
import '../utils/node_utils.dart';
import '../services/v2ray_service.dart';
import 'connection_button.dart' show ConnectionButtonStatus;

/// 主页连接视图 - 中心区域
class HomeConnectionView extends StatefulWidget {
  final ConnectionButtonStatus status;
  final VoidCallback? onConnectTap;
  final bool isLoading;
  final ServerNode? selectedNode;

  const HomeConnectionView({
    super.key,
    required this.status,
    required this.onConnectTap,
    this.isLoading = false,
    this.selectedNode,
  });

  @override
  State<HomeConnectionView> createState() => _HomeConnectionViewState();
}

class _HomeConnectionViewState extends State<HomeConnectionView>
    with TickerProviderStateMixin {
  double _buttonScale = 1.0;
  late AnimationController _loopController;

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.status == ConnectionButtonStatus.connecting ||
        widget.isLoading) {
      _loopController.repeat();
    }
    // 恢复 Tun 模式状态
    V2rayService().loadTunState();
  }

  @override
  void didUpdateWidget(HomeConnectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasBusy = oldWidget.isLoading ||
        oldWidget.status == ConnectionButtonStatus.connecting;
    final isBusy =
        widget.isLoading || widget.status == ConnectionButtonStatus.connecting;
    if (wasBusy != isBusy) {
      if (isBusy) {
        _loopController.repeat();
      } else {
        _loopController.stop();
        _loopController.reset();
      }
    }
  }

  @override
  void dispose() {
    _loopController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _buttonScale = 0.96);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _buttonScale = 1.0);
  }

  void _handleTapCancel() {
    setState(() => _buttonScale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isBusy =
        widget.isLoading || widget.status == ConnectionButtonStatus.connecting;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final style =
        widget.isLoading && widget.status == ConnectionButtonStatus.disconnected
            ? _StatusStyle(
                accent: const Color(0xFFB8C0CC),
                action: AppLocalizations.of(context)?.syncing ?? 'Syncing',
              )
            : _statusStyle(context, widget.status);
    if (reduceMotion && _loopController.isAnimating) {
      _loopController.stop();
    } else if (!reduceMotion &&
        (widget.isLoading ||
            widget.status == ConnectionButtonStatus.connecting) &&
        !_loopController.isAnimating) {
      _loopController.repeat();
    }
    final buttonDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
    final textDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 180);
    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonWidth = (constraints.maxWidth * 0.60).clamp(190.0, 270.0);
        final indicatorTarget =
            widget.status == ConnectionButtonStatus.connecting ? 1.0 : 0.0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: _getStatusText(context, widget.status),
              button: true,
              enabled: true,
              child: GestureDetector(
                onTapDown: _handleTapDown,
                onTapUp: _handleTapUp,
                onTapCancel: _handleTapCancel,
                onTap: widget.onConnectTap,
                child: AnimatedScale(
                  scale: _buttonScale,
                  duration: buttonDuration,
                  curve: Curves.easeOutCubic,
                  child: RepaintBoundary(
                    child: AnimatedContainer(
                      duration: buttonDuration,
                      curve: Curves.easeOutCubic,
                      width: buttonWidth,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _surfaceColor(context, widget.status),
                            Color.lerp(
                              _surfaceColor(context, widget.status),
                              context.appPalette.surface,
                              0.16,
                            )!,
                          ],
                        ),
                        border: Border.all(
                          color: style.accent
                              .withValues(alpha: isBusy ? 0.25 : 0.45),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.appPalette.shadow
                                .withValues(alpha: 0.35),
                            blurRadius: 11,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isBusy && !reduceMotion)
                            _buildBusyEffects(style, buttonWidth),
                          Positioned(
                            bottom: 12,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(end: indicatorTarget),
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Container(
                                  width: (buttonWidth - 80) * value,
                                  height: 1.2,
                                  decoration: BoxDecoration(
                                    color: style.accent.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                );
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: textDuration,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                                ),
                                child: _buildIndicator(
                                    style, isBusy, reduceMotion),
                              ),
                              const SizedBox(width: 14),
                              AnimatedSwitcher(
                                duration: textDuration,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.2),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                                child: Text(
                                  style.action,
                                  key: ValueKey(style.action),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                    color: Colors.white,
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
            const SizedBox(height: 22),
            // Node Info
            SizedBox(
              height: 52,
              child: AnimatedOpacity(
                duration: textDuration,
                opacity: widget.selectedNode != null ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: widget.selectedNode == null,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: widget.selectedNode != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: context.appPalette.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: context.appPalette.border,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.public,
                                  size: 16,
                                  color: context.appPalette.accent,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  NodeUtils.extractCountry(
                                    widget.selectedNode!.name,
                                    context: context,
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.appPalette.textPrimary,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                if (widget.selectedNode!.latency != null) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.appPalette.surfaceAlt,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${widget.selectedNode!.latency}ms',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _latencyColor(
                                            widget.selectedNode!.latency!),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

            // Proxy Mode Selector
            const SizedBox(height: 20),
            _buildProxyModeSelector(context),
          ],
        );
      },
    );
  }

  Widget _buildProxyModeSelector(BuildContext context) {
    // Current assumption (sync with V2rayService later if observable)
    // For now we use a local state that defaults to what V2rayService has
    // Since V2rayService is singleton, we can read from it but it doesn't notify changes easily without stream
    // We will just manage it here for the view.

    return GestureDetector(
      onTap: () => _showProxySettingsDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.appPalette.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appPalette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded,
                size: 14, color: context.appPalette.textSecondary),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)?.proxySettings ?? 'Proxy Mode',
              style: TextStyle(
                fontSize: 12,
                color: context.appPalette.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProxySettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        var routingMode = V2rayService().routingMode;
        bool tunEnabled = V2rayService().tunEnabled;

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: context.appPalette.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
                AppLocalizations.of(context)?.proxySettings ?? 'Proxy Settings',
                style: TextStyle(color: context.appPalette.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)?.routingMode ?? 'Routing Mode',
                  style: TextStyle(
                      color: context.appPalette.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildRadioOption(
                  title: AppLocalizations.of(context)?.ruleMode ?? 'Rule Mode',
                  value: ProxyRoutingMode.rule,
                  groupValue: routingMode,
                  onChanged: (val) {
                    setState(() => routingMode = val);
                    V2rayService().setRoutingMode(val);
                  },
                ),
                _buildRadioOption(
                  title:
                      AppLocalizations.of(context)?.globalMode ?? 'Global Mode',
                  value: ProxyRoutingMode.global,
                  groupValue: routingMode,
                  onChanged: (val) {
                    setState(() => routingMode = val);
                    V2rayService().setRoutingMode(val);
                  },
                ),
                if (!Platform.isIOS && !Platform.isAndroid) ...[
                  Divider(color: context.appPalette.border),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(
                        AppLocalizations.of(context)?.tunMode ?? 'Tun Mode',
                        style:
                            TextStyle(color: context.appPalette.textPrimary)),
                    subtitle: Text('全局流量代理',
                        style: TextStyle(
                            color: context.appPalette.textSecondary,
                            fontSize: 11)),
                    value: tunEnabled,
                    activeThumbColor: context.appPalette.accent,
                    activeTrackColor:
                        context.appPalette.accent.withValues(alpha: 0.4),
                    inactiveThumbColor: context.appPalette.textSecondary,
                    inactiveTrackColor: context.appPalette.border,
                    onChanged: (val) {
                      setState(() => tunEnabled = val);
                      V2rayService().setTunEnabled(val);
                    },
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)?.close ?? 'Done',
                    style: TextStyle(color: context.appPalette.accent)),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildRadioOption({
    required String title,
    required ProxyRoutingMode value,
    required ProxyRoutingMode groupValue,
    required ValueChanged<ProxyRoutingMode> onChanged,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? context.appPalette.accent.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? context.appPalette.accent.withValues(alpha: 0.5)
                : context.appPalette.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? context.appPalette.accent
                  : context.appPalette.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? context.appPalette.textPrimary
                    : context.appPalette.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(BuildContext context, ConnectionButtonStatus status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case ConnectionButtonStatus.connected:
        return l10n?.connected ?? 'Connected';
      case ConnectionButtonStatus.connecting:
        return l10n?.connecting ?? 'Connecting...';
      case ConnectionButtonStatus.error:
        return l10n?.connectionFailed ?? 'Connection Failed';
      default:
        return l10n?.clickToConnect ?? 'Click to Connect';
    }
  }

  _StatusStyle _statusStyle(
      BuildContext context, ConnectionButtonStatus status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case ConnectionButtonStatus.connected:
        return _StatusStyle(
          accent: const Color(0xFFB7C1CD),
          action: l10n?.disconnect ?? 'Disconnect',
        );
      case ConnectionButtonStatus.connecting:
        return _StatusStyle(
          accent: const Color(0xFF8FA3BF),
          action: l10n?.connecting ?? 'Connecting',
        );
      case ConnectionButtonStatus.error:
        return _StatusStyle(
          accent: const Color(0xFFC19A9A),
          action: l10n?.retry ?? 'Retry',
        );
      default:
        return _StatusStyle(
          accent: const Color(0xFFAEB6C4),
          action: l10n?.connect ?? 'Connect',
        );
    }
  }

  Color _latencyColor(int latency) {
    if (latency < 100) return const Color(0xFF9FD1FF);
    if (latency < 300) return const Color(0xFFC9B77D);
    return const Color(0xFFC18C8C);
  }

  Widget _buildIndicator(_StatusStyle style, bool isBusy, bool reduceMotion) {
    final showCheck = widget.status == ConnectionButtonStatus.connected;
    final base = AnimatedContainer(
      key: ValueKey(showCheck),
      duration: const Duration(milliseconds: 180),
      width: showCheck ? 18 : 12,
      height: showCheck ? 18 : 12,
      decoration: BoxDecoration(
        color: style.accent,
        borderRadius: BorderRadius.circular(showCheck ? 6 : 999),
      ),
      child: showCheck
          ? const Icon(
              Icons.check_rounded,
              size: 14,
              color: Colors.black,
            )
          : null,
    );
    if (!isBusy || reduceMotion) {
      return base;
    }
    return AnimatedBuilder(
      animation: _loopController,
      builder: (context, child) {
        final pulse =
            0.94 + 0.06 * math.sin(_loopController.value * math.pi * 2);
        return Transform.scale(
          scale: pulse,
          child: child,
        );
      },
      child: base,
    );
  }

  Widget _buildBusyEffects(_StatusStyle style, double buttonWidth) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AnimatedBuilder(
          animation: _loopController,
          builder: (context, child) {
            final t = _loopController.value;
            final sweepOffset = (t * 2 - 1) * buttonWidth;
            final glow = 0.03 + 0.02 * math.sin(t * math.pi * 2);
            return Stack(
              children: [
                Opacity(
                  opacity: glow,
                  child: Container(
                    decoration: BoxDecoration(
                      color: style.accent,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(sweepOffset, 0),
                  child: Container(
                    width: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          style.accent.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _surfaceColor(BuildContext context, ConnectionButtonStatus status) {
    switch (status) {
      case ConnectionButtonStatus.connected:
        return context.appPalette.success;
      case ConnectionButtonStatus.connecting:
        return context.appPalette.accent;
      case ConnectionButtonStatus.error:
        return context.appPalette.danger;
      default:
        return context.appPalette.accent;
    }
  }
}

class _StatusStyle {
  final Color accent;
  final String action;

  const _StatusStyle({
    required this.accent,
    required this.action,
  });
}
