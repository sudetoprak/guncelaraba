import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/models/models.dart';
import 'api_client.dart';

class AuthService {
  final _dio = ApiClient().dio;
  final _storage = const FlutterSecureStorage();

  Future<TokenResponse> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    return TokenResponse.fromJson(res.data);
  }

  Future<TokenResponse> register({
    required String email,
    required String username,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final res = await _dio.post('/auth/register', data: {
      'email': email,
      'username': username,
      'password': password,
      'full_name': fullName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'language': 'tr',
    });
    return TokenResponse.fromJson(res.data);
  }

  Future<User> me() async {
    final res = await _dio.get('/auth/me');
    return User.fromJson(res.data);
  }

  Future<void> saveTokens(TokenResponse tokens) async {
    await _storage.write(key: 'access_token', value: tokens.accessToken);
    await _storage.write(key: 'refresh_token', value: tokens.refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<String?> getAccessToken() => _storage.read(key: 'access_token');
}
