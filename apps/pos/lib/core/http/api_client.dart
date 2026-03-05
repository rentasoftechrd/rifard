import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _storageKey = 'rifard_access_token';
const _baseUrlKey = 'rifard_base_url';

/// URL por defecto del backend (VPS). Si el usuario no guardó ninguna, se usa esta.
const kDefaultBaseUrl = 'http://187.124.81.201:3000';

/// En debug puedes forzar la URL con: flutter run --dart-define=API_URL=http://localhost:3000
String? get _envApiUrl {
  const url = String.fromEnvironment('API_URL', defaultValue: '');
  return url.isEmpty ? null : url;
}

class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<String?> get baseUrl async {
    final env = _envApiUrl;
    if (env != null && env.isNotEmpty) return env;
    final url = await _storage.read(key: _baseUrlKey);
    return (url == null || url.trim().isEmpty) ? null : url.trim();
  }

  /// URL efectiva: dart-define > guardada en login > por defecto. Nunca devuelve null ni vacía.
  Future<String> get effectiveBaseUrl async {
    final url = await baseUrl;
    return (url != null && url.isNotEmpty) ? url : kDefaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final v = url.trim();
    if (v.isEmpty) {
      await _storage.delete(key: _baseUrlKey);
    } else {
      await _storage.write(key: _baseUrlKey, value: v);
    }
  }

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
    final base = await effectiveBaseUrl;
    final uri = Uri.parse('$base/api/v1$path').replace(queryParameters: queryParams);
    return _client.get(uri, headers: await _headers());
  }

  Future<http.Response> post(String path, {Object? body}) async {
    final base = await effectiveBaseUrl;
    final uri = Uri.parse('$base/api/v1$path');
    return _client.post(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
  }

  Future<http.Response> put(String path, {Object? body}) async {
    final base = await effectiveBaseUrl;
    final uri = Uri.parse('$base/api/v1$path');
    return _client.put(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
  }

  Future<bool> get isLoggedIn async => (await token) != null;
}
