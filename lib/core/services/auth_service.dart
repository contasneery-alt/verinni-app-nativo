import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// UserPermissions maps the 35 boolean flags in the `user_permissions` table.
/// These are set EXCLUSIVELY by the Super Admin via the web dashboard.
/// The app NEVER writes to this table — only reads.
class UserPermissions {
  final bool canViewMaterials;
  final bool canEditMaterials;
  final bool canViewPurchases;
  final bool canEditPurchases;
  final bool canViewExits;
  final bool canEditExits;
  final bool canViewReports;
  final bool canViewUsers;
  final bool canEditUsers;
  final bool canViewFuel;
  final bool canEditFuel;
  final bool canViewEmployees;
  final bool canEditEmployees;
  final bool canViewServices;
  final bool canEditServices;
  final bool canViewConfig;
  final bool canViewSuppliers;
  final bool canCreateSuppliers;
  final bool canEditSuppliers;
  final bool canDeleteSuppliers;
  final bool canEditPurchaseDate;
  final bool canViewTools;
  final bool canEditTools;
  final bool canDeleteTools;
  final bool canRegisterToolExits;
  final bool canRegisterToolPurchases;
  final bool canRegisterToolReturns;
  final bool canViewToolReports;
  final bool canViewEpis;
  final bool canEditEpis;
  final bool canRegisterEpiPurchases;
  final bool canRegisterEpiExits;
  final bool canDeleteEpis;

  const UserPermissions({
    this.canViewMaterials = false,
    this.canEditMaterials = false,
    this.canViewPurchases = false,
    this.canEditPurchases = false,
    this.canViewExits = false,
    this.canEditExits = false,
    this.canViewReports = false,
    this.canViewUsers = false,
    this.canEditUsers = false,
    this.canViewFuel = false,
    this.canEditFuel = false,
    this.canViewEmployees = false,
    this.canEditEmployees = false,
    this.canViewServices = false,
    this.canEditServices = false,
    this.canViewConfig = false,
    this.canViewSuppliers = false,
    this.canCreateSuppliers = false,
    this.canEditSuppliers = false,
    this.canDeleteSuppliers = false,
    this.canEditPurchaseDate = false,
    this.canViewTools = false,
    this.canEditTools = false,
    this.canDeleteTools = false,
    this.canRegisterToolExits = false,
    this.canRegisterToolPurchases = false,
    this.canRegisterToolReturns = false,
    this.canViewToolReports = false,
    this.canViewEpis = false,
    this.canEditEpis = false,
    this.canRegisterEpiPurchases = false,
    this.canRegisterEpiExits = false,
    this.canDeleteEpis = false,
  });

  /// Super Admin gets all permissions automatically regardless of the table.
  const UserPermissions.superAdmin()
      : canViewMaterials = true,
        canEditMaterials = true,
        canViewPurchases = true,
        canEditPurchases = true,
        canViewExits = true,
        canEditExits = true,
        canViewReports = true,
        canViewUsers = true,
        canEditUsers = true,
        canViewFuel = true,
        canEditFuel = true,
        canViewEmployees = true,
        canEditEmployees = true,
        canViewServices = true,
        canEditServices = true,
        canViewConfig = true,
        canViewSuppliers = true,
        canCreateSuppliers = true,
        canEditSuppliers = true,
        canDeleteSuppliers = true,
        canEditPurchaseDate = true,
        canViewTools = true,
        canEditTools = true,
        canDeleteTools = true,
        canRegisterToolExits = true,
        canRegisterToolPurchases = true,
        canRegisterToolReturns = true,
        canViewToolReports = true,
        canViewEpis = true,
        canEditEpis = true,
        canRegisterEpiPurchases = true,
        canRegisterEpiExits = true,
        canDeleteEpis = true;

  factory UserPermissions.fromMap(Map<String, dynamic> m) {
    bool b(String key) => m[key] == true;
    return UserPermissions(
      canViewMaterials: b('can_view_materials'),
      canEditMaterials: b('can_edit_materials'),
      canViewPurchases: b('can_view_purchases'),
      canEditPurchases: b('can_edit_purchases'),
      canViewExits: b('can_view_exits'),
      canEditExits: b('can_edit_exits'),
      canViewReports: b('can_view_reports'),
      canViewUsers: b('can_view_users'),
      canEditUsers: b('can_edit_users'),
      canViewFuel: b('can_view_fuel'),
      canEditFuel: b('can_edit_fuel'),
      canViewEmployees: b('can_view_employees'),
      canEditEmployees: b('can_edit_employees'),
      canViewServices: b('can_view_services'),
      canEditServices: b('can_edit_services'),
      canViewConfig: b('can_view_config'),
      canViewSuppliers: b('can_view_suppliers'),
      canCreateSuppliers: b('can_create_suppliers'),
      canEditSuppliers: b('can_edit_suppliers'),
      canDeleteSuppliers: b('can_delete_suppliers'),
      canEditPurchaseDate: b('can_edit_purchase_date'),
      canViewTools: b('can_view_tools'),
      canEditTools: b('can_edit_tools'),
      canDeleteTools: b('can_delete_tools'),
      canRegisterToolExits: b('can_register_tool_exits'),
      canRegisterToolPurchases: b('can_register_tool_purchases'),
      canRegisterToolReturns: b('can_register_tool_returns'),
      canViewToolReports: b('can_view_tool_reports'),
      canViewEpis: b('can_view_epis'),
      canEditEpis: b('can_edit_epis'),
      canRegisterEpiPurchases: b('can_register_epi_purchases'),
      canRegisterEpiExits: b('can_register_epi_exits'),
      canDeleteEpis: b('can_delete_epis'),
    );
  }
}

/// AuthService handles authentication and privilege resolution.
///
/// SECURITY GUARANTEE:
/// ─────────────────────────────────────────────────────────────────
/// 1. Identity = Supabase auth.users (email + password).
///    The `employees` table has NO email column and is NEVER used
///    for login validation.
///
/// 2. Role = user_roles.role (set by Super Admin, read-only in app).
///    Possible values observed: 'super_admin', 'admin', 'user', etc.
///
/// 3. Permissions = user_permissions (37 boolean flags, read-only).
///    Super Admin role bypasses the table entirely — full access.
///
/// 4. CPF (if ever added to employees or profiles) is IGNORED by
///    this service. It does not change roles, permissions or session.
/// ─────────────────────────────────────────────────────────────────
class AuthService extends ChangeNotifier {
  final SupabaseClient _db = Supabase.instance.client;

  // ── State ────────────────────────────────────────────────────────
  User? _user;
  Map<String, dynamic>? _profile; // from `profiles` table
  String _role = 'user'; // from `user_roles` table
  UserPermissions _permissions = const UserPermissions();
  bool _isLoading = false;
  String? _lastError;

  // ── Getters ──────────────────────────────────────────────────────
  User? get currentUser => _user;
  Map<String, dynamic>? get profile => _profile;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  /// Role comes from user_roles.role — never from employees or CPF
  String get role => _role;
  bool get isSuperAdmin => _role == 'super_admin';
  bool get isAdmin => _role == 'super_admin' || _role == 'admin';

  /// Permissions: Super Admin gets all; others get from user_permissions table
  UserPermissions get permissions =>
      isSuperAdmin ? const UserPermissions.superAdmin() : _permissions;

  /// Display name from profiles.name, falling back to email local-part
  String get userName {
    final n = _profile?['name'];
    if (n != null && n.toString().trim().isNotEmpty) return n.toString().trim();
    return _user?.email?.split('@').first ?? 'Usuário';
  }

  String get userEmail => _profile?['email'] ?? _user?.email ?? '';
  String? get userAvatar => _profile?['avatar_url'];
  String get userSetor => _profile?['setor'] ?? '';
  String get roleLabel {
    switch (_role) {
      case 'super_admin':
        return 'Super Admin';
      case 'admin':
        return 'Administrador';
      case 'manager':
        return 'Gestor';
      default:
        return 'Usuário';
    }
  }

  // ── Constructor ──────────────────────────────────────────────────
  AuthService() {
    _user = _db.auth.currentUser;
    if (_user != null) _loadUserData();

    _db.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
          _user = data.session?.user;
          _loadUserData();
          break;
        case AuthChangeEvent.signedOut:
        case AuthChangeEvent.userDeleted:
          _clearState();
          break;
        case AuthChangeEvent.tokenRefreshed:
          _user = data.session?.user;
          break;
        default:
          break;
      }
      notifyListeners();
    });
  }

  // ── Internal loaders ─────────────────────────────────────────────

  Future<void> _loadUserData() async {
    if (_user == null) return;
    await Future.wait([
      _loadProfile(),
      _loadRole(),
    ]);
    // Load permissions only after role is known (super_admin skips it)
    if (!isSuperAdmin) await _loadPermissions();
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    try {
      // profiles.user_id references auth.users.id
      final row = await _db
          .from('profiles')
          .select('id, user_id, name, email, avatar_url, setor, status')
          .eq('user_id', _user!.id)
          .maybeSingle();
      _profile = row;
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] _loadProfile error: $e');
    }
  }

  Future<void> _loadRole() async {
    try {
      // user_roles.user_id references auth.users.id
      final row = await _db
          .from('user_roles')
          .select('role')
          .eq('user_id', _user!.id)
          .maybeSingle();
      _role = row?['role']?.toString() ?? 'user';
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] _loadRole error: $e');
      _role = 'user';
    }
  }

  Future<void> _loadPermissions() async {
    try {
      // user_permissions.user_id references auth.users.id
      final row = await _db
          .from('user_permissions')
          .select('*')
          .eq('user_id', _user!.id)
          .maybeSingle();
      _permissions = row != null
          ? UserPermissions.fromMap(row)
          : const UserPermissions();
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] _loadPermissions error: $e');
      _permissions = const UserPermissions();
    }
  }

  void _clearState() {
    _user = null;
    _profile = null;
    _role = 'user';
    _permissions = const UserPermissions();
    _lastError = null;
  }

  // ── Public API ───────────────────────────────────────────────────

  /// Sign in with email + password.
  /// Returns null on success, or a human-readable error string (with debug
  /// code appended in brackets) on failure.
  Future<String?> signIn(String email, String password) async {
    _setLoading(true);
    _lastError = null;

    try {
      final res = await _db.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      if (res.user != null) {
        _user = res.user;
        await _loadUserData();
        _setLoading(false);
        return null; // ✅ success
      }

      _setLoading(false);
      return 'Credenciais inválidas. Verifique seu e-mail e senha.';
    } on AuthException catch (e) {
      _lastError = e.message;
      _setLoading(false);
      return _mapAuthError(e);
    } catch (e) {
      _lastError = e.toString();
      _setLoading(false);
      return 'Erro inesperado: $e\n[UnknownError]';
    }
  }

  Future<void> signOut() async {
    await _db.auth.signOut();
    _clearState();
    notifyListeners();
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _db.auth.resetPasswordForEmail(email.trim().toLowerCase());
      return null;
    } on AuthException catch (e) {
      return 'Erro: ${e.message}\n[AuthApiError: ${e.statusCode}]';
    } catch (e) {
      return 'Erro ao enviar e-mail de recuperação.';
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  /// Maps Supabase auth errors to pt-BR messages with debug codes.
  String _mapAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials') ||
        msg.contains('wrong password')) {
      return 'E-mail ou senha incorretos.\n[AuthApiError: ${e.message}]';
    }
    if (msg.contains('email not confirmed')) {
      return 'E-mail não confirmado. Verifique sua caixa de entrada.\n[AuthApiError: ${e.message}]';
    }
    if (msg.contains('too many requests') || msg.contains('rate limit')) {
      return 'Muitas tentativas. Aguarde alguns minutos.\n[AuthApiError: ${e.message}]';
    }
    if (msg.contains('user not found') || msg.contains('no user found')) {
      return 'Usuário não encontrado. Verifique o e-mail informado.\n[AuthApiError: ${e.message}]';
    }
    if (msg.contains('network') || msg.contains('connection') ||
        msg.contains('socket')) {
      return 'Erro de conexão. Verifique sua internet.\n[NetworkError: ${e.message}]';
    }
    return 'Erro de autenticação.\n[AuthApiError: ${e.message} | status: ${e.statusCode}]';
  }
}
