import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages `employees` and `employee_functions`.
/// NOTE: employees has NO email, NO cpf, NO password.
/// Authentication lives exclusively in auth.users + profiles + user_roles.
///
/// Real employees columns: id, name, function_id, is_active,
/// has_ticket_card, epi_camisa, epi_calca, epi_blusao, epi_botina,
/// epi_luvas, epi_protetor_auricular, epi_concha, created_at, updated_at
class EmployeeService extends ChangeNotifier {
  final SupabaseClient _db = Supabase.instance.client;

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _functions = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get employees => _employees;
  List<Map<String, dynamic>> get functions => _functions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get total => _employees.length;
  int get active =>
      _employees.where((e) => e['is_active'] == true).length;

  Future<void> loadEmployees() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _db
          .from('employees')
          .select('*, employee_functions(id, name)')
          .order('name');
      _employees = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) debugPrint('[EmployeeService] loadEmployees: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadFunctions() async {
    try {
      final data = await _db
          .from('employee_functions')
          .select('id, name')
          .order('name');
      _functions = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[EmployeeService] loadFunctions: $e');
    }
  }

  Future<Map<String, dynamic>?> getEmployee(String id) async {
    try {
      return await _db
          .from('employees')
          .select('*, employee_functions(id, name)')
          .eq('id', id)
          .single();
    } catch (e) {
      return null;
    }
  }

  /// Daily attendance records
  Future<List<Map<String, dynamic>>> getDailyRecords(String date) async {
    try {
      final data = await _db
          .from('employee_daily_records')
          .select('*, employees(id, name)')
          .eq('record_date', date)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  String functionName(Map<String, dynamic> emp) {
    final fn = emp['employee_functions'];
    if (fn is Map) return fn['name']?.toString() ?? '--';
    return '--';
  }
}
