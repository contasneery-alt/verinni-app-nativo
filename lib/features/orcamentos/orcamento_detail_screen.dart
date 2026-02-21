import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:verinni_os/core/services/orcamento_service.dart';
import 'package:verinni_os/core/theme/app_theme.dart';
import 'package:verinni_os/core/utils/formatters.dart';
import 'package:verinni_os/shared/widgets/verinni_card.dart';

class OrcamentoDetailScreen extends StatefulWidget {
  final String id;
  const OrcamentoDetailScreen({super.key, required this.id});

  @override
  State<OrcamentoDetailScreen> createState() => _OrcamentoDetailScreenState();
}

class _OrcamentoDetailScreenState extends State<OrcamentoDetailScreen> {
  Map<String, dynamic>? _orc;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final svc = context.read<OrcamentoService>();
    final data = await svc.getOrcamento(widget.id);
    if (!mounted) return;
    setState(() {
      _orc = data;
      _isLoading = false;
      if (data == null) _error = 'Orçamento não encontrado';
    });
  }

  Future<void> _updateStatus(String status) async {
    final svc = context.read<OrcamentoService>();
    final error = await svc.updateStatus(widget.id, status);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
        ),
      );
    } else {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status atualizado com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _orc != null
              ? _orc!['title'] ?? 'Orçamento'
              : 'Detalhes do Orçamento',
        ),
        actions: [
          if (_orc != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Exportar PDF',
              onPressed: _exportPdf,
            ),
          if (_orc != null)
            PopupMenuButton<String>(
              onSelected: _updateStatus,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'pending',
                  child: Text('Pendente'),
                ),
                const PopupMenuItem(
                  value: 'approved',
                  child: Text('Aprovado'),
                ),
                const PopupMenuItem(
                  value: 'in_progress',
                  child: Text('Em Andamento'),
                ),
                const PopupMenuItem(
                  value: 'completed',
                  child: Text('Concluído'),
                ),
                const PopupMenuItem(
                  value: 'cancelled',
                  child: Text('Cancelado'),
                ),
              ],
              icon: const Icon(Icons.more_vert),
              tooltip: 'Alterar status',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Erro',
                  subtitle: _error!,
                  actionLabel: 'Tentar novamente',
                  onAction: _load,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status card
                      VerinniCard(
                        gradient: AppColors.cardGradient,
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.description_outlined,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _orc!['title'] ??
                                        'Orçamento #${widget.id.substring(0, 8)}',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppFormatters.dateTimeFromString(
                                        _orc!['created_at']?.toString()),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              status: _orc!['status'] ?? 'pending',
                              label: context
                                  .read<OrcamentoService>()
                                  .getStatusLabel(_orc!['status']),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Details
                      _SectionCard(
                        title: 'Informações do Cliente',
                        children: [
                          _DetailRow(
                            label: 'Nome',
                            value: _orc!['client_name'] ??
                                _orc!['nome_cliente'] ??
                                '--',
                          ),
                          _DetailRow(
                            label: 'E-mail',
                            value: _orc!['client_email'] ??
                                _orc!['email'] ??
                                '--',
                          ),
                          _DetailRow(
                            label: 'Telefone',
                            value: AppFormatters.phone(
                                _orc!['client_phone']?.toString() ??
                                    _orc!['telefone']?.toString()),
                          ),
                          _DetailRow(
                            label: 'CPF/CNPJ',
                            value: _orc!['client_document'] ??
                                _orc!['cpf'] ??
                                '--',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _SectionCard(
                        title: 'Detalhes do Orçamento',
                        children: [
                          _DetailRow(
                            label: 'Serviços',
                            value: _orc!['services'] ??
                                _orc!['description'] ??
                                '--',
                          ),
                          _DetailRow(
                            label: 'Observações',
                            value: _orc!['notes'] ??
                                _orc!['observacoes'] ??
                                '--',
                          ),
                          _DetailRow(
                            label: 'Validade',
                            value: AppFormatters.dateFromString(
                                _orc!['expires_at']?.toString()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Financial summary
                      VerinniCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resumo Financeiro',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _FinancialRow(
                              label: 'Subtotal',
                              value: double.tryParse(
                                      _orc!['subtotal']?.toString() ?? '0') ??
                                  0,
                            ),
                            _FinancialRow(
                              label: 'Desconto',
                              value: double.tryParse(
                                      _orc!['discount']?.toString() ?? '0') ??
                                  0,
                              isNegative: true,
                            ),
                            const Divider(color: AppColors.border, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  AppFormatters.currency(
                                    double.tryParse(
                                            _orc!['total_value']?.toString() ??
                                                _orc!['valor']?.toString() ??
                                                _orc!['amount']?.toString() ??
                                                '0') ??
                                        0,
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _exportPdf,
                              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                              label: const Text('Exportar PDF'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showStatusDialog(),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Alterar Status'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  void _showStatusDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusOption(
              status: 'pending',
              label: 'Pendente',
              onTap: () {
                Navigator.pop(ctx);
                _updateStatus('pending');
              },
            ),
            _StatusOption(
              status: 'approved',
              label: 'Aprovado',
              onTap: () {
                Navigator.pop(ctx);
                _updateStatus('approved');
              },
            ),
            _StatusOption(
              status: 'in_progress',
              label: 'Em Andamento',
              onTap: () {
                Navigator.pop(ctx);
                _updateStatus('in_progress');
              },
            ),
            _StatusOption(
              status: 'completed',
              label: 'Concluído',
              onTap: () {
                Navigator.pop(ctx);
                _updateStatus('completed');
              },
            ),
            _StatusOption(
              status: 'cancelled',
              label: 'Cancelado',
              onTap: () {
                Navigator.pop(ctx);
                _updateStatus('cancelled');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Função de exportação PDF em desenvolvimento...'),
        backgroundColor: AppColors.info,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return VerinniCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isNegative;

  const _FinancialRow({
    required this.label,
    required this.value,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
          Text(
            '${isNegative ? '- ' : ''}${AppFormatters.currency(value)}',
            style: TextStyle(
              color: isNegative ? AppColors.error : AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String status;
  final String label;
  final VoidCallback onTap;

  const _StatusOption({
    required this.status,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: StatusBadge(status: status, label: label),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
