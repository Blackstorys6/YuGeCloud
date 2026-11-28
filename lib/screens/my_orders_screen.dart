import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/payment_method.dart';
import '../models/plan.dart';
import '../services/v2board_api.dart';
import '../services/user_data_service.dart';
import '../utils/formatters.dart';
import '../theme/app_colors.dart';
import '../widgets/flux_loader.dart';

class MyOrdersScreen extends StatefulWidget {
  final bool historyOnly;
  final ValueChanged<Plan>? onSelectPlan;

  const MyOrdersScreen({
    super.key,
    this.historyOnly = false,
    this.onSelectPlan,
  });

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final V2BoardApi _api = V2BoardApi();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  Set<int>? _availablePlanIds;

  int _number(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _statusText(dynamic value) {
    switch (_number(value)) {
      case 0:
        return '待支付';
      case 1:
        return '开通中';
      case 2:
        return '已取消';
      case 3:
        return '已完成';
      case 4:
        return '已折抵';
      default:
        return '未知状态';
    }
  }

  Color _statusColor(BuildContext context, dynamic value) {
    final palette = context.appPalette;
    switch (_number(value)) {
      case 0:
        return palette.warning;
      case 1:
        return palette.accent;
      case 2:
        return palette.textSecondary;
      case 3:
      case 4:
        return palette.success;
      default:
        return palette.textSecondary;
    }
  }

  String _date(dynamic value) {
    final seconds = _number(value);
    if (seconds <= 0) return '—';
    final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _amount(dynamic value) {
    return '¥${Formatters.formatCurrency(_number(value))}';
  }

  Future<void> _loadOrders() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await _api.fetchOrders();
      final data = response['data'];
      final list = data is List ? data : <dynamic>[];

      final orders = list
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      Set<int>? availablePlanIds;
      if (widget.historyOnly) {
        try {
          final planResponse = await _api.getPlans();
          final planData = planResponse['data'];
          if (planData is List) {
            availablePlanIds = planData
                .whereType<Map>()
                .map((item) => _number(item['id']))
                .where((id) => id > 0)
                .toSet();
          } else {
            throw Exception('套餐列表格式异常');
          }
        } catch (_) {
          availablePlanIds = null;
        }
      }

      if (mounted) {
        setState(() {
          _orders = orders;
          if (widget.historyOnly) {
            _availablePlanIds = availablePlanIds;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _showDetail(String tradeNo) async {
    final palette = context.appPalette;
    try {
      final response = await _api.getOrderDetail(tradeNo);
      final data = response['data'];

      if (!mounted) return;

      if (data is! Map) {
        _showMessage('暂时无法读取订单详情');
        return;
      }

      final order = Map<String, dynamic>.from(data);

      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: palette.surface,
          title: Text('订单详情'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(dialogContext, '订单号', tradeNo),
                _detailRow(
                    dialogContext,
                    '套餐',
                    order['plan'] is Map
                        ? (order['plan']['name']?.toString() ?? '—')
                        : '—'),
                _detailRow(
                    dialogContext, '应付金额', _amount(order['total_amount'])),
                _detailRow(
                    dialogContext, '余额抵扣', _amount(order['balance_amount'])),
                _detailRow(
                    dialogContext, '优惠金额', _amount(order['discount_amount'])),
                _detailRow(dialogContext, '订单状态', _statusText(order['status'])),
                _detailRow(dialogContext, '创建时间', _date(order['created_at'])),
                _detailRow(dialogContext, '支付时间', _date(order['paid_at'])),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('关闭'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) _showMessage('获取订单详情失败：$e');
    }
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: TextStyle(color: palette.textSecondary),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _cancelOrder(String tradeNo) async {
    final palette = context.appPalette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('取消订单'),
        content: Text('确定要取消这笔待支付订单吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('暂不取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('确认取消'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.cancelOrder(tradeNo);
      _showMessage('订单取消请求已提交');
      await _loadOrders();
    } catch (e) {
      _showMessage('取消订单失败：$e');
    }
  }

  Future<void> _continuePayment(String tradeNo) async {
    final palette = context.appPalette;
    try {
      final response = await _api.getPaymentMethods();
      final data = response['data'];
      final list = data is List ? data : <dynamic>[];

      final methods = list
          .whereType<Map>()
          .map((item) => PaymentMethod.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((method) => method.id > 0)
          .toList();

      if (!mounted) return;

      if (methods.isEmpty) {
        _showMessage('当前没有可用的支付方式');
        return;
      }

      final selected = await showModalBottomSheet<PaymentMethod>(
        context: context,
        backgroundColor: palette.surface,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  '选择支付方式',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...methods.map(
                (method) => ListTile(
                  leading: Icon(
                    Icons.payment,
                    color: palette.accent,
                  ),
                  title: Text(method.name),
                  onTap: () => Navigator.pop(sheetContext, method),
                ),
              ),
            ],
          ),
        ),
      );

      if (selected == null || !mounted) return;

      final result = await _api.checkoutOrder(tradeNo, selected.id);
      final paymentData = result['data'];

      if (paymentData is String &&
          (paymentData.startsWith('http') ||
              paymentData.startsWith('alipays://') ||
              paymentData.startsWith('weixin://'))) {
        final uri = Uri.tryParse(paymentData);
        if (uri == null || !await canLaunchUrl(uri)) {
          _showMessage('无法打开支付链接，请检查设备是否安装对应应用');
          return;
        }
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (paymentData != true &&
          paymentData != 1 &&
          paymentData != '1') {
        _showMessage('支付请求未成功，请稍后重试');
        return;
      }

      if (!mounted) return;
      _showMessage('已提交支付请求，正在确认订单状态');
      await _pollOrder(tradeNo);
    } catch (e) {
      if (mounted) _showMessage('发起支付失败：$e');
    }
  }

  Future<void> _pollOrder(String tradeNo) async {
    for (var i = 0; i < 45; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      try {
        final response = await _api.checkOrder(tradeNo);
        final status = response['data'];

        if (status == 1 ||
            status == true ||
            status == '1' ||
            status == 3 ||
            status == '3') {
          _showMessage('订单状态已更新');
          await _loadOrders();
          return;
        }
      } catch (_) {
        // 暂时无法查询时继续下一次检查
      }
    }

    if (mounted) {
      _showMessage('暂未确认支付结果，可稍后刷新订单列表');
      await _loadOrders();
    }
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order) {
    final palette = context.appPalette;
    final tradeNo = order['trade_no']?.toString() ?? '';
    final status = order['status'];
    final plan = order['plan'];
    final planName =
        plan is Map ? (plan['name']?.toString() ?? '套餐订单') : '套餐订单';

    return Card(
      color: palette.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    planName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _statusText(status),
                  style: TextStyle(
                    color: _statusColor(context, status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _amount(order['total_amount']),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: palette.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '订单号：$tradeNo',
              style: TextStyle(
                fontSize: 12,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '创建时间：${_date(order['created_at'])}',
              style: TextStyle(
                fontSize: 12,
                color: palette.textSecondary,
              ),
            ),
            Divider(height: 24, color: palette.border),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed:
                      tradeNo.isEmpty ? null : () => _showDetail(tradeNo),
                  child: Text('订单详情'),
                ),
                if (_number(status) == 0) ...[
                  FilledButton(
                    onPressed: tradeNo.isEmpty
                        ? null
                        : () => _continuePayment(tradeNo),
                    child: Text('继续支付'),
                  ),
                  TextButton(
                    onPressed:
                        tradeNo.isEmpty ? null : () => _cancelOrder(tradeNo),
                    child: Text(
                      '取消订单',
                      style: TextStyle(color: Colors.redAccent),
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

  List<Plan> get _historyPlans {
    final result = <Plan>[];
    final seen = <int>{};

    for (final order in _orders) {
      if (_number(order['status']) != 3) continue;
      if (_number(order['type']) == 4) continue;

      final rawPlan = order['plan'];
      if (rawPlan is! Map) continue;

      try {
        final json = Map<String, dynamic>.from(rawPlan);
        final id = _number(json['id']);
        if (id <= 0 || !seen.add(id)) continue;
        result.add(Plan.fromJson(json));
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  Widget _buildHistoryPlanCard(BuildContext context, Plan plan) {
    final palette = context.appPalette;
    final trafficGb =
        (plan.transferEnable / (1024 * 1024 * 1024)).toStringAsFixed(0);

    return Card(
      color: palette.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '套餐流量：$trafficGb GB',
              style: TextStyle(color: palette.textSecondary),
            ),
            if (plan.content?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                plan.content!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
            ],
            if (widget.onSelectPlan != null) ...[
              const SizedBox(height: 12),
              if (_availablePlanIds == null)
                Text(
                  '暂时无法确认此套餐是否在售，请刷新后重试',
                  style: TextStyle(color: palette.textSecondary),
                )
              else if (_availablePlanIds!.contains(plan.id))
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => widget.onSelectPlan!(plan),
                    child: const Text('重新选择此套餐'),
                  ),
                )
              else
                Text(
                  '当前不可购买（套餐可能已停售）',
                  style: TextStyle(color: palette.textSecondary),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context) {
    final plans = _historyPlans;
    if (!widget.historyOnly || plans.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '曾经购买的套餐',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: context.appPalette.textPrimary,
            ),
          ),
        ),
        ...plans.map((plan) => _buildHistoryPlanCard(context, plan)),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.historyOnly ? '历史套餐' : '我的订单'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _loadOrders,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(color: palette.background),
        child: _loading
            ? const Center(child: FluxLoader(showTips: true))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '加载订单失败：$_error',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadOrders,
                            child: Text('重新加载'),
                          ),
                        ],
                      ),
                    ),
                  )
                : widget.historyOnly && _historyPlans.isEmpty
                    ? const Center(child: Text('暂无已完成的历史套餐'))
                    : !widget.historyOnly && _orders.isEmpty
                        ? const Center(child: Text('暂无订单记录'))
                        : RefreshIndicator(
                            onRefresh: _loadOrders,
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: widget.historyOnly
                                  ? [_buildHistorySection(context)]
                                  : _orders
                                      .map((order) =>
                                          _buildOrderCard(context, order))
                                      .toList(),
                            ),
                          ),
      ),
    );
  }
}
