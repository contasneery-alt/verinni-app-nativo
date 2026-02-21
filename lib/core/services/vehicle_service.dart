import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages `vehicles`, `fuel_records` and `vehicle_daily_trips`.
/// Real vehicles columns: id, name, license_plate, type, year,
/// original_km, current_km, tank_capacity, current_driver_id,
/// current_driver_name, is_active, current_service_id,
/// current_service_name, created_at, updated_at
class VehicleService extends ChangeNotifier {
  final SupabaseClient _db = Supabase.instance.client;

  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _fuelRecords = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get vehicles => _vehicles;
  List<Map<String, dynamic>> get fuelRecords => _fuelRecords;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get total => _vehicles.length;
  int get active => _vehicles.where((v) => v['is_active'] == true).length;
  int get inactive => _vehicles.where((v) => v['is_active'] == false).length;

  // ── Vehicles ─────────────────────────────────────────────────────

  Future<void> loadVehicles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _db
          .from('vehicles')
          .select('*')
          .order('name');
      _vehicles = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) debugPrint('[VehicleService] loadVehicles: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getVehicle(String id) async {
    try {
      return await _db.from('vehicles').select('*').eq('id', id).single();
    } catch (e) {
      return null;
    }
  }

  Future<String?> addVehicle(Map<String, dynamic> data) async {
    try {
      await _db.from('vehicles').insert({
        ...data,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await loadVehicles();
      return null;
    } catch (e) {
      return 'Erro ao adicionar veículo: $e';
    }
  }

  Future<String?> updateVehicle(String id, Map<String, dynamic> data) async {
    try {
      await _db.from('vehicles').update({
        ...data,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      await loadVehicles();
      return null;
    } catch (e) {
      return 'Erro ao atualizar veículo: $e';
    }
  }

  // ── Fuel Records ─────────────────────────────────────────────────
  /// Real columns: vehicle_id, refuel_date, fuel_type, liters,
  /// price_per_liter, total_cost, km_before, km_after,
  /// is_full_tank, user_id, user_name, observations

  Future<void> loadFuelRecords({String? vehicleId}) async {
    try {
      dynamic query = _db
          .from('fuel_records')
          .select('*, vehicles(id, name, license_plate)');
      if (vehicleId != null) {
        final data = await query
            .eq('vehicle_id', vehicleId)
            .order('refuel_date', ascending: false)
            .limit(50);
        _fuelRecords = List<Map<String, dynamic>>.from(data);
      } else {
        final data = await query
            .order('refuel_date', ascending: false)
            .limit(50);
        _fuelRecords = List<Map<String, dynamic>>.from(data);
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[VehicleService] loadFuelRecords: $e');
    }
  }

  Future<String?> addFuelRecord(Map<String, dynamic> data) async {
    try {
      await _db.from('fuel_records').insert({
        ...data,
        'created_at': DateTime.now().toIso8601String(),
      });
      // Update vehicle current_km if provided
      final kmAfter = data['km_after'];
      final vehicleId = data['vehicle_id'];
      if (kmAfter != null && vehicleId != null) {
        await _db.from('vehicles').update({
          'current_km': kmAfter,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', vehicleId);
      }
      await loadVehicles();
      await loadFuelRecords(vehicleId: vehicleId?.toString());
      return null;
    } catch (e) {
      return 'Erro ao registrar abastecimento: $e';
    }
  }

  // ── Daily Trips ──────────────────────────────────────────────────
  /// Real columns: vehicle_id, trip_date, employee_id, employee_name,
  /// destination, origin, departure_time, return_time,
  /// km_departure, km_return, observations

  Future<List<Map<String, dynamic>>> getDailyTrips(String vehicleId) async {
    try {
      final data = await _db
          .from('vehicle_daily_trips')
          .select('*')
          .eq('vehicle_id', vehicleId)
          .order('trip_date', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  String typeLabel(String? t) {
    switch (t?.toLowerCase()) {
      case 'car':        return 'Carro';
      case 'truck':      return 'Caminhão';
      case 'van':        return 'Van';
      case 'motorcycle': return 'Moto';
      case 'pickup':     return 'Picape';
      default:           return t ?? 'Veículo';
    }
  }
}
