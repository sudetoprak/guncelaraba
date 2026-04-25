import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String apiBaseUrl = 'http://100.114.176.17:8000/api/v1';
const String wsBaseUrl = 'ws://100.114.176.17:8000';
const String serverBaseUrl = 'http://100.114.176.17:8000';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      headers: {'Content-Type': 'application/json'},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          try {
            final refreshToken = await _storage.read(key: 'refresh_token');
            if (refreshToken == null) return handler.next(error);
            final res = await Dio().post('$apiBaseUrl/auth/refresh',
                data: {'refresh_token': refreshToken});
            final accessToken = res.data['access_token'];
            final newRefresh = res.data['refresh_token'];
            await _storage.write(key: 'access_token', value: accessToken);
            await _storage.write(key: 'refresh_token', value: newRefresh);
            error.requestOptions.headers['Authorization'] = 'Bearer $accessToken';
            final retryResponse = await dio.fetch(error.requestOptions);
            return handler.resolve(retryResponse);
          } catch (_) {
            await _storage.delete(key: 'access_token');
            await _storage.delete(key: 'refresh_token');
          }
        }
        handler.next(error);
      },
    ));
  }
}