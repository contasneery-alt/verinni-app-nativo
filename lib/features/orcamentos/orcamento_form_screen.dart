import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:verinni_os/core/services/auth_service.dart';
import 'package:verinni_os/core/services/orcamento_service.dart';
import 'package:verinni_os/core/theme/app_theme.dart';
import 'package:verinni_os/shared/widgets/verinni_card.dart';

class OrcamentoFormScreen extends StatefulWidget {
  const OrcamentoFormScreen({super.key});

  @override
  State<OrcamentoFormScreen> createState() => _OrcamentoFormScreenState();
}

class _OrcamentoFormScreenState extends State<OrcamentoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientEmailController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _servicesController = TextEditingController();
  final _notesController = TextEditingController();
  final _totalController = TextEditingController();
  bool _isLoading = false;
  String _status = 'pending';

  @override
  void dispose() {
    _titleController.dispose();
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _clientPhoneController.dispose();
    _servicesController.dispose();
    _notesController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final auth = context.read<AuthService>();
    final svc = context.read<OrcamentoService>();

    final data = {
      'id': const Uuid().v4(),
      'title': _titleController.text.trim(),
      'client_name': _clientNameController.text.trim(),
      'client_email': _clientEmailController.text.trim(),
      'client_phone': _clientPhoneController.text.trim(),
      'services': _servicesController.text.trim(),
      'notes': _notesController.text.trim(),
      'total_value': double.tryParse(
              _totalController.text.replaceAll(',', '.')) ??
          0.0,
      'status': _status,
      'created_by': auth.currentUser?.id,
      'created_at': DateTime.now().toIso8601String(),
    };

    final error = await svc.createOrcamento(data);

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
              _FormSection(
                title: 'Identificação',
                children: [
                  _buildField(
                    controller: _titleController,
                    label: 'Título do Orçamento *',
                    hint: 'Ex: Revisão Completa - Ford F-250',
                    validator: (v) =>
                        v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _FormSection(
                title: 'Dados do Cliente',
                children: [
                  _buildField(
                    controller: _clientNameController,
                    label: 'Nome do Cliente *',
                    hint: 'Nome completo ou razão social',
                    validator: (v) =>
                        v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _clientEmailController,
                    label: 'E-mail',
                    hint: 'cliente@email.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _clientPhoneController,
                    label: 'Telefone',
                    hint: '(00) 00000-0000',
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _FormSection(
                title: 'Detalhes do Serviço',
                children: [
                  _buildField(
                    controller: _servicesController,
                    label: 'Serviços *',
                    hint: 'Descreva os serviços a serem realizados...',
                    maxLines: 4,
                    validator: (v) =>
                        v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _notesController,
                    label: 'Observações',
                    hint: 'Informações adicionais...',
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _FormSection(
                title: 'Financeiro',
                children: [
                  _buildField(
                    controller: _totalController,
                    label: 'Valor Total (R\$) *',
                    hint: '0,00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v!.isEmpty) return 'Campo obrigatório';
                      if (double.tryParse(v.replaceAll(',', '.')) == null) {
                        return 'Valor inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    onChanged: (v) => setState(() => _status = v!),
                    style: const TextStyle(color: AppColors.textPrimary),
                    dropdownColor: AppColors.surfaceElevated,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('Pendente')),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
