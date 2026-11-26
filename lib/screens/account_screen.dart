import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/user_info.dart';
import '../services/user_data_service.dart';
import '../services/v2board_api.dart'; // For V2BoardApiException
import '../services/api_config.dart';
import '../services/alert_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/animated_card.dart';
import '../widgets/staggered_list.dart';
import '../widgets/section_header.dart';
import '../widgets/flux_loader.dart';
import 'invite_screen.dart';
import 'my_orders_screen.dart';
import 'privacy_screen.dart';
import 'tos_screen.dart';

class AccountScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final String connectionStatus;
  final String connectionState;
  final int reloadToken;
  const AccountScreen({
    super.key,
    required this.onLogout,
    required this.connectionStatus,
    required this.connectionState,
    this.reloadToken = 0,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _userDataService = UserDataService();
  late Future<Map<String, dynamic>> _accountFuture;
  bool _isRetrying = false; // 重试时强制显示 loading

  @override
  void initState() {
    super.initState();
    // ❌ 不在 initState 中加载数据，依赖 RootShell 的预加载
    // RootShell._initApp 会预加载 getAccountPageData()，数据已缓存
    _accountFuture = _loadAccount(); // 读取缓存，不会发起新请求
  }

  @override
  void didUpdateWidget(covariant AccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      setState(() {
        _accountFuture = _loadAccount();
      });
    }
  }

  Future<Map<String, dynamic>> _loadAccount({bool forceRefresh = false}) async {
    // 确保 token 已加载
    final config = ApiConfig();
    await config.refreshAuthCache();

    // 使用缓存服务获取数据 (智能缓存)
    return await _userDataService.getAccountPageData(
      forceRefresh: forceRefresh,
    );
  }

  /// 检查并显示流量/到期提醒弹窗
  Future<void> _checkAndShowAlerts(Map<String, dynamic> subscribeData) async {
    if (!mounted) return;

    final usedBytes = ((subscribeData['u'] ?? 0) as num).toInt() +
        ((subscribeData['d'] ?? 0) as num).toInt();
    final totalBytes = ((subscribeData['transfer_enable'] ?? 0) as num).toInt();
    final expiredAt = ((subscribeData['expired_at'] ?? 0) as num).toInt();

    if (totalBytes > 0 && expiredAt > 0) {
      await AlertService().checkAndShowAlert(
        context: context,
        usedBytes: usedBytes,
        totalBytes: totalBytes,
        expiredAt: expiredAt,
      );
    }
  }

  Future<void> _logout() async {
    // 用户反馈：不用走 logout 接口，直接清除本地状态跳转
    await ApiConfig().clearAuth();
    if (mounted) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    // 重试时优先显示 loading，不管 FutureBuilder 状态如何
    if (_isRetrying) {
      return const Scaffold(body: Center(child: FluxLoader()));
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _accountFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final err = snapshot.error;
          final statusCode = err is V2BoardApiException ? err.statusCode : null;
          final isAuthExpired = statusCode == 401 || statusCode == 403;
          String message = err is V2BoardApiException
              ? err.message
              : AppLocalizations.of(context)?.networkError ?? 'Network error';

          // 如果错误信息包含 "token is null"，提供更友好的提示
          if (message.toLowerCase().contains('token is null') ||
              message.toLowerCase().contains('token') &&
                  message.toLowerCase().contains('null')) {
            message =
                AppLocalizations.of(context)?.reLogin ?? 'Please re-login';
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAuthExpired
                        ? Icons.error_outline
                        : Icons.warning_amber_rounded,
                    size: 48,
                    color: palette.warning,
                  ),
                  SizedBox(height: 16),
                  Text(
                    message,
                    style: TextStyle(
                      color: palette.warning,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isRetrying = true;
                            _accountFuture = _loadAccount(forceRefresh: true)
                                .whenComplete(() {
                              if (mounted) setState(() => _isRetrying = false);
                            });
                          });
                        },
                        child: Text(
                          AppLocalizations.of(context)?.retry ?? 'Retry',
                        ),
                      ),
                      if (isAuthExpired) ...[
                        SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            await ApiConfig().clearAuth();
                            if (context.mounted) widget.onLogout();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.accent,
                          ),
                          child: Text(
                            AppLocalizations.of(context)?.reLogin ?? 'Re-login',
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Center(child: FluxLoader(showTips: false));
        }
        final user = snapshot.data!['user'] as UserInfo;

        // final config = snapshot.data!['config'] as Map<String, dynamic>;

        final subInfo =
            snapshot.data!['subscribe'] as Map<String, dynamic>? ?? {};

        // 显示流量/到期提醒弹窗 (延迟到 build 完成后)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndShowAlerts(subInfo);
        });

        // Calculate usage if available
        final upload = subInfo['u'] as int? ?? 0;
        final download = subInfo['d'] as int? ?? 0;
        final total = subInfo['transfer_enable'] as int? ?? 1;
        final used = upload + download;
        final percent = (used / total).clamp(0.0, 1.0);

        return StaggeredList(
          eagerBuild: true,
          staggerDelay: Duration.zero,
          animationDuration: Duration.zero,
          padding: const EdgeInsets.only(
            top: 0,
            left: 16,
            right: 16,
            bottom: 100,
          ),
          children: [
            SectionHeader(
              title:
                  AppLocalizations.of(context)?.subscription ?? 'Subscription',
            ),
            SizedBox(height: 12),
            AnimatedCard(
              shadowIntensity: 0.35,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.star,
                          color: palette.accent,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subInfo['plan'] != null
                                ? (subInfo['plan']['name'] ??
                                    (AppLocalizations.of(
                                          context,
                                        )?.unknownPlan ??
                                        'Unknown Plan'))
                                : (AppLocalizations.of(
                                      context,
                                    )?.noSubscription ??
                                    'No Subscription'),
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (subInfo['expired_at'] != null)
                            Text(
                              '${AppLocalizations.of(context)?.expireDate ?? "Expires"}: ${Formatters.formatEpoch(subInfo['expired_at'])}',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      backgroundColor: palette.surfaceAlt,
                      valueColor: AlwaysStoppedAnimation(palette.accent),
                      minHeight: 8,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${AppLocalizations.of(context)?.usedTraffic ?? "Used"}: ${Formatters.formatBytes(used)}',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${AppLocalizations.of(context)?.totalTraffic ?? "Total"}: ${Formatters.formatBytes(total)}',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (subInfo['reset_day'] != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 16,
                            color: palette.warning,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '${AppLocalizations.of(context)?.trafficResetInfo ?? "Traffic resets on"} ${subInfo['reset_day']}',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: 24),
            SectionHeader(
              title: AppLocalizations.of(context)?.basicInfo ?? 'Basic Info',
            ),
            SizedBox(height: 12),
            AnimatedCard(
              shadowIntensity: 0.35,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    context,
                    Icons.email,
                    AppLocalizations.of(context)?.email ?? 'Email',
                    user.email,
                  ),
                  SizedBox(height: 12),
                  _buildInfoRow(
                    context,
                    Icons.account_balance_wallet,
                    AppLocalizations.of(context)?.balance ?? 'Balance',
                    Formatters.formatCurrency(user.balance),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),
            SectionHeader(title: '设置分类'),
            SizedBox(height: 12),

            _buildCategoryCard(
              Icons.security_rounded,
              '账号与安全',
              '密码修改与账户保护',
              () => _openCategory('账号与安全', [
                _buildLinkRow(
                  context,
                  Icons.lock_outline_rounded,
                  '修改账号密码',
                  _showChangePasswordDialog,
                ),
              ]),
            ),
            SizedBox(height: 12),

            _buildCategoryCard(
              Icons.card_giftcard_rounded,
              '订单与权益',
              '订单记录与邀请奖励',
              () => _openCategory('订单与权益', [
                _buildLinkRow(
                  context,
                  Icons.receipt_long_outlined,
                  '我的订单',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyOrdersScreen(),
                    ),
                  ),
                ),
                Divider(height: 24, color: palette.border),
                _buildLinkRow(
                  context,
                  Icons.card_giftcard_rounded,
                  '邀请有礼',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InviteScreen(),
                    ),
                  ),
                ),
              ]),
            ),
            SizedBox(height: 12),

            _buildCategoryCard(
              Icons.support_agent_rounded,
              '帮助与服务',
              '联系客服与访问官方网站',
              () => _openCategory('帮助与服务', [
                _buildLinkRow(
                  context,
                  Icons.support_agent,
                  AppLocalizations.of(context)?.customerService ??
                      'Customer Service',
                  _showCustomerServiceDialog,
                ),
                Divider(height: 24, color: palette.border),
                _buildLinkRow(
                  context,
                  Icons.language_rounded,
                  '官方网站',
                  _openOfficialWebsite,
                ),
              ]),
            ),
            SizedBox(height: 12),

            _buildCategoryCard(
              Icons.info_outline_rounded,
              '关于与法律',
              '服务条款、隐私政策与应用信息',
              () => _openCategory('关于与法律', [
                _buildLinkRow(
                  context,
                  Icons.description_outlined,
                  AppLocalizations.of(context)?.termsOfService ??
                      'Terms of Service',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TosScreen(),
                    ),
                  ),
                ),
                Divider(height: 24, color: palette.border),
                _buildLinkRow(
                  context,
                  Icons.privacy_tip_outlined,
                  AppLocalizations.of(context)?.privacyPolicy ??
                      'Privacy Policy',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyScreen(),
                    ),
                  ),
                ),
                Divider(height: 24, color: palette.border),
                _buildLinkRow(
                  context,
                  Icons.info_outline,
                  AppLocalizations.of(context)?.about ?? 'About 屿哥云',
                  () => _showAboutDialog(context),
                ),
              ]),
            ),

            SizedBox(height: 24),
            AnimatedCard(
              shadowIntensity: 0.35,
              onTap: _logout,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: palette.danger, size: 20),
                  SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)?.logout ?? 'Logout',
                    style: TextStyle(
                      color: palette.danger,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // 版本号
            SizedBox(height: 16),
            Center(
              child: Text(
                '屿哥云 v1.0.0',
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
            ),
            SizedBox(height: 48),
          ],
        );
      },
    );
  }

  void _openCategory(String title, List<Widget> children) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AccountCategoryScreen(
          title: title,
          children: children,
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final palette = context.appPalette;

    return AnimatedCard(
      shadowIntensity: 0.35,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: palette.accent, size: 21),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: palette.textSecondary,
            size: 22,
          ),
        ],
      ),
    );
  }

  Future<void> _openOfficialWebsite() async {
    final uri = Uri.parse('https://panel.yugenb.dpdns.org');
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开官方网站')),
        );
      }
    } catch (e) {
      debugPrint('Open website failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('打开官方网站失败，请稍后重试')),
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final palette = context.appPalette;
    final formKey = GlobalKey<FormState>();
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool loading = false;
    String? errorText;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: palette.surface,
                title: Text(
                  '修改账号密码',
                  style: TextStyle(color: palette.textPrimary),
                ),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: oldController,
                          obscureText: true,
                          enabled: !loading,
                          decoration: const InputDecoration(
                            labelText: '当前密码',
                          ),
                          validator: (value) =>
                              value == null || value.isEmpty ? '请输入当前密码' : null,
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: newController,
                          obscureText: true,
                          enabled: !loading,
                          decoration: const InputDecoration(
                            labelText: '新密码',
                            helperText: '至少 8 位',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入新密码';
                            }
                            if (value.length < 8) {
                              return '新密码至少需要 8 位';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: confirmController,
                          obscureText: true,
                          enabled: !loading,
                          decoration: const InputDecoration(
                            labelText: '确认新密码',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请再次输入新密码';
                            }
                            if (value != newController.text) {
                              return '两次输入的新密码不一致';
                            }
                            return null;
                          },
                        ),
                        if (errorText != null) ...[
                          SizedBox(height: 12),
                          Text(
                            errorText!,
                            style: TextStyle(color: palette.danger),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        loading ? null : () => Navigator.pop(dialogContext),
                    child: Text('取消'),
                  ),
                  FilledButton(
                    onPressed: loading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            setDialogState(() {
                              loading = true;
                              errorText = null;
                            });

                            try {
                              await V2BoardApi().changePassword(
                                oldController.text,
                                newController.text,
                              );

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('密码修改成功'),
                                ),
                              );
                            } catch (e) {
                              if (!dialogContext.mounted) return;
                              setDialogState(() {
                                loading = false;
                                errorText = e is V2BoardApiException
                                    ? e.message
                                    : '修改失败，请检查网络后重试';
                              });
                            }
                          },
                    child: loading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text('确认修改'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      oldController.dispose();
      newController.dispose();
      confirmController.dispose();
    }
  }

  // 屿哥云 QQ 客服
  static const String _customerQQ = '3896699819';

  Future<void> _showCustomerServiceDialog() async {
    final palette = context.appPalette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '屿哥云客服',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '客服 QQ：3896699819',
                style: TextStyle(color: palette.textSecondary),
              ),
              ListTile(
                leading: Icon(
                  Icons.chat_rounded,
                  color: palette.accent,
                ),
                title: Text(
                  '联系在线客服',
                  style: TextStyle(color: palette.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _launchQQ(
                    'mqqwpa://im/chat?chat_type=wpa&uin=$_customerQQ&version=1&src_type=web',
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: palette.accent,
                ),
                title: Text(
                  '添加客服好友',
                  style: TextStyle(color: palette.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _launchQQ(
                    'mqqapi://card/show_pslcard?src_type=internal&version=1&uin=$_customerQQ&card_type=person',
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.copy_rounded,
                  color: palette.accent,
                ),
                title: Text(
                  '复制客服 QQ 号',
                  style: TextStyle(color: palette.textPrimary),
                ),
                onTap: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: _customerQQ),
                  );

                  if (!sheetContext.mounted) return;

                  Navigator.pop(sheetContext);

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('客服 QQ 号已复制')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchQQ(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await _copyCustomerQQ();
      }
    } catch (e) {
      debugPrint('QQ launch failed: $e');
      await _copyCustomerQQ();
    }
  }

  Future<void> _copyCustomerQQ() async {
    await Clipboard.setData(
      const ClipboardData(text: _customerQQ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无法打开 QQ，客服号码已复制：3896699819')),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final palette = context.appPalette;
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.accent.withValues(alpha: 0.7)),
        SizedBox(width: 12),
        Text(
          '$label: ',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildLinkRow(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final palette = context.appPalette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.accent.withValues(alpha: 0.7)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: palette.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final palette = context.appPalette;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/icons/app_icon.png',
                    width: 32, height: 32, fit: BoxFit.cover)),
            SizedBox(width: 12),
            Text('屿哥云', style: TextStyle(color: palette.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.appDescription ??
                  '屿哥云 是一款安全、快速的网络加速服务。',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                height: 1.45,
                letterSpacing: 0.1,
              ),
            ),
            SizedBox(height: 20),
            _buildAboutFeature(
              Icons.hub_rounded,
              AppLocalizations.of(context)?.ixpAccess ?? 'IXP 接入',
              AppLocalizations.of(context)?.fastRoutingDesc ?? '极速分流优化',
            ),
            SizedBox(height: 12),
            _buildAboutFeature(
              Icons.speed_rounded,
              AppLocalizations.of(context)?.highSpeed ?? '高速稳定',
              AppLocalizations.of(context)?.highSpeedDesc ?? '全球高速专线',
            ),
            SizedBox(height: 12),
            _buildAboutFeature(
              Icons.security_rounded,
              AppLocalizations.of(context)?.noLogs ?? '安全无日志',
              AppLocalizations.of(context)?.privacyProtectionDesc ?? '严控隐私安全',
            ),
            SizedBox(height: 12),
            _buildAboutFeature(
              Icons.lock_rounded,
              AppLocalizations.of(context)?.strongEncryption ?? '强力加密',
              AppLocalizations.of(context)?.strongEncryptionDesc ??
                  'AES-256 位加密',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)?.close ?? 'Close',
              style: TextStyle(color: palette.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutFeature(IconData icon, String title, String subtitle) {
    final palette = context.appPalette;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: palette.accent),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.25,
                letterSpacing: 0.1,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                height: 1.35,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AccountCategoryScreen extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const AccountCategoryScreen({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          AnimatedCard(
            shadowIntensity: 0.35,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
