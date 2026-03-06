import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _baseUrlKey = 'rifard_base_url';
const _storageKeyToken = 'rifard_access_token';
const _storageKeyRefresh = 'rifard_refresh_token';

/// URL por defecto del backend (VPS). Si el usuario no guardó ninguna, se usa esta.
const kDefaultBaseUrl = 'http://187.124.81.201:3000';

/// En debug puedes forzar la URL con: flutter run --dart-define=API_URL=http://localhost:3000
String? get _envApiUrl {
  const url = String.fromEnvironment('API_URL', defaultValue: '');
  return url.isEmpty ? null : url;
}

/// Callbacks opcionales para usar sesión en memoria (evita lecturas async al storage).
typedef TokenGetter = String? Function();
typedef SetTokensCallback = Future<void> Function(String accessToken, String? refreshToken);
typedef ClearSessionCallback = Future<void> Function();

class ApiClient {
  ApiClient({
    http.Client? client,
    FlutterSecureStorage? storage,
    this.getToken,
    this.getRefreshToken,
    this.onSetTokens,
    this.onClearSession,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final TokenGetter? getToken;
  final TokenGetter? getRefreshToken;
  final SetTokensCallback? onSetTokens;
  final ClearSessionCallback? onClearSession;

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

  /// Token actual: primero desde sesión en memoria, si no desde storage.
  Future<String?> get token async =>
      getToken?.call() ?? _storage.read(key: _storageKeyToken);

  Future<String?> get refreshToken async =>
      getRefreshToken?.call() ?? _storage.read(key: _storageKeyRefresh);

  Future<void> setToken(String? t) async {
    if (t == null) {
      if (onClearSession != null) {
        await onClearSession!();
      } else {
        await _storage.delete(key: _storageKeyToken);
        await _storage.delete(key: _storageKeyRefresh);
      }
    } else {
      if (onSetTokens != null) {
        await onSetTokens!(t, null);
      } else {
        await _storage.write(key: _storageKeyToken, value: t);
      }
    }
  }

  /// Guarda access y refresh token (login). Al cerrar sesión usar setToken(null).
  Future<void> setTokens(String accessToken, String? refreshToken) async {
    if (onSetTokens != null) {
      await onSetTokens!(accessToken, refreshToken);
    } else {
      await _storage.write(key: _storageKeyToken, value: accessToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _storage.write(key: _storageKeyRefresh, value: refreshToken);
      }
    }
  }

  Future<Map<String, String>> _headers() async {
    final t = getToken?.call() ?? await _storage.read(key: _storageKeyToken);
    final headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (t != null) headers['Authorization'] = 'Bearer $t';
    return headers;
  }

  /// Si el servidor devuelve 401, intenta renovar con refresh token y reintenta la petición una vez.
  Future<http.Response> get(String path, {Map<String, String>? queryParams}) async {
    final base = await effectiveBaseUrl;
    final uri = Uri.parse('$base/api/v1$path').replace(queryParameters: queryParams);
    var resp = await _client.get(uri, headers: await _headers());
    if (resp.statusCode == 401 && await _tryRefresh()) {
      resp = await _client.get(uri, headers: await _headers());
    }
    return resp;
  }

  Future<http.Response> post(String path, {Object? body}) async {
    final base = await effectiveBaseUrl;
    final uri = Uri.parse('$base/api/v1$path');
    var resp = await _client.post(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
    if (resp.statusCode == 401 && await _tryRefresh()) {
      resp = await _client.post(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
    }
    return resp;
  }

  Future<http.Response> put(String path, {Object? body}) async {
    final base = await effectiveBaseUrl;
    final uri = Uri.parse('$base/api/v1$path');
    var resp = await _client.put(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
    if (resp.statusCode == 401 && await _tryRefresh()) {
      resp = await _client.put(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
    }
    return resp;
  }

  /// Si el access token está expirado o expira en menos de [minMinutes] minutos, intenta renovarlo. Útil al entrar en Ventas.
  Future<bool> refreshTokenIfExpiredOrSoon({int minMinutes = 2}) async {
    final t = await token;
    if (t == null || t.isEmpty) return false;
    try {
      final parts = t.split('.');
      if (parts.length != 3) return false;
      String payload = parts[1];
      payload += '=='.substring(0, (4 - payload.length % 4) % 4);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>?;
      final exp = map?['exp'];
      if (exp == null) return false;
      final expSec = exp is int ? exp : (exp as num).toInt();
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final margin = minMinutes * 60;
      if (expSec > now + margin) return false; // aún válido
      return await _tryRefresh();
    } catch (_) {
      return false;
    }
  }

  /// Renueva el access token con el refresh token. Devuelve true si se renovó.
  Future<bool> _tryRefresh() async {
    final ref = await refreshToken;
    if (ref == null || ref.isEmpty) return false;
    final base = await effectiveBaseUrl;
    try {
      final r = await _client.post(
        Uri.parse('$base/api/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'refreshToken': ref}),
      );
      if (r.statusCode != 200 && r.statusCode != 201) return false;
      final data = jsonDecode(r.body) as Map<String, dynamic>?;
      final access = data?['accessToken'] as String?;
      final refresh = data?['refreshToken'] as String?;
      if (access != null && access.isNotEmpty) {
        await setTokens(access, refresh ?? ref);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> get isLoggedIn async => (await token) != null;
}
