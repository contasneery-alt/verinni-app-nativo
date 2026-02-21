import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:verinni_os/core/theme/app_theme.dart';
import 'package:verinni_os/core/utils/formatters.dart';
import 'package:verinni_os/shared/widgets/verinni_card.dart';

/// Frota — usa a tabela `vehicles` (real) com colunas:
/// id, name, license_plate, type, current_km, is_active,
/// created_at, updated_at
///
/// Tabela `fuel_records` (real) com colunas:
/// id, vehicle_id, liters, total_cost, km_before, km_after,
/// fuel_type, created_at
class FrotaScreen extends StatefulWidget {
  const FrotaScreen({super.key});

  @override
  State<FrotaScreen> createState() => _FrotaScreenState();
}

class _FrotaScreenState extends State<FrotaScreen>
    with SingleTickerProviderStateMixin {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _fuelRecords = [];
  bool _isLoading = true;
  late TabController _tabCtrl;

  // Computed counts
  int get _total => _vehicles.length;
  int get _ativos => _vehicles.where((v) => v['is_active'] == true).length;
  int get _inativos => _vehicles.where((v) => v['is_active'] == false).length;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadVehicles(), _loadFuelRecords()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadVehicles() async {
    try {
      final data = await _db
          .from('vehicles')
          .select('*')
          .order('created_at', ascending: false);
      _vehicles = List<Map<String, dynamic>>.from(data);
    } catch (_) {
      _vehicles = [];
    }
  }

  Future<void> _loadFuelRecords() async {
    try {
      final data = await _db
          .from('fuel_records')
          .select('*, vehicles(id, name, license_plate)')
          .order('created_at', ascending: false)
          .limit(30);
      _fuelRecords = List<Map<String, dynamic>>.from(data);
    } catch (_) {
      _fuelRecords = [];
    }
  }

  Future<void> _addVehicle(Map<String, dynamic> data) async {
    try {
      await _db.from('vehicles').insert(data);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veículo adicionado com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar veículo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleActive(String id, bool currentActive) async {
    try {
      await _db
          .from('vehicles')
          .update({
            'is_active': !currentActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
      await _loadVehicles();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
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
        title: const Text('Gestão de Frota'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
            tooltip: 'Atualizar',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddVehicleDialog(),
            tooltip: 'Adicionar veículo',
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: 'Veículos ($_total)'),
            Tab(text: 'Abastecimentos'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildVehiclesTab(),
                _buildFuelTab(),
              ],
            ),
    );
  }

  Widget _buildVehiclesTab() {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        slivers: [
          // Stats
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: _StatMini(
                      label: 'Total',
                      value: '$_total',
                      icon: Icons.directions_car,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatMini(
                      label: 'Ativos',
                      value: '$_ativos',
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatMini(
                      label: 'Inativos',
                      value: '$_inativos',
                      icon: Icons.block_outlined,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // List
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: _vehicles.isEmpty
                ? SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.directions_car_outlined,
                      title: 'Nenhum veículo',
                      subtitle: 'Adicione veículos à frota usando o botão +',
                      actionLabel: 'Adicionar Veículo',
                      onAction: _showAddVehicleDialog,
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _VehicleCard(
                          vehicle: _vehicles[i],
                          onToggleActive: _toggleActive,
                        ),
                      ),
                      childCount: _vehicles.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelTab() {
    if (_fuelRecords.isEmpty) {
      return const EmptyState(
        icon: Icons.local_gas_station_outlined,
        title: 'Sem registros',
        subtitle: 'Nenhum abastecimento registrado ainda.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFuelRecords,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _fuelRecords.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final r = _fuelRecords[i];
          final vehicle = r['vehicles'];
          final vehicleName = vehicle is Map
              ? '${vehicle['name'] ?? '--'} (${vehicle['license_plate'] ?? '--'})'
              : '--';
          final liters =
              double.tryParse(r['liters']?.toString() ?? '0') ?? 0;
          final cost =
              double.tryParse(r['total_cost']?.toString() ?? '0') ?? 0;
          final kmBefore =
              double.tryParse(r['km_before']?.toString() ?? '0') ?? 0;
          final kmAfter =
              double.tryParse(r['km_after']?.toString() ?? '0') ?? 0;
          final driven = kmAfter - kmBefore;

          return VerinniCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_gas_station,
                      color: AppColors.info, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleName,
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
                        '${liters.toStringAsFixed(1)} L${r['fuel_type'] != null ? ' • ${r['fuel_type']}' : ''}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                      if (driven > 0)
                        Text(
                          '${driven.toStringAsFixed(0)} km percorridos',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      Text(
                        AppFormatters.dateFromString(
                            r['created_at']?.toString()),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  AppFormatters.currency(cost),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddVehicleDialog() {
    final nameCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final kmCtrl = TextEditingController();
    String type = 'car';
    bool isActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Adicionar Veículo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome / Modelo *',
                    hintText: 'Ex: Ford F-250 Diesel',
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: plateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Placa *',
                    hintText: 'ABC-1D23',
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: kmCtrl,
                  decoration: const InputDecoration(
                    labelText: 'KM Atual',
                    hintText: '0',
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  dropdownColor: AppColors.surfaceElevated,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (v) => setDlg(() => type = v!),
                  items: const [
                    DropdownMenuItem(value: 'car', child: Text('Carro')),
                    DropdownMenuItem(value: 'truck', child: Text('Caminhão')),
                    DropdownMenuItem(value: 'van', child: Text('Van')),
                    DropdownMenuItem(
                        value: 'motorcycle', child: Text('Moto')),
                    DropdownMenuItem(value: 'other', child: Text('Outro')),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Ativo',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  value: isActive,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setDlg(() => isActive = v),
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
              onPressed: () {
                if (nameCtrl.text.isEmpty || plateCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                _addVehicle({
                  'name': nameCtrl.text.trim(),
                  'license_plate': plateCtrl.text.trim().toUpperCase(),
                  'type': type,
                  'current_km': int.tryParse(kmCtrl.text) ?? 0,
                  'is_active': isActive,
                });
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatMini({
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
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final Future<void> Function(String id, bool currentActive) onToggleActive;

  const _VehicleCard({required this.vehicle, required this.onToggleActive});

  @override
  Widget build(BuildContext context) {
    final isActive = vehicle['is_active'] == true;
    final name = vehicle['name']?.toString() ?? '--';
    final plate = vehicle['license_plate']?.toString() ?? '--';
    final type = vehicle['type']?.toString() ?? '';
    final km = vehicle['current_km'];
    final id = vehicle['id']?.toString() ?? '';

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
              _typeIcon(type),
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
                  name,
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
                      plate,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    if (type.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• ${_typeLabel(type)}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                if (km != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.speed_outlined,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '$km km',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isActive ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isActive ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isActive ? 'Ativo' : 'Inativo',
                  style: TextStyle(
                    color: isActive ? AppColors.success : AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => onToggleActive(id, isActive),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isActive ? Icons.toggle_on : Icons.toggle_off,
                    color: isActive
                        ? AppColors.success
                        : AppColors.textMuted,
                    size: 28,
                    semanticLabel: isActive ? 'Desativar' : 'Ativar',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'truck':
      case 'caminhao':
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

  String _typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'car':
        return 'Carro';
      case 'truck':
        return 'Caminhão';
      case 'van':
        return 'Van';
      case 'motorcycle':
        return 'Moto';
      default:
        return type;
    }
  }
}
