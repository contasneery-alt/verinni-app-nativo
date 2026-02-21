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
  final _db = Supabase.instance.client;

  // real counters
  int _budgetsTotal = 0;
  int _budgetsPending = 0;
  int _ordersInProgress = 0;
  int _vehiclesActive = 0;
  int _employeesActive = 0;
  double _revenueMonth = 0;

  List<Map<String, dynamic>> _recentBudgets = [];
  List<Map<String, dynamic>> _recentOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadCounts(),
      _loadRecentBudgets(),
      _loadRecentOrders(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadCounts() async {
    // budgets total
    try {
      final r = await _db
          .from('budgets')
          .select('id')
          .count(CountOption.exact);
      setState(() => _budgetsTotal = r.count);
    } catch (_) {}

    // budgets pending
    try {
      final r = await _db
          .from('budgets')
          .select('id')
          .eq('status', 'pending')
          .count(CountOption.exact);
      setState(() => _budgetsPending = r.count);
    } catch (_) {}

    // orders in progress
    try {
      final r = await _db
          .from('orders')
          .select('id')
          .eq('status', 'in_progress')
          .count(CountOption.exact);
      setState(() => _ordersInProgress = r.count);
    } catch (_) {}

    // vehicles active
    try {
      final r = await _db
          .from('vehicles')
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);
      setState(() => _vehiclesActive = r.count);
    } catch (_) {}

    // employees active
    try {
      final r = await _db
          .from('employees')
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);
      setState(() => _employeesActive = r.count);
    } catch (_) {}

    // revenue this month (paid income)
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1).toIso8601String();
      final data = await _db
          .from('financial_transactions')
          .select('amount')
          .eq('type', 'income')
          .eq('status', 'paid')
          .gte('paid_date', start);
      double total = 0;
      for (final t in data) {
        total += double.tryParse(t['amount']?.toString() ?? '0') ?? 0;
      }
      setState(() => _revenueMonth = total);
    } catch (_) {}
  }

  Future<void> _loadRecentBudgets() async {
    try {
      final data = await _db
          .from('budgets')
          .select('id, budget_number, status, valor_venda, created_at, clients(name)')
          .order('created_at', ascending: false)
          .limit(4);
      if (mounted) setState(() => _recentBudgets = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  Future<void> _loadRecentOrders() async {
    try {
      final data = await _db
          .from('orders')
          .select('id, order_number, status, health, data_entrega_prevista, clients(name)')
          .order('created_at', ascending: false)
          .limit(4);
      if (mounted) setState(() => _recentOrders = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Bom dia' : hour < 18 ? 'Boa tarde' : 'Boa noite';
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // ── App bar ────────────────────────────────────────────
            SliverAppBar(
              backgroundColor: AppColors.surface,
              floating: true,
              snap: true,
              expandedHeight: 130,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting, ${auth.userName.split(' ').first}!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            AppFormatters.date(DateTime.now()),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              auth.roleLabel,
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
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
              // ── KPI grid ─────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverGrid(
                  delegate: SliverChildListDelegate([
                    StatCard(
                      title: 'Orçamentos',
                      value: '$_budgetsTotal',
                      icon: Icons.description_outlined,
                      iconColor: AppColors.primary,
                      subtitle: '$_budgetsPending pendentes',
                      onTap: () => context.go('/orcamentos'),
                    ),
                    StatCard(
                      title: 'Em Produção',
                      value: '$_ordersInProgress',
                      icon: Icons.precision_manufacturing_outlined,
                      iconColor: AppColors.warning,
                      subtitle: 'Ordens em andamento',
                      onTap: () => context.go('/totem'),
                    ),
                    StatCard(
                      title: 'Receita/Mês',
                      value: AppFormatters.currencyCompact(_revenueMonth),
                      icon: Icons.trending_up,
                      iconColor: AppColors.success,
                      subtitle: 'Mês atual (pago)',
                      onTap: () => context.go('/financeiro'),
                    ),
                    StatCard(
                      title: 'Frota Ativa',
                      value: '$_vehiclesActive',
                      icon: Icons.directions_car_outlined,
                      iconColor: AppColors.info,
                      subtitle: '$_employeesActive funcionários ativos',
                      onTap: () => context.go('/frota'),
                    ),
                  ]),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 4 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isWide ? 1.3 : 1.05,
                  ),
                ),
              ),

              // ── Quick actions ─────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ações Rápidas',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.add_circle_outline,
                              label: 'Novo\nOrçamento',
                              color: AppColors.primary,
                              onTap: () => context.go('/orcamentos/novo'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.factory_outlined,
                              label: 'Totem\nProdução',
                              color: AppColors.warning,
                              onTap: () => context.go('/totem'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.local_gas_station_outlined,
                              label: 'Abast.\nFrota',
                              color: AppColors.success,
                              onTap: () => context.go('/frota'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.bar_chart_outlined,
                              label: 'Financeiro',
                              color: AppColors.info,
                              onTap: () => context.go('/financeiro'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Recent budgets ────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Orçamentos Recentes',
                    onSeeAll: () => context.go('/orcamentos'),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      if (_recentBudgets.isEmpty) {
                        return const _EmptyRow(
                            label: 'Nenhum orçamento encontrado');
                      }
                      if (i >= _recentBudgets.length) return null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _BudgetRow(budget: _recentBudgets[i]),
                      );
                    },
                    childCount:
                        _recentBudgets.isEmpty ? 1 : _recentBudgets.length,
                  ),
                ),
              ),

              // ── Recent orders ─────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Ordens em Produção',
                    onSeeAll: () => context.go('/totem'),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      if (_recentOrders.isEmpty) {
                        return const _EmptyRow(
                            label: 'Nenhuma ordem em produção');
                      }
                      if (i >= _recentOrders.length) return null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _OrderRow(order: _recentOrders[i]),
                      );
                    },
                    childCount:
                        _recentOrders.isEmpty ? 1 : _recentOrders.length,
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary,
                    child: Text(AppFormatters.initials(auth.userName),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auth.userName,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        Text(auth.userEmail,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                        if (auth.userSetor.isNotEmpty)
                          Text(auth.userSetor,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(auth.roleLabel,
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
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
              title: const Text('Sair da Conta',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w500)),
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

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: const Text('Ver todos')),
        ],
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => VerinniCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 2),
          ],
        ),
      );
}

class _BudgetRow extends StatelessWidget {
  final Map<String, dynamic> budget;
  const _BudgetRow({required this.budget});

  @override
  Widget build(BuildContext context) {
    final status = budget['status'] as String? ?? 'pending';
    final client = budget['clients'];
    final clientName = client is Map ? client['name']?.toString() : null;
    final num = budget['budget_number']?.toString() ?? budget['id'].toString().substring(0, 8);
    final valor = double.tryParse(budget['valor_venda']?.toString() ?? '0') ?? 0;

    return VerinniCard(
      onTap: () => context.go('/orcamentos/${budget['id']}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.description_outlined,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Orç. #$num',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                if (clientName != null)
                  Text(clientName,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(status: status, label: _lbl(status)),
              const SizedBox(height: 4),
              if (valor > 0)
                Text(AppFormatters.currency(valor),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  String _lbl(String s) {
    const m = {
      'pending': 'Pendente', 'approved': 'Aprovado',
      'in_progress': 'Em Andamento', 'completed': 'Concluído',
      'cancelled': 'Cancelado', 'draft': 'Rascunho', 'sent': 'Enviado',
    };
    return m[s] ?? s;
  }
}

class _OrderRow extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'pending';
    final health = order['health'] as String?;
    final client = order['clients'];
    final clientName = client is Map ? client['name']?.toString() : null;
    final num = order['order_number']?.toString() ?? order['id'].toString().substring(0, 8);

    Color healthColor = AppColors.success;
    if (health == 'yellow') healthColor = AppColors.warning;
    if (health == 'red') healthColor = AppColors.error;

    return VerinniCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: healthColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.precision_manufacturing_outlined,
                color: healthColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OS #$num',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                if (clientName != null)
                  Text(clientName,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          StatusBadge(status: status, label: _lbl(status)),
        ],
      ),
    );
  }

  String _lbl(String s) {
    const m = {
      'pending': 'Aguardando', 'in_progress': 'Em Produção',
      'completed': 'Entregue', 'cancelled': 'Cancelado',
    };
    return m[s] ?? s;
  }
}

class _EmptyRow extends StatelessWidget {
  final String label;
  const _EmptyRow({required this.label});

  @override
  Widget build(BuildContext context) => VerinniCard(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 14)),
        ),
      );
}
