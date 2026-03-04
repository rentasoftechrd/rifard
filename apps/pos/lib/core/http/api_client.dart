import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _storageKey = 'rifard_access_token';
const _baseUrlKey = 'rifard_base_url';

class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<String?> get baseUrl async => _storage.read(key: _baseUrlKey);
  Future<void> setBaseUrl(String url) => _storage.write(key: _baseUrlKey, value: url);

  Future<String?> get token async => _storage.read(key: _storageKey);
  Future<void> setToken(String? t) async {
    if (t == null) {
      await _storage.delete(key: _storageKey);
    } else {
      await _storage.write(key: _storageKey, value: t);
    }
  }

  Future<Map<String, String>> _headers() async {
    final t = await token;
    final headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (t != null) headers['Authorization'] = 'Bearer $t';
    return headers;
  }

  Future<http.Response> get(String path, {Map<String, String>? queryParams}) async {
    final base = await baseUrl ?? 'http://localhost:3000';
    final uri = Uri.parse('$base/api/v1$path').replace(queryParameters: queryParams);
    return _client.get(uri, headers: await _headers());
  }

  Future<http.Response> post(String path, {Object? body}) async {
    final base = await baseUrl ?? 'http://localhost:3000';
    final uri = Uri.parse('$base/api/v1$path');
    return _client.post(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
  }

  Future<http.Response> put(String path, {Object? body}) async {
    final base = await baseUrl ?? 'http://localhost:3000';
    final uri = Uri.parse('$base/api/v1$path');
    return _client.put(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
  }

  Future<bool> get isLoggedIn async => (await token) != null;
}
