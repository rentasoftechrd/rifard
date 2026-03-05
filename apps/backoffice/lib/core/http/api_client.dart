import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _storageKey = 'rifard_backoffice_token';

class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;
  // Compile: --dart-define=API_URL=http://localhost:3000
  static String get _defaultBaseUrl =>
      const String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000');
  String _baseUrl = _defaultBaseUrl;

  /// Cache del token en memoria para no leer storage en cada comprobación de auth.
  String? _cachedToken;
  bool _tokenRead = false;

  String get baseUrl => _baseUrl;
  set baseUrl(String v) => _baseUrl = v;

  Future<String?> get token async {
    if (_tokenRead) return _cachedToken;
    _cachedToken = await _storage.read(key: _storageKey);
    _tokenRead = true;
    return _cachedToken;
  }

  Future<void> setToken(String? t) async {
    _cachedToken = t;
    _tokenRead = true;
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
    final base = _baseUrl;
    final uri = Uri.parse('$base/api/v1$path').replace(queryParameters: queryParams);
    return _client.get(uri, headers: await _headers());
  }

  Future<http.Response> post(String path, {Object? body, Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$_baseUrl/api/v1$path').replace(queryParameters: queryParams);
    return _client.post(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
  }

  Future<http.Response> put(String path, {Object? body}) async {
    final uri = Uri.parse('$_baseUrl/api/v1$path');
    return _client.put(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
  }

  Future<http.Response> delete(String path) async {
    final uri = Uri.parse('$_baseUrl/api/v1$path');
    return _client.delete(uri, headers: await _headers());
  }

  Future<bool> get isLoggedIn async => (await token) != null;
}
