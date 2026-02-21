import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FrotaService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _veiculos = [];
  List<Map<String, dynamic>> _manutencoes = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get veiculos => _veiculos;
  List<Map<String, dynamic>> get manutencoes => _manutencoes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalVeiculos => _veiculos.length;
  int get veiculosAtivos =>
      _veiculos.where((v) => v['status'] == 'active').length;
  int get veiculosManutencao =>
      _veiculos.where((v) => v['status'] == 'maintenance').length;

  Future<void> loadVeiculos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _supabase
          .from('vehicles')
          .select('*')
          .order('created_at', ascending: false);
      _veiculos = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) debugPrint('Error loading vehicles: $e');
      _veiculos = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadManutencoes() async {
    try {
      final data = await _supabase
          .from('vehicle_maintenances')
          .select('*')
          .order('date', ascending: false)
          .limit(20);
      _manutencoes = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading maintenances: $e');
    }
  }

  Future<String?> addVeiculo(Map<String, dynamic> data) async {
    try {
      await _supabase.from('vehicles').insert(data);
      await loadVeiculos();
      return null;
    } catch (e) {
      return 'Erro ao adicionar veículo: $e';
    }
  }

  Future<String?> updateVeiculo(String id, Map<String, dynamic> data) async {
    try {
      await _supabase.from('vehicles').update(data).eq('id', id);
      await loadVeiculos();
      return null;
    } catch (e) {
      return 'Erro ao atualizar veículo: $e';
    }
  }
}
