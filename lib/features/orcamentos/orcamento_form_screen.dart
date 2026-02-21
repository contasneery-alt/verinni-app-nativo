import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:verinni_os/core/services/auth_service.dart';
import 'package:verinni_os/core/services/budget_service.dart';
import 'package:verinni_os/core/theme/app_theme.dart';
import 'package:verinni_os/shared/widgets/verinni_card.dart';

class OrcamentoFormScreen extends StatefulWidget {
  const OrcamentoFormScreen({super.key});

  @override
  State<OrcamentoFormScreen> createState() => _OrcamentoFormScreenState();
}

class _OrcamentoFormScreenState extends State<OrcamentoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _obsController = TextEditingController();
  final _valorVendaController = TextEditingController();
  final _valorOriginalController = TextEditingController();
  final _descontoController = TextEditingController();
  final _validadeController = TextEditingController();

  bool _isLoading = false;
  String _status = 'pending';
  String? _selectedClientId;
  String? _selectedClientName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetService>().loadClients();
    });
  }

  @override
  void dispose() {
    _obsController.dispose();
    _valorVendaController.dispose();
    _valorOriginalController.dispose();
    _descontoController.dispose();
    _validadeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final auth = context.read<AuthService>();
    final svc = context.read<BudgetService>();

    final data = <String, dynamic>{
      'status': _status,
      'observacoes': _obsController.text.trim().isEmpty
          ? null
          : _obsController.text.trim(),
      'created_by': auth.currentUser?.id,
    };

    if (_selectedClientId != null) data['client_id'] = _selectedClientId;

    final valorVenda = double.tryParse(
        _valorVendaController.text.replaceAll(',', '.'));
    if (valorVenda != null) data['valor_venda'] = valorVenda;

    final valorOriginal = double.tryParse(
        _valorOriginalController.text.replaceAll(',', '.'));
    if (valorOriginal != null) data['valor_original'] = valorOriginal;

    final desconto = double.tryParse(
        _descontoController.text.replaceAll(',', '.'));
    if (desconto != null && desconto > 0) data['desconto'] = desconto;

    if (_validadeController.text.trim().isNotEmpty) {
      try {
        final parts = _validadeController.text.trim().split('/');
        if (parts.length == 3) {
          final dt = DateTime(int.parse(parts[2]), int.parse(parts[1]),
              int.parse(parts[0]));
          data['validade'] = dt.toIso8601String();
        }
      } catch (_) {}
    }

    final error = await svc.createBudget(data);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Orçamento criado com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/orcamentos');
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BudgetService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Novo Orçamento')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Client
              _FormSection(
                title: 'Cliente',
                children: [
                  svc.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary, strokeWidth: 2))
                      : svc.clients.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: AppColors.textMuted, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Nenhum cliente cadastrado. Faça login para carregar os clientes.',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedClientId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Selecionar Cliente',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              dropdownColor: AppColors.surfaceElevated,
                              style:
                                  const TextStyle(color: AppColors.textPrimary),
                              onChanged: (v) {
                                setState(() {
                                  _selectedClientId = v;
                                  final c = svc.clients.firstWhere(
                                    (c) => c['id'] == v,
                                    orElse: () => {},
                                  );
                                  _selectedClientName =
                                      c['name']?.toString();
                                });
                              },
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text(
                                    '— Sem cliente vinculado —',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 13),
                                  ),
                                ),
                                ...svc.clients.map((c) {
                                  return DropdownMenuItem<String>(
                                    value: c['id']?.toString(),
                                    child: Text(
                                      '${c['name'] ?? '--'}${c['cnpj'] != null ? '  (${c['cnpj']})' : ''}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                              ],
                            ),
                  if (_selectedClientName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Selecionado: $_selectedClientName',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Financial
              _FormSection(
                title: 'Valores',
                children: [
                  _buildField(
                    controller: _valorVendaController,
                    label: 'Valor de Venda (R\$) *',
                    hint: '0,00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Campo obrigatório';
                      }
                      if (double.tryParse(v.replaceAll(',', '.')) == null) {
                        return 'Valor inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _valorOriginalController,
                    label: 'Valor Original (R\$)',
                    hint: '0,00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _descontoController,
                    label: 'Desconto (R\$)',
                    hint: '0,00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Details
              _FormSection(
                title: 'Detalhes',
                children: [
                  _buildField(
                    controller: _validadeController,
                    label: 'Validade',
                    hint: 'DD/MM/AAAA',
                    keyboardType: TextInputType.datetime,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _obsController,
                    label: 'Observações',
                    hint: 'Informações adicionais...',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _status,
                    onChanged: (v) => setState(() => _status = v!),
                    style: const TextStyle(color: AppColors.textPrimary),
                    dropdownColor: AppColors.surfaceElevated,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'draft', child: Text('Rascunho')),
                      DropdownMenuItem(
                          value: 'pending', child: Text('Pendente')),
                      DropdownMenuItem(
                          value: 'sent', child: Text('Enviado')),
                      DropdownMenuItem(
                          value: 'approved', child: Text('Aprovado')),
                      DropdownMenuItem(
                          value: 'in_progress', child: Text('Em Andamento')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 20),
                  label: Text(
                    _isLoading ? 'Salvando...' : 'Salvar Orçamento',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FormSection({required this.title, required this.children});

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
