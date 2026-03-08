import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart' show Ref;
import '../../../core/http/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// Respuesta: { online: [...], offline: [...] }. Online = lastSeenAt dentro del umbral (ej. 60s).
Future<Map<String, dynamic>> fetchPosConnected(Ref ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final resp = await api.get('/pos/connected');
    if (resp.statusCode != 200) {
      String msg = 'Error ${resp.statusCode}';
      if (resp.body.isNotEmpty) {
        try {
          final m = jsonDecode(resp.body) as Map<String, dynamic>?;
          if (m != null && m['message'] != null) msg = m['message'].toString();
        } catch (_) {}
      }
      return {'online': <dynamic>[], 'offline': <dynamic>[], 'error': true, 'errorMessage': msg};
    }
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    return {
      'online': map['online'] as List<dynamic>? ?? [],
      'offline': map['offline'] as List<dynamic>? ?? [],
    };
  } catch (e) {
    return {'online': <dynamic>[], 'offline': <dynamic>[], 'error': true, 'errorMessage': e.toString()};
  }
}

/// autoDispose: al salir y volver a la pantalla se vuelve a cargar. Invalidar refresca desde el backend.
final posConnectedProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return fetchPosConnected(ref);
});
