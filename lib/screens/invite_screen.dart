import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/v2board_api.dart';
import '../models/invite_data.dart';
import '../theme/app_colors.dart';
import '../widgets/flux_loader.dart';
import 'package:share_plus/share_plus.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen>
    with SingleTickerProviderStateMixin {
  bool _isGenerating = false;
  late Future<Map<String, dynamic>> _inviteDataFuture;
  late AnimationController _animController;
  late Animation<double> _breatheAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _breatheAnim = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Lazy loading: 仅在页面构建时才加载数据
    _inviteDataFuture = _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final api = V2BoardApi();
    final data = await api.fetchInviteData();
    final details = await api.fetchInviteDetails();
    return {'data': data, 'details': details};
  }

  Future<void> _generateCode() async {
    setState(() => _isGenerating = true);
    try {
      final api = V2BoardApi();
      await api.generateInviteCode();
      // Reload data
      setState(() {
        _inviteDataFuture = _loadData();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.generateFailed ?? "Generation failed"}: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPalette.background,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.inviteManagement ?? 'Invite Management',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _inviteDataFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${AppLocalizations.of(context)?.loadNodesFailed ?? "Loading failed"}: ${snapshot.error}',
                    style: TextStyle(color: context.appPalette.accentWarm),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() {
                      _inviteDataFuture = _loadData();
                    }),
                    child: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: FluxLoader(showTips: true));
          }

          final inviteData = snapshot.data!['data'] as InviteFetchData;
          final details = snapshot.data!['details'] as List<InviteDetail>;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _inviteDataFuture = _loadData();
              });
              await _inviteDataFuture;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsGrid(inviteData.stat),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    AppLocalizations.of(context)?.myInviteCode ??
                        'My Invite Code',
                  ),
                  const SizedBox(height: 12),
                  _buildCodesList(inviteData.codes),
                  const SizedBox(height: 16),
                  _buildGenerateButton(),
                  const SizedBox(height: 32),
                  _buildSectionHeader(
                    AppLocalizations.of(context)?.inviteHistory ??
                        'Invite History',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailsList(details),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: context.appPalette.textPrimary,
      ),
    );
  }

  Widget _buildStatsGrid(InviteStat stat) {
    return AnimatedBuilder(
      animation: _breatheAnim,
      builder: (context, child) {
        final shadowOpacity = 0.1 + (_breatheAnim.value * 0.15); // 0.1 -> 0.25
        final borderOpacity = 0.2 + (_breatheAnim.value * 0.3); // 0.2 -> 0.5
        final blurRadius = 10.0 + (_breatheAnim.value * 15.0); // 10 -> 25

        return Column(
          children: [
            // 1. Financial Card (Black/Silver breathing) - Compact Horizontal Layout
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                // Dark Metallic Gradient
                gradient: LinearGradient(
                  colors: [
                    context.appPalette.surfaceAlt,
                    context.appPalette.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.appPalette.accent.withOpacity(borderOpacity),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.appPalette.accent.withOpacity(shadowOpacity),
                    blurRadius: blurRadius,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Side: Label + Big Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: context.appPalette.border,
                              ),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_outlined,
                              color: context.appPalette.accent,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)?.availableCommission ??
                                'Available Commission',
                            style: TextStyle(
                              color: context.appPalette.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '¥${stat.availableCommission}',
                        style: TextStyle(
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? context.appPalette.accent
                                  : context.appPalette.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),

                  // Divider
                  Container(
                    width: 1,
                    height: 50,
                    color: context.appPalette.accent.withOpacity(0.1),
                  ),

                  // Right Side: Compact Stats Column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildMiniStat(
                        AppLocalizations.of(context)?.pendingCommission ??
                            'Pending',
                        '¥${stat.pendingCommission}',
                      ),
                      const SizedBox(height: 12),
                      _buildMiniStat(
                        AppLocalizations.of(context)?.totalCommission ??
                            'Total',
                        '¥${stat.validCommission}',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Performance Card (Subtle breathing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: context.appPalette.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.appPalette.accent.withOpacity(
                    borderOpacity * 0.5,
                  ), // Subtle border
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.appPalette.shadow,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPerformanceItem(
                    Icons.people_outline_rounded,
                    '${stat.registeredUsers}',
                    AppLocalizations.of(context)?.registeredUsers ?? 'Users',
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: context.appPalette.accent.withOpacity(0.1),
                  ),
                  _buildPerformanceItem(
                    Icons.percent_rounded,
                    '${stat.commissionRate}%',
                    AppLocalizations.of(context)?.commissionPercentage ??
                        'Rate',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.appPalette.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: context.appPalette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.appPalette.accent.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: context.appPalette.accent, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: context.appPalette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: context.appPalette.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCodesList(List<InviteCode> codes) {
    if (codes.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)?.noInviteData ?? 'No invite codes',
          style: TextStyle(color: context.appPalette.textSecondary),
        ),
      );
    }
    return Column(
      children: codes.map((code) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: context.appPalette.accent.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    code.code,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.appPalette.accent,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppLocalizations.of(context)?.createdAt ?? "创建于"}: ${_formatDate(code.createdAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appPalette.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      // Hardcoded domain as per feedback
                      const domain = 'https://panel.yugenb.dpdns.org';
                      final url = '$domain/#/register?code=${code.code}';
                      Share.share('邀请你使用屿哥云： $url');
                    },
                    icon: Icon(Icons.share,
                        color: context.appPalette.textSecondary),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    icon: Icon(Icons.copy,
                        color: context.appPalette.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGenerateButton() {
    return AnimatedBuilder(
      animation: _breatheAnim,
      builder: (context, child) {
        return GestureDetector(
          onTap: _isGenerating ? null : _generateCode,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              // Silver Gradient
              gradient: LinearGradient(
                colors: [
                  context.appPalette.accent,
                  context.appPalette.accentWarm,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(
                    alpha: _breatheAnim.value * 0.3,
                  ),
                  blurRadius: 15 + (_breatheAnim.value * 10),
                  spreadRadius: _breatheAnim.value * 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Center(
        child: _isGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                AppLocalizations.of(context)?.generateCode ?? 'Generate Code',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildDetailsList(List<InviteDetail> details) {
    if (details.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            AppLocalizations.of(context)?.noInviteHistory ?? 'No records',
            style: TextStyle(color: context.appPalette.textSecondary),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: details.length,
      itemBuilder: (context, index) {
        final item = details[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appPalette.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getCommissionStatusText(item.commissionStatus),
                    style: TextStyle(
                      color: _getCommissionStatusColor(item.commissionStatus),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(item.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appPalette.textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                '+${item.commissionBalance}元',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.appPalette.accent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getCommissionStatusText(int status) {
    switch (status) {
      case 0:
        return '待确认';
      case 1:
        return '发放中';
      case 2:
        return '有效';
      case 3:
        return '无效';
      case 4:
        return '已发放';
      default:
        return '未知';
    }
  }

  Color _getCommissionStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.red;
      case 4:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
