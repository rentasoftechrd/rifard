import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/http/api_client.dart';
import '../../../core/session/app_session.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    getToken: () => ref.read(appSessionProvider).token,
    getRefreshToken: () => ref.read(appSessionProvider).refreshToken,
    onSetTokens: (access, refresh) => ref.read(appSessionProvider.notifier).setTokens(access, refresh),
    onClearSession: () => ref.read(appSessionProvider.notifier).clear(),
  );
});

/// Espera rehidratación desde storage y luego devuelve si hay sesión (token en memoria).
final isLoggedInProvider = FutureProvider<bool>((ref) async {
  await ref.read(appSessionProvider.notifier).rehydrateFuture;
  return ref.watch(appSessionProvider).isLoggedIn;
});

final currentUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (await api.token == null) return null;
  final resp = await api.get('/auth/me');
  if (resp.statusCode != 200) return null;
  try {
    return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
  } catch (_) {
    return null;
  }
});
