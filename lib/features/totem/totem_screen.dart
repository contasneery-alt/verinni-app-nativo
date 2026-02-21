import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:verinni_os/core/theme/app_theme.dart';
import 'package:verinni_os/core/utils/formatters.dart';
import 'package:verinni_os/shared/widgets/verinni_card.dart';

class TotemScreen extends StatefulWidget {
  const TotemScreen({super.key});

  @override
  State<TotemScreen> createState() => _TotemScreenState();
}

class _TotemScreenState extends State<TotemScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _ordens = [];
  bool _isLoading = true;
  late TabController _tabController;

  final _statusTabs = ['Em Aberto', 'Em Andamento', 'Concluídos'];
  final _statusKeys = ['pending', 'in_progress', 'completed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      // Try orcamentos table as production orders
      final data = await _supabase
          .from('orcamentos')
          .select('*')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _ordens = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (_) {
      // Try production_orders table
      try {
        final data = await _supabase
            .from('production_orders')
            .select('*')
            .order('created_at', ascending: false);
        if (mounted) {
          setState(() {
            _ordens = List<Map<String, dynamic>>.from(data);
          });
        }
      } catch (_) {
        if (mounted) setState(() => _ordens = []);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _getByStatus(String status) {
    return _ordens.where((o) => o['status'] == status).toList();
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await _supabase
          .from('orcamentos')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status atualizado!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Totem de Produção'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
            tooltip: 'Atualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _statusTabs
              .asMap()
              .entries
              .map((e) => Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(e.value),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_getByStatus(_statusKeys[e.key]).length}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: _statusKeys.map((status) {
                final items = _getByStatus(status);
                if (items.isEmpty) {
                  return EmptyState(
                    icon: status == 'pending'
                        ? Icons.inbox_outlined
                        : status == 'in_progress'
                            ? Icons.precision_manufacturing_outlined
                            : Icons.check_circle_outline,
                    title: 'Nenhuma ordem',
                    subtitle: 'Não há ordens ${_statusTabs[_statusKeys.indexOf(status)].toLowerCase()} no momento',
                  );
                }
                return RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  child: isTablet
                      ? GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.4,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) => _TotemCard(
                            ordem: items[i],
                            onUpdateStatus: _updateStatus,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _TotemCard(
                            ordem: items[i],
                            onUpdateStatus: _updateStatus,
                          ),
                        ),
                );
              }).toList(),
            ),
    );
  }
}

class _TotemCard extends StatelessWidget {
  final Map<String, dynamic> ordem;
  final Future<void> Function(String id, String status) onUpdateStatus;

  const _TotemCard({required this.ordem, required this.onUpdateStatus});

  @override
  Widget build(BuildContext context) {
    final id = ordem['id']?.toString() ?? '';
    final status = ordem['status'] as String? ?? 'pending';
    final title = ordem['title'] ??
        ordem['client_name'] ??
        'OS #${id.length > 8 ? id.substring(0, 8) : id}';

    return VerinniCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                status: status,
                label: _statusLabel(status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ordem['services'] != null) ...[
            Text(
              ordem['services'],
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                AppFormatters.dateFromString(ordem['created_at']?.toString()),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 12),
          // Action buttons
          if (status == 'pending')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onUpdateStatus(id, 'in_progress'),
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Iniciar'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  backgroundColor: AppColors.primary,
                ),
              ),
            )
          else if (status == 'in_progress')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onUpdateStatus(id, 'completed'),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Concluir'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  backgroundColor: AppColors.success,
                ),
              ),
            )
          else
            Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                const SizedBox(width: 4),
                const Text(
                  'Ordem Concluída',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Em Aberto';
      case 'in_progress':
        return 'Em Andamento';
      case 'completed':
        return 'Concluído';
      default:
        return status;
    }
  }
}
