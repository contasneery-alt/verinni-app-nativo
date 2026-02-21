import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages the `orders` table — production orders.
/// Real columns: id, order_number, client_id, budget_id, status,
/// production_type, health, data_venda, data_entrega_prevista,
/// data_entrega_real, vendedor_id, current_responsible_id,
/// valor_venda, custo_materiais, observacoes, created_at, updated_at
class OrderService extends ChangeNotifier {
  final SupabaseClient _db = Supabase.instance.client;

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Status grouping helpers ──────────────────────────────────────

  List<Map<String, dynamic>> get pending =>
      _orders.where((o) => o['status'] == 'pending').toList();
  List<Map<String, dynamic>> get inProgress =>
      _orders.where((o) => o['status'] == 'in_progress').toList();
  List<Map<String, dynamic>> get completed =>
      _orders.where((o) => o['status'] == 'completed').toList();

  // ── CRUD ─────────────────────────────────────────────────────────

  Future<void> loadOrders({String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      var query = _db
          .from('orders')
          .select('*, clients(id, name, phone)');
      if (status != null) {
        final data = await query
            .eq('status', status)
            .order('created_at', ascending: false);
        _orders = List<Map<String, dynamic>>.from(data);
      } else {
        final data =
            await query.order('created_at', ascending: false);
        _orders = List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) debugPrint('[OrderService] loadOrders: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getOrder(String id) async {
    try {
      return await _db
          .from('orders')
          .select('*, clients(id, name, email, phone, cnpj)')
          .eq('id', id)
          .single();
    } catch (e) {
      if (kDebugMode) debugPrint('[OrderService] getOrder $id: $e');
      return null;
    }
  }

  Future<String?> updateStatus(String id, String status) async {
    try {
      await _db.from('orders').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
        if (status == 'completed')
          'data_entrega_real': DateTime.now().toIso8601String(),
      }).eq('id', id);
      await loadOrders();
      return null;
    } catch (e) {
      return 'Erro ao atualizar status: $e';
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  String statusLabel(String? s) {
    switch (s) {
      case 'pending':       return 'Aguardando';
      case 'in_progress':   return 'Em Produção';
      case 'completed':     return 'Entregue';
      case 'cancelled':     return 'Cancelado';
      case 'paused':        return 'Pausado';
      case 'waiting_parts': return 'Aguard. Peças';
      default:              return s ?? '--';
    }
  }

  String healthLabel(String? h) {
    switch (h) {
      case 'green':  return 'No prazo';
      case 'yellow': return 'Atenção';
      case 'red':    return 'Atrasado';
      default:       return h ?? '--';
    }
  }
}
