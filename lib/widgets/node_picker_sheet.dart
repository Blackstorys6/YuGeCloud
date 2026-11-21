import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/server_node.dart';
import '../services/latency_test_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import 'flux_loader.dart';

class NodePickerSheet extends StatefulWidget {
  final ValueChanged<ServerNode> onNodeSelected;

  const NodePickerSheet({super.key, required this.onNodeSelected});

  @override
  State<NodePickerSheet> createState() => _NodePickerSheetState();
}

class _NodePickerSheetState extends State<NodePickerSheet> {
  final _subscriptionService = SubscriptionService();
  final _latencyService = LatencyTestService();
  List<ServerNode> _nodes = [];
  final Set<ServerNode> _tested = {};
  bool _isLoading = true;
  bool _testing = false;
  int _runId = 0;

  static bool _isUdp(ServerNode n) =>
      const {'hysteria2', 'tuic', 'wireguard'}.contains(n.protocol);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _runId++;
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _isLoading = true);
    try {
      final nodes = await _subscriptionService.fetchNodes(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        _nodes = List.of(nodes);
        _isLoading = false;
      });
      _runTest();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runTest() async {
    if (_nodes.isEmpty) return;
    final run = ++_runId;
    setState(() {
      _testing = true;
      _tested.clear();
      for (final n in _nodes) {
        n.latency = null;
      }
    });
    final queue = List<ServerNode>.of(_nodes);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final n = queue.removeLast();
        final ms = _isUdp(n)
            ? await _latencyService.testIcmp(n)
            : await _latencyService.testLatency(
                n,
                timeout: const Duration(seconds: 3),
              );
        if (!mounted || run != _runId) return;
        setState(() {
          n.latency = ms;
          _tested.add(n);
        });
      }
    }

    await Future.wait(List.generate(4, (_) => worker()));
    if (!mounted || run != _runId) return;
    setState(() {
      _testing = false;
      int key(ServerNode n) => n.latency ?? 999999;
      _nodes.sort((a, b) => key(a).compareTo(key(b)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      expand: false,
      snap: true,
      initialChildSize: 0.7,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l?.selectNode ?? '选择节点',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '测速',
                      onPressed: (_testing || _isLoading) ? null : _runTest,
                      icon: Icon(
                        Icons.speed_rounded,
                        color: _testing
                            ? AppColors.textSecondary
                            : AppColors.accent,
                      ),
                    ),
                    IconButton(
                      tooltip: l?.refresh ?? '刷新',
                      onPressed: _isLoading ? null : () => _load(force: true),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                const Expanded(child: Center(child: FluxLoader(size: 30)))
              else if (_nodes.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      l?.noNodes ?? '暂无可用节点',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: _nodes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _buildItem(_nodes[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItem(ServerNode n) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          widget.onNodeSelected(n);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.85),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFF8F6FC)],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          n.protocol.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _latencyPill(n),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _latencyPill(ServerNode n) {
    if (!_tested.contains(n)) {
      return _pill(_testing ? '测速中' : '未测速', AppColors.textSecondary);
    }
    final ms = n.latency;
    if (ms == null) {
      return _isUdp(n)
          ? _pill('UDP·未响应', AppColors.textSecondary)
          : _pill('超时', AppColors.danger);
    }
    final c = ms < 200
        ? AppColors.success
        : (ms < 500 ? AppColors.warning : AppColors.danger);
    return _pill('${ms}ms', c);
  }

  Widget _pill(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: c,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
