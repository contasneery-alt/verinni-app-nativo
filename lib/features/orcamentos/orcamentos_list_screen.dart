import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:verinni_os/core/services/budget_service.dart';
import 'package:verinni_os/core/theme/app_theme.dart';
import 'package:verinni_os/core/utils/formatters.dart';
import 'package:verinni_os/shared/widgets/verinni_card.dart';

class OrcamentosListScreen extends StatefulWidget {
  const OrcamentosListScreen({super.key});
  @override
  State<OrcamentosListScreen> createState() => _OrcamentosListScreenState();
}

class _OrcamentosListScreenState extends State<OrcamentosListScreen> {
  final _searchCtrl = TextEditingController();
  String _filter = 'todos';
  String _search = '';

  static const _filters = [
    {'key': 'todos',       'label': 'Todos'},
    {'key': 'pending',     'label': 'Pendente'},
    {'key': 'draft',       'label': 'Rascunho'},
    {'key': 'sent',        'label': 'Enviado'},
    {'key': 'approved',    'label': 'Aprovado'},
    {'key': 'in_progress', 'label': 'Em Andamento'},
    {'key': 'completed',   'label': 'Concluído'},
    {'key': 'cancelled',   'label': 'Cancelado'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetService>().loadBudgets();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> all) {
    return all.where((b) {
      final matchFilter = _filter == 'todos' || b['status'] == _filter;
      if (!matchFilter) return false;
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      final num = b['budget_number']?.toString().toLowerCase() ?? '';
      final client = (b['clients'] is Map)
          ? b['clients']['name']?.toString().toLowerCase() ?? ''
          : '';
      final obs = b['observacoes']?.toString().toLowerCase() ?? '';
      return num.contains(q) || client.contains(q) || obs.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BudgetService>();
    final filtered = _filtered(svc.budgets);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Orçamentos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: svc.loadBudgets,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/orcamentos/novo'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, semanticLabel: 'Novo orçamento'),
        label: const Text('Novo', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar por número, cliente...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        })
                    : null,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          // Filters
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final sel = _filter == f['key'];
                return FilterChip(
                  label: Text(f['label']!),
                  selected: sel,
                  onSelected: (_) => setState(() => _filter = f['key']!),
                  backgroundColor: AppColors.surfaceElevated,
                  selectedColor: AppColors.primaryGlow,
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: sel ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: sel ? AppColors.primary : AppColors.border,
                    width: sel ? 1.5 : 1,
                  ),
                );
              },
            ),
          ),
          // Count
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Text(
                  '${filtered.length} orçamento${filtered.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: svc.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : svc.error != null && svc.budgets.isEmpty
                    ? EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Erro ao carregar',
                        subtitle: svc.error!,
                        actionLabel: 'Tentar novamente',
                        onAction: svc.loadBudgets)
                    : filtered.isEmpty
                        ? EmptyState(
                            icon: Icons.description_outlined,
                            title: _search.isNotEmpty
                                ? 'Sem resultados'
                                : 'Nenhum orçamento',
                            subtitle: _search.isNotEmpty
                                ? 'Nenhum orçamento para "$_search"'
                                : 'Crie um novo orçamento',
                            actionLabel: 'Novo Orçamento',
                            onAction: () => context.go('/orcamentos/novo'))
                        : RefreshIndicator(
                            color: AppColors.primary,
                            backgroundColor: AppColors.surface,
                            onRefresh: svc.loadBudgets,
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) =>
                                  _BudgetCard(budget: filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Map<String, dynamic> budget;
  const _BudgetCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<BudgetService>();
    final status = budget['status'] as String? ?? 'pending';
    final client = budget['clients'];
    final clientName =
        client is Map ? client['name']?.toString() ?? '--' : '--';
    final num = budget['budget_number']?.toString() ??
        budget['id'].toString().substring(0, 8);
    final valorVenda =
        double.tryParse(budget['valor_venda']?.toString() ?? '0') ?? 0;
    final desconto =
        double.tryParse(budget['desconto']?.toString() ?? '0') ?? 0;

    return VerinniCard(
      onTap: () => context.go('/orcamentos/${budget['id']}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Orçamento #$num',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
              ),
              StatusBadge(status: status, label: svc.statusLabel(status)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(clientName,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                AppFormatters.dateFromString(
                    budget['created_at']?.toString()),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          if (budget['validade'] != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.event_outlined,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                'Válido até ${AppFormatters.dateFromString(budget['validade']?.toString())}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
              ),
            ]),
          ],
          if (valorVenda > 0) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desconto > 0)
                      Text(
                        'Desconto: ${AppFormatters.currency(desconto)}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                    const Text('Valor de Venda',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
                Text(
                  AppFormatters.currency(valorVenda),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
