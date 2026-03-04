import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart' show Ref;
import '../../../core/http/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// Respuesta: { online: [...], offline: [...] }. Online = lastSeenAt dentro del umbral (ej. 60s).
Future<Map<String, dynamic>> fetchPosConnected(Ref ref) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.get('/pos/connected');
  if (resp.statusCode != 200) {
    return {'online': <dynamic>[], 'offline': <dynamic>[], 'error': true};
  }
  try {
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    return {
      'online': map['online'] as List<dynamic>? ?? [],
      'offline': map['offline'] as List<dynamic>? ?? [],
    };
  } catch (_) {
    return {'online': <dynamic>[], 'offline': <dynamic>[], 'error': true};
  }
}

final posConnectedProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return fetchPosConnected(ref);
});
