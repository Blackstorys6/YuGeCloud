import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/user_subscribe.dart';
import '../services/user_data_service.dart';
import '../services/v2ray_service.dart';
import '../theme/app_colors.dart';
import 'invite_screen.dart';
import '../widgets/fade_in_widget.dart';

AppPalette _homePalette(BuildContext context) =>
    Theme.of(context).extension<AppPalette>() ?? AppPalette.light;

class HomeDashboard extends StatefulWidget {
  final VoidCallback onConnectPressed;
  final Future<void> Function()? onReconnectRequested;
  final bool isConnected;
  final bool isConnecting;
  final String statusMessage;
  final VoidCallback? onSelectNode;
  final VoidCallback? onOpenPlans;
  final String? selectedNodeName;
  final String? connectedNodeName;
  final int reloadToken;

  const HomeDashboard({
    super.key,
    required this.onConnectPressed,
    this.onReconnectRequested,
    required this.isConnected,
    this.isConnecting = false,
    this.statusMessage = '',
    this.onSelectNode,
    this.onOpenPlans,
    this.selectedNodeName,
    this.connectedNodeName,
    this.reloadToken = 0,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;
  UserSubscribe? _sub;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine),
    );

    _loadData();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _glowController.dispose();
    super.dispose();
  }

  static const double _navSpace = 100;

  Future<void> _loadData({bool force = false}) async {
    try {
      final m = await UserDataService().getSubscribeInfo(forceRefresh: force);
      final raw =
          m['data'] is Map ? Map<String, dynamic>.from(m['data'] as Map) : m;
      final sub = UserSubscribe.fromJson(raw);
      if (!mounted) return;
      setState(() => _sub = sub);
    } catch (e) {
      debugPrint('Load subscribe info failed: $e');
    }
  }

  @override
  void didUpdateWidget(covariant HomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isConnected != widget.isConnected ||
        oldWidget.reloadToken != widget.reloadToken) {
      _loadData(force: true);
    }
  }

  ({String v, String u}) _fmtBytes(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) {
      final x = bytes / gb;
      return (
        v: x >= 100 ? x.toStringAsFixed(0) : x.toStringAsFixed(1),
        u: 'GB',
      );
    }
    if (bytes >= mb) return (v: (bytes / mb).toStringAsFixed(0), u: 'MB');
    if (bytes >= kb) return (v: (bytes / kb).toStringAsFixed(0), u: 'KB');
    return (v: '$bytes', u: 'B');
  }

  ({String v, String u}) _daysLeft() {
    final s = _sub;
    if (s == null) return (v: '—', u: '');
    if (s.planId == 0 && s.transferEnable == 0) return (v: '未订阅', u: '');
    if (s.expiredAt == 0) return (v: '长期有效', u: '');
    final ms = s.expiredAt * 1000 - DateTime.now().millisecondsSinceEpoch;
    if (ms <= 0) return (v: '已过期', u: '');
    return (v: '${(ms / 86400000).ceil()}', u: '天');
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.isConnecting;
    final palette =
        Theme.of(context).extension<AppPalette>() ?? AppPalette.light;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.background,
            palette.surfaceAlt,
            palette.background,
          ],
        ),
      ),
      child: FadeInWidget(
        delay: const Duration(milliseconds: 150),
        duration: const Duration(milliseconds: 600),
        offset: const Offset(0, 20),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildUsageBar(),
                              const SizedBox(height: 48),
                              _buildUsageText(),
                              const SizedBox(height: 14),
                              _buildExpiryRow(),
                              const SizedBox(height: 16),
                              _buildEntryCard(context),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              _buildBottomConnect(isBusy),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsageBar() {
    final s = _sub;
    final total = s?.transferEnable ?? 0;
    final used = s == null ? 0 : s.upload + s.download;
    final double avail =
        total > 0 ? (1 - used / total).clamp(0.0, 1.0).toDouble() : 0.0;
    final pct = (avail * 100).round();
    final color = avail < 0.1
        ? _homePalette(context).danger
        : _homePalette(context).accent;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Container(
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _homePalette(context).surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: avail,
            child: SizedBox.expand(
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) => CustomPaint(
                  painter: _WaterProgressPainter(
                    color: color,
                    phase: reduceMotion ? 0.0 : _glowController.value,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                total > 0 ? '$pct% 可用' : '暂无流量',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageText() {
    final s = _sub;
    final used = _fmtBytes(s == null ? 0 : s.upload + s.download);
    final total = _fmtBytes(s?.transferEnable ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '已用流量',
          style: TextStyle(
              color: _homePalette(context).textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: used.v,
                style: TextStyle(
                  color: _homePalette(context).textPrimary,
                  fontSize: 44,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              TextSpan(
                text: ' ${used.u} / ${total.v} ${total.u}',
                style: TextStyle(
                  color: _homePalette(context).textSecondary,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpiryRow() {
    final d = _daysLeft();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '有效期',
                style: TextStyle(
                    color: _homePalette(context).textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: d.v,
                      style: TextStyle(
                        color: _homePalette(context).textPrimary,
                        fontSize: 44,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    TextSpan(
                      text: d.u.isEmpty ? '' : ' ${d.u}',
                      style: TextStyle(
                        color: _homePalette(context).textSecondary,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.onOpenPlans != null)
          OutlinedButton(
            onPressed: widget.onOpenPlans,
            style: OutlinedButton.styleFrom(
              foregroundColor: _homePalette(context).accent,
              side: BorderSide(color: _homePalette(context).accent, width: 1.5),
              shape: const StadiumBorder(),
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 22),
            ),
            child: const Text(
              '更新订阅',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  Widget _buildEntryCard(BuildContext context) {
    final mode =
        V2rayService().routingMode == ProxyRoutingMode.global ? '全局模式' : '规则分流';
    return Material(
      color: _homePalette(context).surface,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _entryRow(
            verticalPadding: 17,
            icon: Icons.dns_rounded,
            title: '服务器',
            subtitle: widget.isConnecting
                ? (widget.connectedNodeName == null
                    ? '正在连接…'
                    : '正在连接 · ${widget.connectedNodeName}')
                : widget.isConnected
                    ? (widget.connectedNodeName == null
                        ? '已连接'
                        : '已连接 · ${widget.connectedNodeName}')
                    : '请选择服务器',
            onTap: widget.onSelectNode,
          ),
          Divider(
            height: 18,
            indent: 20,
            endIndent: 20,
            color: _homePalette(context).border,
          ),
          _entryRow(
            verticalPadding: 17,
            icon: Icons.public_rounded,
            title: '代理模式',
            subtitle: mode,
            onTap: () => _showProxySettingsDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _entryRow({
    double verticalPadding = 14,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: 20, vertical: verticalPadding),
        child: Row(
          children: [
            Icon(icon, color: _homePalette(context).accent, size: 30),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _homePalette(context).textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _homePalette(context).textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _homePalette(context).textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomConnect(bool isBusy) {
    final connected = widget.isConnected;
    final label = isBusy ? '连接中…' : (connected ? '断开连接' : '连接');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, _navSpace),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton(
              onPressed: isBusy ? null : widget.onConnectPressed,
              style: FilledButton.styleFrom(
                backgroundColor: connected
                    ? _homePalette(context).surfaceAlt
                    : _homePalette(context).accent,
                disabledBackgroundColor: Color.lerp(
                  _homePalette(context).accent,
                  Theme.of(context).brightness == Brightness.light
                      ? _homePalette(context).textPrimary
                      : Colors.black,
                  0.24,
                )!,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white70,
                shape: const StadiumBorder(),
                minimumSize: const Size.fromHeight(60),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (connected)
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: _homePalette(context).success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (isBusy) ...[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProxyModeButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () => _showProxySettingsDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _homePalette(context).surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _homePalette(context).accent.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 16,
              color: _homePalette(context).accent.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 8),
            Text(
              l10n?.proxySettings ?? 'Proxy Mode',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  void _showProxySettingsDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    var routingMode = V2rayService().routingMode;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Center(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 280,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _homePalette(context).surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _homePalette(context)
                              .accent
                              .withValues(alpha: 0.12),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 标题
                          Text(
                            l10n?.routingMode ?? 'Routing Mode',
                            style: TextStyle(
                              color: _homePalette(context).textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 规则模式
                          _buildModeCard(
                            icon: Icons.alt_route_rounded,
                            title: l10n?.ruleMode ?? 'Smart',
                            isSelected: routingMode == ProxyRoutingMode.rule,
                            onTap: () async {
                              if (routingMode == ProxyRoutingMode.rule) {
                                Navigator.pop(context);
                                return;
                              }
                              V2rayService().setRoutingMode(
                                ProxyRoutingMode.rule,
                              );
                              Navigator.pop(context);
                              await _requestReconnectIfNeeded();
                            },
                          ),
                          const SizedBox(height: 10),
                          // 全局模式
                          _buildModeCard(
                            icon: Icons.public_rounded,
                            title: l10n?.globalMode ?? 'Global',
                            isSelected: routingMode == ProxyRoutingMode.global,
                            onTap: () async {
                              if (routingMode == ProxyRoutingMode.global) {
                                Navigator.pop(context);
                                return;
                              }
                              V2rayService().setRoutingMode(
                                ProxyRoutingMode.global,
                              );
                              Navigator.pop(context);
                              await _requestReconnectIfNeeded();
                            },
                          ),
                          // TUN 模式（仅桌面端）
                          if (!Platform.isAndroid && !Platform.isIOS) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _homePalette(context).background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: _homePalette(context).border),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.router_rounded,
                                    color: _homePalette(context).textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n?.tunMode ?? 'TUN Mode',
                                          style: TextStyle(
                                            color: _homePalette(context)
                                                .textPrimary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          l10n?.tunModeDesc ?? 'Experimental',
                                          style: TextStyle(
                                            color: _homePalette(context)
                                                .textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatefulBuilder(
                                    builder: (context, setTunState) {
                                      var tunEnabled =
                                          V2rayService().tunEnabled;
                                      return Switch(
                                        value: tunEnabled,
                                        activeThumbColor:
                                            _homePalette(context).accent,
                                        onChanged: (val) async {
                                          setTunState(() => tunEnabled = val);
                                          await V2rayService()
                                              .setTunEnabled(val);
                                          await _requestReconnectIfNeeded();
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _requestReconnectIfNeeded() async {
    if (!widget.isConnected) return;
    if (widget.onReconnectRequested != null) {
      await widget.onReconnectRequested!();
      return;
    }
    widget.onConnectPressed();
    await Future.delayed(const Duration(milliseconds: 600));
    widget.onConnectPressed();
  }

  Widget _buildModeCard({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? _homePalette(context).accent.withValues(alpha: 0.08)
              : _homePalette(context).background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? _homePalette(context).accent.withValues(alpha: 0.35)
                : _homePalette(context).border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? _homePalette(context).accent
                  : _homePalette(context).textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? _homePalette(context).textPrimary
                      : _homePalette(context).textSecondary,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded,
                  color: _homePalette(context).accent, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? _homePalette(context).accent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? _homePalette(context).accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? _homePalette(context).accent.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? _homePalette(context).accent
                    : Colors.white.withValues(alpha: 0.6),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.9),
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: _homePalette(context).accent,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context) {
    // 使用 LayoutBuilder 响应式布局：桌面端 4 列，移动端 2 列
    return LayoutBuilder(
      builder: (context, constraints) {
        // 简单判断：如果宽度大于 600 则视为桌面/宽屏
        final isDesktop = constraints.maxWidth > 600;
        final crossAxisCount = isDesktop ? 4 : 2;
        final childAspectRatio = isDesktop ? 2.5 : 2.4;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          children: [
            _buildFeatureTile(
              context,
              Icons.hub_rounded,
              AppLocalizations.of(context)?.ixpAccess ?? 'IXP Access',
              AppLocalizations.of(context)?.fastRouting ?? 'Fast Routing',
            ),
            _buildFeatureTile(
              context,
              Icons.speed_rounded,
              AppLocalizations.of(context)?.highSpeed ?? 'High Speed',
              AppLocalizations.of(context)?.instant4k ?? '4K Instant',
            ),
            _buildFeatureTile(
              context,
              Icons.security_rounded,
              AppLocalizations.of(context)?.noLogs ?? 'No Logs',
              AppLocalizations.of(context)?.privacyProtection ?? 'Privacy',
            ),
            _buildFeatureTile(
              context,
              Icons.lock_rounded,
              AppLocalizations.of(context)?.strongEncryption ?? 'Encryption',
              'AES-256',
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeatureTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _homePalette(context).surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _homePalette(context).accent.withValues(alpha: 0.15),
            width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isLightTheme ? 0.1575 : 0.1,
            ),
            blurRadius: isLightTheme ? 4.9 : 4,
            offset: isLightTheme ? const Offset(0, 2.1) : const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _homePalette(context).accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _homePalette(context).accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroButton(double t, double glowT) {
    final isBusy = widget.isConnecting;
    final l10n = AppLocalizations.of(context);
    final label = widget.isConnected
        ? (l10n?.disconnect ?? 'Disconnect')
        : (isBusy
            ? (l10n?.connecting ?? 'Connecting')
            : (l10n?.connect ?? 'Connect'));
    final icon = widget.isConnected ? Icons.power : Icons.power_settings_new;

    return GestureDetector(
      onTap: isBusy ? null : widget.onConnectPressed,
      child: SizedBox(
        width: 240,
        height: 68,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: widget.isConnected
                  ? const [Color(0xFF343A43), Color(0xFF1A1D23)]
                  : const [Color(0xFF2F3540), Color(0xFF12151B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: _homePalette(context).accent.withValues(alpha: 0.55),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: _homePalette(context).accent.withValues(alpha: 0.42),
                blurRadius: 34,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 柔和的银色光带，保持静态质感
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              // 轻微呼吸感，但不改变尺寸
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, _) {
                    final glow = 0.06 +
                        0.04 * math.sin(_glowAnimation.value * math.pi * 2);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: RadialGradient(
                          colors: [
                            _homePalette(context)
                                .accent
                                .withValues(alpha: glow),
                            Colors.transparent,
                          ],
                          radius: 0.9,
                          center: Alignment.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              // 状态指示点
              Positioned(
                right: 16,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: widget.isConnected
                          ? [
                              const Color(0xFF6CFFB8),
                              _homePalette(context).accent
                            ]
                          : (isBusy
                              ? [
                                  const Color(0xFFFFE18D),
                                  const Color(0xFFFFB347),
                                ]
                              : [
                                  _homePalette(context).accent,
                                  const Color(0xFF6F7A8C)
                                ]),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isConnected
                            ? _homePalette(context)
                                .accent
                                .withValues(alpha: 0.5)
                            : _homePalette(context)
                                .accent
                                .withValues(alpha: 0.25),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const InviteScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _homePalette(context).accent.withValues(alpha: 0.2),
              _homePalette(context).accent.withValues(alpha: 0.05),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _homePalette(context).accent.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _homePalette(context).accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.card_giftcard,
                color: _homePalette(context).accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)?.inviteFriendsTitle ?? '邀请有礼',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)?.inviteFriendsSubtitle ??
                        '邀请好友加入，获取丰厚奖励',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class _WaterProgressPainter extends CustomPainter {
  final Color color;
  final double phase;

  const _WaterProgressPainter({
    required this.color,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(color, Colors.white, 0.16)!,
          color,
          Color.lerp(color, Colors.black, 0.10)!,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    final angle = phase * math.pi * 2;
    _wave(canvas, size, angle, 0.37, 0.055, 1.35,
        Paint()..color = Colors.white.withValues(alpha: 0.17));
    _wave(canvas, size, angle + math.pi * 0.85, 0.43, 0.040, 1.75,
        Paint()..color = color.withValues(alpha: 0.22));

    final highlight = Path();
    for (double x = 0; x <= size.width; x += 4) {
      final y = size.height * 0.37 +
          math.sin(x / size.width * math.pi * 2 * 1.35 + angle) *
              size.height *
              0.055;
      if (x == 0) {
        highlight.moveTo(x, y);
      } else {
        highlight.lineTo(x, y);
      }
    }
    canvas.drawPath(
      highlight,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.24),
    );
  }

  void _wave(
    Canvas canvas,
    Size size,
    double phase,
    double level,
    double amplitude,
    double frequency,
    Paint paint,
  ) {
    final path = Path();
    for (double x = 0; x <= size.width; x += 4) {
      final y = size.height * level +
          math.sin(x / size.width * math.pi * 2 * frequency + phase) *
              size.height *
              amplitude;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaterProgressPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.phase != phase;
}
