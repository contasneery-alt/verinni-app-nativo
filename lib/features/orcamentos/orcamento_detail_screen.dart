import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:verinni_os/core/services/budget_service.dart';
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
  Map<String, dynamic>? _budget;
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
    final svc = context.read<BudgetService>();
    final data = await svc.getBudget(widget.id);
    if (!mounted) return;
    setState(() {
      _budget = data;
      _isLoading = false;
      if (data == null) _error = 'Orçamento não encontrado';
    });
  }

  Future<void> _updateStatus(String status) async {
    final svc = context.read<BudgetService>();
    final error = await svc.updateStatus(widget.id, status);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
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

  Future<void> _exportPdf() async {
    if (_budget == null) return;

    final svc = context.read<BudgetService>();
    final client = _budget!['clients'] is Map ? _budget!['clients'] : null;
    final budgetNum =
        _budget!['budget_number']?.toString() ?? widget.id.substring(0, 8);
    final valorVenda =
        double.tryParse(_budget!['valor_venda']?.toString() ?? '0') ?? 0;
    final valorOriginal =
        double.tryParse(_budget!['valor_original']?.toString() ?? '0') ?? 0;
    final desconto =
        double.tryParse(_budget!['desconto']?.toString() ?? '0') ?? 0;

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#0A0F1E'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Verinni OS',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          'Sistema de Gestão Industrial',
                          style: pw.TextStyle(
                              fontSize: 12, color: PdfColors.grey400),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'ORÇAMENTO',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#3B82F6'),
                          ),
                        ),
                        pw.Text(
                          '#$budgetNum',
                          style: pw.TextStyle(
                              fontSize: 12, color: PdfColors.grey400),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Status and Date
              pw.Row(
                children: [
                  pw.Text('Status: ',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(svc.statusLabel(_budget!['status'])),
                  pw.Spacer(),
                  pw.Text('Data: ',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(AppFormatters.dateFromString(
                      _budget!['created_at']?.toString())),
                ],
              ),
              if (_budget!['validade'] != null) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Text('Válido até: ',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(AppFormatters.dateFromString(
                        _budget!['validade']?.toString())),
                  ],
                ),
              ],
              pw.SizedBox(height: 24),
              pw.Divider(),
              pw.SizedBox(height: 16),

              // Client
              pw.Text(
                'DADOS DO CLIENTE',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#3B82F6'),
                ),
              ),
              pw.SizedBox(height: 8),
              if (client != null) ...[
                pw.Text('Nome: ${client['name'] ?? '--'}'),
                if (client['email'] != null)
                  pw.Text('E-mail: ${client['email']}'),
                if (client['phone'] != null)
                  pw.Text('Telefone: ${AppFormatters.phone(client['phone'])}'),
                if (client['cnpj'] != null) pw.Text('CNPJ: ${client['cnpj']}'),
                if (client['city'] != null)
                  pw.Text(
                      'Cidade: ${client['city']}${client['state'] != null ? '/${client['state']}' : ''}'),
              ] else
                pw.Text('Sem dados do cliente'),
              pw.SizedBox(height: 24),
              pw.Divider(),
              pw.SizedBox(height: 16),

              // Notes / Observations
              if (_budget!['observacoes'] != null) ...[
                pw.Text(
                  'OBSERVAÇÕES',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#3B82F6'),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(_budget!['observacoes'].toString()),
                pw.SizedBox(height: 24),
                pw.Divider(),
                pw.SizedBox(height: 16),
              ],

              // Financial
              pw.Text(
                'RESUMO FINANCEIRO',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#3B82F6'),
                ),
              ),
              pw.SizedBox(height: 8),
              if (valorOriginal > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Valor Original:'),
                    pw.Text(AppFormatters.currency(valorOriginal)),
                  ],
                ),
              if (desconto > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Desconto:'),
                    pw.Text('- ${AppFormatters.currency(desconto)}'),
                  ],
                ),
              ],
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'VALOR DE VENDA:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  pw.Text(
                    AppFormatters.currency(valorVenda),
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                      color: PdfColor.fromHex('#3B82F6'),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 40),

              // Footer
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Verinni OS • Sistema Industrial • Documento gerado em ${AppFormatters.dateTimeFromString(DateTime.now().toIso8601String())}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ),
            ],
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'orcamento_$budgetNum.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.read<BudgetService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _budget != null
              ? 'Orçamento #${_budget!['budget_number'] ?? widget.id.substring(0, 8)}'
              : 'Detalhes do Orçamento',
        ),
        actions: [
          if (_budget != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Exportar PDF',
              onPressed: _exportPdf,
            ),
          if (_budget != null)
            PopupMenuButton<String>(
              onSelected: _updateStatus,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'draft', child: Text('Rascunho')),
                PopupMenuItem(value: 'pending', child: Text('Pendente')),
                PopupMenuItem(value: 'sent', child: Text('Enviado')),
                PopupMenuItem(
                    value: 'negotiating', child: Text('Negociando')),
                PopupMenuItem(value: 'approved', child: Text('Aprovado')),
                PopupMenuItem(
                    value: 'in_progress', child: Text('Em Andamento')),
                PopupMenuItem(value: 'completed', child: Text('Concluído')),
                PopupMenuItem(value: 'cancelled', child: Text('Cancelado')),
              ],
              icon: const Icon(Icons.more_vert),
              tooltip: 'Alterar status',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
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
                      // Header card
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
                                    'Orçamento #${_budget!['budget_number'] ?? widget.id.substring(0, 8)}',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppFormatters.dateTimeFromString(
                                        _budget!['created_at']?.toString()),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              status: _budget!['status'] ?? 'pending',
                              label: svc.statusLabel(_budget!['status']),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Client info
                      _buildClientSection(),
                      const SizedBox(height: 12),

                      // Budget details
                      _buildDetailsSection(),
                      const SizedBox(height: 12),

                      // Financial summary
                      _buildFinancialSection(),
                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _exportPdf,
                              icon: const Icon(Icons.picture_as_pdf_outlined,
                                  size: 18),
                              label: const Text('Exportar PDF'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _showStatusDialog,
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

  Widget _buildClientSection() {
    final client = _budget!['clients'];
    if (client is! Map) {
      return _SectionCard(
        title: 'Cliente',
        children: [
          const _DetailRow(label: 'Cliente', value: 'Não vinculado'),
        ],
      );
    }
    return _SectionCard(
      title: 'Informações do Cliente',
      children: [
        _DetailRow(label: 'Nome', value: client['name']?.toString() ?? '--'),
        if (client['email'] != null)
          _DetailRow(label: 'E-mail', value: client['email'].toString()),
        if (client['phone'] != null)
          _DetailRow(
              label: 'Telefone',
              value: AppFormatters.phone(client['phone']?.toString())),
        if (client['cnpj'] != null)
          _DetailRow(label: 'CNPJ', value: client['cnpj'].toString()),
        if (client['city'] != null)
          _DetailRow(
              label: 'Cidade',
              value:
                  '${client['city']}${client['state'] != null ? '/${client['state']}' : ''}'),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return _SectionCard(
      title: 'Detalhes do Orçamento',
      children: [
        if (_budget!['validade'] != null)
          _DetailRow(
            label: 'Validade',
            value: AppFormatters.dateFromString(_budget!['validade'].toString()),
          ),
        if (_budget!['observacoes'] != null &&
            _budget!['observacoes'].toString().isNotEmpty)
          _DetailRow(
            label: 'Observações',
            value: _budget!['observacoes'].toString(),
          ),
        if (_budget!['created_at'] != null)
          _DetailRow(
            label: 'Criado em',
            value: AppFormatters.dateTimeFromString(
                _budget!['created_at'].toString()),
          ),
      ],
    );
  }

  Widget _buildFinancialSection() {
    final valorVenda =
        double.tryParse(_budget!['valor_venda']?.toString() ?? '0') ?? 0;
    final valorOriginal =
        double.tryParse(_budget!['valor_original']?.toString() ?? '0') ?? 0;
    final desconto =
        double.tryParse(_budget!['desconto']?.toString() ?? '0') ?? 0;

    return VerinniCard(
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
          if (valorOriginal > 0)
            _FinancialRow(label: 'Valor Original', value: valorOriginal),
          if (desconto > 0)
            _FinancialRow(
                label: 'Desconto', value: desconto, isNegative: true),
          const Divider(color: AppColors.border, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Valor de Venda',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                AppFormatters.currency(valorVenda),
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
    );
  }

  void _showStatusDialog() {
    final svc = context.read<BudgetService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            'draft',
            'pending',
            'sent',
            'negotiating',
            'approved',
            'in_progress',
            'completed',
            'cancelled',
          ].map((s) {
            return ListTile(
              leading: StatusBadge(status: s, label: svc.statusLabel(s)),
              onTap: () {
                Navigator.pop(ctx);
                _updateStatus(s);
              },
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
        ),
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
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
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
