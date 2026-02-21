import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:verinni_os/core/theme/app_theme.dart';
import 'package:verinni_os/core/utils/formatters.dart';
import 'package:verinni_os/shared/widgets/verinni_card.dart';

/// Totem de Produção — lê a tabela `orders` (OS reais)
/// Colunas: id, order_number, status, production_type, health, valor_venda,
///          vehicle_id, leader_id, budget_id, created_at, updated_at, etc.
/// Joins: budgets → clients (para nome do cliente)
class TotemScreen extends StatefulWidget {
  const TotemScreen({super.key});

  @override
  State<TotemScreen> createState() => _TotemScreenState();
}

class _TotemScreenState extends State<TotemScreen>
    with SingleTickerProviderStateMixin {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  late TabController _tabController;

  final _tabLabels = ['Em Aberto', 'Em Andamento', 'Concluídos'];
  final _tabStatus = ['pending', 'in_progress', 'completed'];

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
      // Join: orders → budgets → clients para obter nome do cliente
      final data = await _db
          .from('orders')
          .select('*, budgets(id, budget_number, clients(id, name))')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      // Se o join falhar, busca sem join
      try {
        final data = await _db
            .from('orders')
            .select('*')
            .order('created_at', ascending: false);
        if (mounted) {
          setState(() {
            _orders = List<Map<String, dynamic>>.from(data);
          });
        }
      } catch (_) {
        if (mounted) setState(() => _orders = []);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _byStatus(String status) {
    return _orders.where((o) => o['status'] == status).toList();
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      await _db
          .from('orders')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status da OS atualizado!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
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
          tabs: _tabLabels.asMap().entries.map((e) {
            final count = _byStatus(_tabStatus[e.key]).length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.value, style: const TextStyle(fontSize: 13)),
                  if (!_isLoading) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: _tabStatus.map((status) {
                final items = _byStatus(status);
                if (items.isEmpty) {
                  return EmptyState(
                    icon: status == 'pending'
                        ? Icons.inbox_outlined
                        : status == 'in_progress'
                            ? Icons.precision_manufacturing_outlined
                            : Icons.check_circle_outline,
                    title: 'Nenhuma OS',
                    subtitle:
                        'Não há ordens de serviço ${_tabLabels[_tabStatus.indexOf(status)].toLowerCase()}',
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
                            childAspectRatio: 1.35,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) => _OrderCard(
                            order: items[i],
                            onUpdateStatus: _updateStatus,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _OrderCard(
                            order: items[i],
                            onUpdateStatus: _updateStatus,
                          ),
                        ),
                );
              }).toList(),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Future<void> Function(String id, String status) onUpdateStatus;

  const _OrderCard({required this.order, required this.onUpdateStatus});

  String _getTitle() {
    final orderNum = order['order_number']?.toString();
    if (orderNum != null) return 'OS #$orderNum';
    final id = order['id']?.toString() ?? '';
    return 'OS #${id.length > 8 ? id.substring(0, 8) : id}';
  }

  String _getClientName() {
    final budget = order['budgets'];
    if (budget is Map) {
      final client = budget['clients'];
      if (client is Map) {
        return client['name']?.toString() ?? '--';
      }
    }
    return '--';
  }

  String _getProductionType() {
    final pt = order['production_type']?.toString();
    if (pt == null || pt.isEmpty) return '';
    switch (pt) {
      case 'repair':
        return 'Reparo';
      case 'maintenance':
        return 'Manutenção';
      case 'installation':
        return 'Instalação';
      case 'inspection':
        return 'Inspeção';
      default:
        return pt;
    }
  }

  String _getHealth() {
    final h = order['health']?.toString();
    switch (h) {
      case 'good':
        return 'Bom';
      case 'warning':
        return 'Atenção';
      case 'critical':
        return 'Crítico';
      default:
        return '';
    }
  }

  Color _getHealthColor() {
    final h = order['health']?.toString();
    switch (h) {
      case 'good':
        return AppColors.success;
      case 'warning':
        return AppColors.warning;
      case 'critical':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = order['id']?.toString() ?? '';
    final status = order['status']?.toString() ?? 'pending';
    final clientName = _getClientName();
    final productionType = _getProductionType();
    final health = _getHealth();
    final valorVenda =
        double.tryParse(order['valor_venda']?.toString() ?? '0') ?? 0;

    return VerinniCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Text(
                  _getTitle(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 8),

          // Client
          if (clientName != '--') ...[
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    clientName,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // Production type + Health
          Row(
            children: [
              if (productionType.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    productionType,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (health.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getHealthColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _getHealthColor().withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    health,
                    style: TextStyle(
                        color: _getHealthColor(),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              const Spacer(),
              if (valorVenda > 0)
                Text(
                  AppFormatters.currency(valorVenda),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Date
          Row(
            children: [
              const Icon(Icons.access_time, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                AppFormatters.dateFromString(order['created_at']?.toString()),
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),

          const Spacer(),
          const SizedBox(height: 10),

          // Action button
          if (status == 'pending')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onUpdateStatus(id, 'in_progress'),
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Iniciar OS'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else if (status == 'in_progress')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onUpdateStatus(id, 'completed'),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Concluir OS'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            Row(
              children: [
                const Icon(Icons.check_circle,
                    size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                const Text(
                  'OS Concluída',
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

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = AppColors.statusPending;
        label = 'Em Aberto';
        break;
      case 'in_progress':
        color = AppColors.statusInProgress;
        label = 'Em Andamento';
        break;
      case 'completed':
        color = AppColors.statusCompleted;
        label = 'Concluído';
        break;
      case 'cancelled':
        color = AppColors.statusCancelled;
        label = 'Cancelado';
        break;
      default:
        color = AppColors.textMuted;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
