import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:verinni_os/core/services/frota_service.dart';
import 'package:verinni_os/core/theme/app_theme.dart';
import 'package:verinni_os/shared/widgets/verinni_card.dart';

class FrotaScreen extends StatefulWidget {
  const FrotaScreen({super.key});

  @override
  State<FrotaScreen> createState() => _FrotaScreenState();
}

class _FrotaScreenState extends State<FrotaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FrotaService>().loadVeiculos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FrotaService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gestão de Frota'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => svc.loadVeiculos(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddVehicleDialog(context),
            tooltip: 'Adicionar veículo',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: svc.loadVeiculos,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          slivers: [
            // Stats row
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'Total',
                        value: '${svc.totalVeiculos}',
                        icon: Icons.directions_car,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        label: 'Ativos',
                        value: '${svc.veiculosAtivos}',
                        icon: Icons.check_circle_outline,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        label: 'Manutenção',
                        value: '${svc.veiculosManutencao}',
                        icon: Icons.build_outlined,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // List
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: svc.isLoading
                  ? const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    )
                  : svc.veiculos.isEmpty
                      ? SliverFillRemaining(
                          child: EmptyState(
                            icon: Icons.directions_car_outlined,
                            title: 'Nenhum veículo',
                            subtitle:
                                'Adicione veículos à frota usando o botão +',
                            actionLabel: 'Adicionar Veículo',
                            onAction: () => _showAddVehicleDialog(context),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final v = svc.veiculos[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _VehicleCard(vehicle: v),
                              );
                            },
                            childCount: svc.veiculos.length,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVehicleDialog(BuildContext context) {
    final plateController = TextEditingController();
    final modelController = TextEditingController();
    final yearController = TextEditingController();
    String status = 'active';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Adicionar Veículo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: plateController,
                  decoration: const InputDecoration(
                    labelText: 'Placa *',
                    hintText: 'ABC-1234',
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelController,
                  decoration: const InputDecoration(
                    labelText: 'Modelo *',
                    hintText: 'Ex: Ford F-250 Diesel',
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearController,
                  decoration: const InputDecoration(
                    labelText: 'Ano',
                    hintText: '2023',
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  dropdownColor: AppColors.surfaceElevated,
                  decoration: const InputDecoration(labelText: 'Status'),
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (v) => setDialogState(() => status = v!),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Ativo')),
                    DropdownMenuItem(
                        value: 'maintenance', child: Text('Manutenção')),
                    DropdownMenuItem(
                        value: 'inactive', child: Text('Inativo')),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (plateController.text.isEmpty ||
                    modelController.text.isEmpty) {
                  return;
                }
                final svc = context.read<FrotaService>();
                final error = await svc.addVeiculo({
                  'plate': plateController.text.trim().toUpperCase(),
                  'model': modelController.text.trim(),
                  'year': int.tryParse(yearController.text),
                  'status': status,
                  'created_at': DateTime.now().toIso8601String(),
                });
                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error ?? 'Veículo adicionado!'),
                    backgroundColor:
                        error != null ? AppColors.error : AppColors.success,
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return VerinniCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;

  const _VehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final status = vehicle['status'] as String? ?? 'active';
    final statusLabels = {
      'active': 'Ativo',
      'maintenance': 'Manutenção',
      'inactive': 'Inativo',
    };
    final km = vehicle['current_km'] ?? vehicle['mileage'];

    return VerinniCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _getVehicleIcon(vehicle['type'] ?? vehicle['tipo'] ?? ''),
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
                  vehicle['model'] ??
                      vehicle['modelo'] ??
                      vehicle['name'] ??
                      '--',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      vehicle['plate'] ??
                          vehicle['placa'] ??
                          '--',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    if (vehicle['year'] != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• ${vehicle['year']}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
                if (km != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${km.toString()} km',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
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

  IconData _getVehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'truck':
      case 'caminhao':
      case 'caminhão':
        return Icons.local_shipping;
      case 'van':
        return Icons.airport_shuttle;
      case 'motorcycle':
      case 'moto':
        return Icons.two_wheeler;
      default:
        return Icons.directions_car;
    }
  }
}
