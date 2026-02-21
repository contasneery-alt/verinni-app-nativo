import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:verinni_os/core/services/orcamento_service.dart';
import 'package:verinni_os/core/theme/app_theme.dart';
import 'package:verinni_os/core/utils/formatters.dart';
import 'package:verinni_os/shared/widgets/verinni_card.dart';

class OrcamentosListScreen extends StatefulWidget {
  const OrcamentosListScreen({super.key});

  @override
  State<OrcamentosListScreen> createState() => _OrcamentosListScreenState();
}

class _OrcamentosListScreenState extends State<OrcamentosListScreen> {
  final _searchController = TextEditingController();
  String _filter = 'todos';
  String _searchQuery = '';

  final _filters = [
    {'key': 'todos', 'label': 'Todos'},
    {'key': 'pending', 'label': 'Pendentes'},
    {'key': 'approved', 'label': 'Aprovados'},
    {'key': 'in_progress', 'label': 'Em Andamento'},
    {'key': 'completed', 'label': 'Concluídos'},
    {'key': 'cancelled', 'label': 'Cancelados'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrcamentoService>().loadOrcamentos();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filteredOrcamentos(
      List<Map<String, dynamic>> all) {
    return all.where((orc) {
      final matchFilter =
          _filter == 'todos' || orc['status'] == _filter;
      final query = _searchQuery.toLowerCase();
      final matchSearch = query.isEmpty ||
          (orc['title']?.toString().toLowerCase().contains(query) ?? false) ||
          (orc['client_name']?.toString().toLowerCase().contains(query) ??
              false) ||
          (orc['id']?.toString().toLowerCase().contains(query) ?? false);
      return matchFilter && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<OrcamentoService>();
    final filtered = _filteredOrcamentos(svc.orcamentos);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Orçamentos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => svc.loadOrcamentos(),
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
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar orçamentos...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Filter chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _filters[i];
                final isSelected = _filter == f['key'];
                return FilterChip(
                  label: Text(f['label']!),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _filter = f['key']!),
                  backgroundColor: AppColors.surfaceElevated,
                  selectedColor: AppColors.primaryGlow,
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 4),

          // Content
          Expanded(
            child: svc.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : svc.error != null && svc.orcamentos.isEmpty
                    ? EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Erro ao carregar',
                        subtitle:
                            'Verifique a conexão com o banco de dados.\n${svc.error}',
                        actionLabel: 'Tentar novamente',
                        onAction: () => svc.loadOrcamentos(),
                      )
                    : filtered.isEmpty
                        ? EmptyState(
                            icon: Icons.description_outlined,
                            title: _searchQuery.isNotEmpty
                                ? 'Nenhum resultado'
                                : 'Nenhum orçamento',
                            subtitle: _searchQuery.isNotEmpty
                                ? 'Nenhum orçamento encontrado para "$_searchQuery"'
                                : 'Crie um novo orçamento usando o botão abaixo',
                            actionLabel: 'Novo Orçamento',
                            onAction: () => context.go('/orcamentos/novo'),
                          )
                        : RefreshIndicator(
                            color: AppColors.primary,
                            backgroundColor: AppColors.surface,
                            onRefresh: svc.loadOrcamentos,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) =>
                                  _OrcamentoCard(orc: filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _OrcamentoCard extends StatelessWidget {
  final Map<String, dynamic> orc;

  const _OrcamentoCard({required this.orc});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<OrcamentoService>();
    final status = orc['status'] as String? ?? 'pending';
    final statusLabel = svc.getStatusLabel(status);
    final valor = orc['total_value'] ?? orc['valor'] ?? orc['amount'];
    final id = orc['id']?.toString() ?? '';

    return VerinniCard(
      onTap: () => context.go('/orcamentos/$id'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  orc['title'] ??
                      orc['client_name'] ??
                      'Orçamento #${id.length > 8 ? id.substring(0, 8) : id}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: status, label: statusLabel),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoItem(
                icon: Icons.person_outline,
                label: orc['client_name'] ?? orc['nome_cliente'] ?? '--',
              ),
              const SizedBox(width: 16),
              _InfoItem(
                icon: Icons.calendar_today_outlined,
                label: AppFormatters.dateFromString(
                    orc['created_at']?.toString()),
              ),
            ],
          ),
          if (valor != null) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Valor Total',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                Text(
                  AppFormatters.currency(
                      double.tryParse(valor.toString()) ?? 0.0),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
