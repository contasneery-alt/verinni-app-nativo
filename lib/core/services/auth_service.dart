import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? _currentUser;
  Map<String, dynamic>? _profile;
  bool _isLoading = false;
  String? _lastError;

  User? get currentUser => _currentUser;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get isAuthenticated => _currentUser != null;

  String get userRole => _profile?['role'] ?? 'employee';
  String get userName =>
      _profile?['full_name'] ?? _currentUser?.email ?? 'Usuário';
  String? get userAvatar => _profile?['avatar_url'];

  AuthService() {
    _init();
  }

  void _init() {
    _currentUser = _supabase.auth.currentUser;
    if (_currentUser != null) {
      _loadProfile();
    }

    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn) {
        _currentUser = session?.user;
        _loadProfile();
      } else if (event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        _profile = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadProfile() async {
    if (_currentUser == null) return;
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', _currentUser!.id)
          .maybeSingle();
      _profile = response;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading profile: $e');
      }
    }
  }

  /// Login with email and password
  /// Returns null on success, error message string on failure
  Future<String?> signIn(String email, String password) async {
    _setLoading(true);
    _lastError = null;

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user != null) {
        _currentUser = response.user;
        await _loadProfile();
        _setLoading(false);
        return null; // success
      }

      _setLoading(false);
      return 'Credenciais inválidas. Verifique seu e-mail e senha.';
    } on AuthException catch (e) {
      _lastError = e.message;
      _setLoading(false);

      // Map common errors to Portuguese
      final code = e.message.toLowerCase();
      if (code.contains('invalid login credentials') ||
          code.contains('invalid credentials')) {
        return 'E-mail ou senha incorretos.\n[AuthApiError: ${e.message}]';
      } else if (code.contains('email not confirmed')) {
        return 'E-mail não confirmado. Verifique sua caixa de entrada.\n[AuthApiError: ${e.message}]';
      } else if (code.contains('too many requests')) {
        return 'Muitas tentativas. Aguarde alguns minutos.\n[AuthApiError: ${e.message}]';
      } else if (code.contains('network') || code.contains('connection')) {
        return 'Erro de conexão. Verifique sua internet.\n[NetworkError: ${e.message}]';
      }
      return 'Erro de autenticação: ${e.message}\n[AuthApiError: ${e.statusCode}]';
    } catch (e) {
      _lastError = e.toString();
      _setLoading(false);
      return 'Erro inesperado: $e\n[UnknownError]';
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _currentUser = null;
    _profile = null;
    notifyListeners();
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
      return null;
    } on AuthException catch (e) {
      return 'Erro: ${e.message}';
    } catch (e) {
      return 'Erro ao enviar e-mail de recuperação.';
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
