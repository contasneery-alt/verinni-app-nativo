import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrcamentoService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _orcamentos = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get orcamentos => _orcamentos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadOrcamentos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try common table names for quotes/budgets
      final data = await _supabase
          .from('orcamentos')
          .select('*')
          .order('created_at', ascending: false);
      _orcamentos = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) debugPrint('Error loading orcamentos: $e');
      _orcamentos = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getOrcamento(String id) async {
    try {
      final data = await _supabase
          .from('orcamentos')
          .select('*')
          .eq('id', id)
          .single();
      return data;
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching orcamento $id: $e');
      return null;
    }
  }

  Future<String?> createOrcamento(Map<String, dynamic> data) async {
    try {
      await _supabase.from('orcamentos').insert(data);
      await loadOrcamentos();
      return null;
    } catch (e) {
      return 'Erro ao criar orçamento: $e';
    }
  }

  Future<String?> updateOrcamento(
      String id, Map<String, dynamic> data) async {
    try {
      await _supabase.from('orcamentos').update(data).eq('id', id);
      await loadOrcamentos();
      return null;
    } catch (e) {
      return 'Erro ao atualizar orçamento: $e';
    }
  }

  Future<String?> updateStatus(String id, String status) async {
    return updateOrcamento(id, {'status': status});
  }

  String getStatusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Pendente';
      case 'approved':
        return 'Aprovado';
      case 'in_progress':
        return 'Em Andamento';
      case 'completed':
        return 'Concluído';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status ?? 'Desconhecido';
    }
  }
}
