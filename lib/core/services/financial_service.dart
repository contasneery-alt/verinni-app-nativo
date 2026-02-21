import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages `financial_transactions`.
/// Real columns: id, type (income/expense), category, description,
/// amount, due_date, paid_date, status, client_id, supplier_id,
/// order_id, purchase_id, notes, created_by, created_at, updated_at
class FinancialService extends ChangeNotifier {
  final SupabaseClient _db = Supabase.instance.client;

  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = false;
  String? _error;
  Map<String, double> _summary = {};

  List<Map<String, dynamic>> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalIncome => _summary['income'] ?? 0;
  double get totalExpense => _summary['expense'] ?? 0;
  double get balance => totalIncome - totalExpense;

  double get pendingAmount =>
      _transactions
          .where((t) => t['status'] == 'pending')
          .fold(0.0, (s, t) => s + _amount(t));

  Future<void> loadTransactions({
    String? type,
    String? status,
    int limit = 50,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      dynamic q = _db
          .from('financial_transactions')
          .select('*, clients(id, name), suppliers(id, name)');

      if (type != null) {
        final data = await q
            .eq('type', type)
            .order('due_date', ascending: false)
            .limit(limit);
        _transactions = List<Map<String, dynamic>>.from(data);
      } else if (status != null) {
        final data = await q
            .eq('status', status)
            .order('due_date', ascending: false)
            .limit(limit);
        _transactions = List<Map<String, dynamic>>.from(data);
      } else {
        final data = await q
            .order('due_date', ascending: false)
            .limit(limit);
        _transactions = List<Map<String, dynamic>>.from(data);
      }

      _computeSummary();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) debugPrint('[FinancialService] loadTransactions: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getMonthlyRevenue() async {
    try {
      final now = DateTime.now();
      final sixMonthsAgo =
          DateTime(now.year, now.month - 5, 1).toIso8601String();
      final data = await _db
          .from('financial_transactions')
          .select('amount, type, paid_date, created_at')
          .eq('type', 'income')
          .eq('status', 'paid')
          .gte('paid_date', sixMonthsAgo)
          .order('paid_date');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[FinancialService] getMonthlyRevenue: $e');
      return [];
    }
  }

  /// Summary for a specific period
  Future<Map<String, double>> getPeriodSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final data = await _db
          .from('financial_transactions')
          .select('type, amount, status')
          .gte('due_date', from.toIso8601String())
          .lte('due_date', to.toIso8601String());

      double income = 0;
      double expense = 0;
      for (final t in data) {
        final a = _amount(t);
        if (t['type'] == 'income') income += a;
        if (t['type'] == 'expense') expense += a;
      }
      return {'income': income, 'expense': expense};
    } catch (e) {
      return {'income': 0, 'expense': 0};
    }
  }

  Future<String?> createTransaction(Map<String, dynamic> data) async {
    try {
      await _db.from('financial_transactions').insert({
        ...data,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await loadTransactions();
      return null;
    } catch (e) {
      return 'Erro ao criar transação: $e';
    }
  }

  Future<String?> markAsPaid(String id, DateTime? paidDate) async {
    try {
      await _db.from('financial_transactions').update({
        'status': 'paid',
        'paid_date': (paidDate ?? DateTime.now()).toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      await loadTransactions();
      return null;
    } catch (e) {
      return 'Erro ao marcar como pago: $e';
    }
  }

  // ── Private ──────────────────────────────────────────────────────

  void _computeSummary() {
    double income = 0;
    double expense = 0;
    for (final t in _transactions) {
      final a = _amount(t);
      if (t['type'] == 'income') income += a;
      if (t['type'] == 'expense') expense += a;
    }
    _summary = {'income': income, 'expense': expense};
  }

  double _amount(Map<String, dynamic> t) =>
      double.tryParse(t['amount']?.toString() ?? '0') ?? 0;

  // ── Helpers ──────────────────────────────────────────────────────

  String statusLabel(String? s) {
    switch (s) {
      case 'pending':   return 'Pendente';
      case 'paid':      return 'Pago';
      case 'overdue':   return 'Vencido';
      case 'cancelled': return 'Cancelado';
      default:          return s ?? '--';
    }
  }

  String typeLabel(String? t) {
    switch (t) {
      case 'income':  return 'Receita';
      case 'expense': return 'Despesa';
      default:        return t ?? '--';
    }
  }
}
