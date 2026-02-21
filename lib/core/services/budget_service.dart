import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages the `budgets` table (formerly "orcamentos" in the old code).
/// Real columns: id, budget_number, client_id, status, vendedor_id,
/// parceiro_id, valor_original, valor_venda, desconto, validade,
/// observacoes, created_by, created_at, updated_at
class BudgetService extends ChangeNotifier {
  final SupabaseClient _db = Supabase.instance.client;

  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get budgets => _budgets;
  List<Map<String, dynamic>> get clients => _clients;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Budgets ─────────────────────────────────────────────────────

  Future<void> loadBudgets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _db
          .from('budgets')
          .select('*, clients(id, name, email, phone, cnpj)')
          .order('created_at', ascending: false);
      _budgets = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) debugPrint('[BudgetService] loadBudgets: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getBudget(String id) async {
    try {
      return await _db
          .from('budgets')
          .select('*, clients(id, name, email, phone, cnpj, city, state, address)')
          .eq('id', id)
          .single();
    } catch (e) {
      if (kDebugMode) debugPrint('[BudgetService] getBudget $id: $e');
      return null;
    }
  }

  Future<String?> createBudget(Map<String, dynamic> data) async {
    try {
      await _db.from('budgets').insert(data);
      await loadBudgets();
      return null;
    } catch (e) {
      return 'Erro ao criar orçamento: $e';
    }
  }

  Future<String?> updateBudget(String id, Map<String, dynamic> data) async {
    try {
      await _db
          .from('budgets')
          .update({...data, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      await loadBudgets();
      return null;
    } catch (e) {
      return 'Erro ao atualizar orçamento: $e';
    }
  }

  Future<String?> updateStatus(String id, String status) async {
    return updateBudget(id, {'status': status});
  }

  // ── Clients (used in budget forms) ──────────────────────────────

  Future<void> loadClients() async {
    try {
      final data = await _db
          .from('clients')
          .select('id, name, email, phone, cnpj, city, state')
          .order('name');
      _clients = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[BudgetService] loadClients: $e');
    }
  }

  // ── Orders linked to a budget ────────────────────────────────────

  Future<List<Map<String, dynamic>>> getOrdersForBudget(
      String budgetId) async {
    try {
      final data = await _db
          .from('orders')
          .select('*')
          .eq('budget_id', budgetId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  String statusLabel(String? s) {
    switch (s) {
      case 'pending':      return 'Pendente';
      case 'approved':     return 'Aprovado';
      case 'in_progress':  return 'Em Andamento';
      case 'completed':    return 'Concluído';
      case 'cancelled':    return 'Cancelado';
      case 'draft':        return 'Rascunho';
      case 'sent':         return 'Enviado';
      case 'negotiating':  return 'Negociando';
      default:             return s ?? 'Desconhecido';
    }
  }
}
