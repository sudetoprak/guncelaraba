import 'package:flutter/foundation.dart';
import 'models/models.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final _service = AuthService();

  User? _user;
  bool _isLoading = true;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final token = await _service.getAccessToken();
      if (token != null) {
        _user = await _service.me();
      }
    } catch (_) {
      await _service.clearTokens();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    final tokens = await _service.login(email, password);
    await _service.saveTokens(tokens);
    _user = await _service.me();
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final tokens = await _service.register(
      email: email,
      username: username,
      password: password,
      fullName: fullName,
      phone: phone,
    );
    await _service.saveTokens(tokens);
    _user = await _service.me();
    notifyListeners();
  }

  Future<void> logout() async {
    await _service.clearTokens();
    _user = null;
    notifyListeners();
  }
}
