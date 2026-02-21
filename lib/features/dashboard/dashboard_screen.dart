import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:verinni_os/core/services/auth_service.dart';
import 'package:verinni_os/core/theme/app_theme.dart';
import 'package:verinni_os/core/utils/formatters.dart';
import 'package:verinni_os/shared/widgets/verinni_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentOrcamentos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadStats(),
        _loadRecentOrcamentos(),
      ]);
    } catch (e) {
      // Silently handle errors - show empty state
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadStats() async {
    try {
      // Load orcamentos count
      final orcCount =
          await _supabase.from('orcamentos').select('id').count();
      final orcApproved = await _supabase
          .from('orcamentos')
          .select('id')
          .eq('status', 'approved')
          .count();
      final orcPending = await _supabase
          .from('orcamentos')
          .select('id')
          .eq('status', 'pending')
          .count();

      if (mounted) {
        setState(() {
          _stats['orcamentos_total'] = orcCount.count;
          _stats['orcamentos_aprovados'] = orcApproved.count;
          _stats['orcamentos_pendentes'] = orcPending.count;
        });
      }
    } catch (_) {}

    try {
      final veiculos =
          await _supabase.from('vehicles').select('id').count();
      if (mounted) {
        setState(() {
          _stats['veiculos_total'] = veiculos.count;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRecentOrcamentos() async {
    try {
      final data = await _supabase
          .from('orcamentos')
          .select('*')
          .order('created_at', ascending: false)
          .limit(5);
      if (mounted) {
        setState(() {
          _recentOrcamentos = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (_) {
      _recentOrcamentos = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Bom dia'
        : hour < 18
            ? 'Boa tarde'
            : 'Boa noite';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              backgroundColor: AppColors.surface,
              floating: true,
              snap: true,
              pinned: false,
              expandedHeight: 140,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting, ${auth.userName.split(' ').first}!',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppFormatters.date(DateTime.now()),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  color: AppColors.textSecondary,
                  onPressed: () {},
                  tooltip: 'Notificações',
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () => _showProfileMenu(context),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        AppFormatters.initials(auth.userName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else ...[
              // Stats grid
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  delegate: SliverChildListDelegate([
                    StatCard(
                      title: 'Orçamentos',
                      value: '${_stats['orcamentos_total'] ?? 0}',
                      icon: Icons.description_outlined,
                      iconColor: AppColors.primary,
                      subtitle: 'Total cadastrados',
                      onTap: () => context.go('/orcamentos'),
                    ),
                    StatCard(
                      title: 'Aprovados',
                      value: '${_stats['orcamentos_aprovados'] ?? 0}',
                      icon: Icons.check_circle_outline,
                      iconColor: AppColors.success,
                      subtitle: 'Este mês',
                    ),
                    StatCard(
                      title: 'Pendentes',
                      value: '${_stats['orcamentos_pendentes'] ?? 0}',
                      icon: Icons.pending_outlined,
                      iconColor: AppColors.warning,
                      subtitle: 'Aguardando revisão',
                    ),
                    StatCard(
                      title: 'Frota',
                      value: '${_stats['veiculos_total'] ?? 0}',
                      icon: Icons.directions_car_outlined,
                      iconColor: AppColors.info,
                      subtitle: 'Veículos cadastrados',
                      onTap: () => context.go('/frota'),
                    ),
                  ]),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                ),
              ),

              // Quick actions
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ações Rápidas',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.add_circle_outline,
                              label: 'Novo Orçamento',
                              color: AppColors.primary,
                              onTap: () => context.go('/orcamentos/novo'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.factory_outlined,
                              label: 'Totem Produção',
                              color: AppColors.warning,
                              onTap: () => context.go('/totem'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.bar_chart,
                              label: 'Financeiro',
                              color: AppColors.success,
                              onTap: () => context.go('/financeiro'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Recent orcamentos
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Orçamentos Recentes',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/orcamentos'),
                            child: const Text('Ver todos'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_recentOrcamentos.isEmpty)
                        VerinniCard(
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 48,
                                    color: AppColors.textMuted,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Nenhum orçamento encontrado',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ...(_recentOrcamentos.map((orc) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _OrcamentoListItem(orc: orc),
                            ))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    final auth = context.read<AuthService>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      AppFormatters.initials(auth.userName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.userName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          auth.currentUser?.email ?? '',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            auth.userRole.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Sair da Conta',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await auth.signOut();
                if (context.mounted) context.go('/login');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return VerinniCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _OrcamentoListItem extends StatelessWidget {
  final Map<String, dynamic> orc;
  const _OrcamentoListItem({required this.orc});

  @override
  Widget build(BuildContext context) {
    final status = orc['status'] as String? ?? 'pending';
    final statusLabels = {
      'pending': 'Pendente',
      'approved': 'Aprovado',
      'in_progress': 'Em Andamento',
      'completed': 'Concluído',
      'cancelled': 'Cancelado',
    };

    return VerinniCard(
      onTap: () => context.go('/orcamentos/${orc['id']}'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orc['title'] ?? orc['client_name'] ?? 'Orçamento #${orc['id']?.toString().substring(0, 8)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  AppFormatters.dateFromString(orc['created_at']?.toString()),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(
            status: status,
            label: statusLabels[status] ?? status,
          ),
        ],
      ),
    );
  }
}
