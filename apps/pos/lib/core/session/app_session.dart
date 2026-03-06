import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _storageKeyToken = 'rifard_access_token';
const _storageKeyRefresh = 'rifard_refresh_token';

/// Estado de la sesión de auth en memoria. Fuente única del token hasta que expire o logout.
class AppSessionState {
  const AppSessionState({this.token, this.refreshToken});

  final String? token;
  final String? refreshToken;

  bool get isLoggedIn => token != null && token!.isNotEmpty;
}

/// Notifier que mantiene token (y refresh) en memoria y persiste en SecureStorage.
/// No rehidrata al arrancar: el usuario debe ingresar credenciales en cada apertura de la app.
class AppSessionNotifier extends StateNotifier<AppSessionState> {
  AppSessionNotifier(this._storage) : super(const AppSessionState()) {
    if (!_rehydrateCompleter.isCompleted) _rehydrateCompleter.complete();
  }

  final FlutterSecureStorage _storage;
  final Completer<void> _rehydrateCompleter = Completer<void>();

  /// Completa de inmediato (no se restaura sesión desde storage al abrir la app).
  Future<void> get rehydrateFuture => _rehydrateCompleter.future;

  /// Guarda tokens en memoria y en storage. Llamar tras login o tras refresh.
  Future<void> setTokens(String accessToken, String? refreshToken) async {
    final at = accessToken.trim();
    if (at.isEmpty) {
      await clear();
      return;
    }
    await _storage.write(key: _storageKeyToken, value: at);
    final r = refreshToken?.trim();
    if (r != null && r.isNotEmpty) {
      await _storage.write(key: _storageKeyRefresh, value: r);
    }
    state = AppSessionState(
      token: at,
      refreshToken: r ?? state.refreshToken,
    );
  }

  /// Cierra sesión: limpia memoria y storage.
  Future<void> clear() async {
    await _storage.delete(key: _storageKeyToken);
    await _storage.delete(key: _storageKeyRefresh);
    state = const AppSessionState();
  }
}

final _storage = const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

final appSessionProvider = StateNotifierProvider<AppSessionNotifier, AppSessionState>((ref) {
  return AppSessionNotifier(_storage);
});
