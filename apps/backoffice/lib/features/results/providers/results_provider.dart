import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/http/api_client.dart';
import '../../auth/providers/auth_provider.dart';

Map<String, dynamic> _parseMap(String body) {
  try {
    return Map<String, dynamic>.from(jsonDecode(body) as Map);
  } catch (_) {
    return {};
  }
}

List<dynamic> _parseList(String body) {
  try {
    return jsonDecode(body) as List<dynamic>;
  } catch (_) {
    return [];
  }
}

/// Lista de resultados pendientes de aprobación (OPERADOR+ ve lista; solo ADMIN/SUPER aprueban).
final pendingResultsProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/draws/results/pending');
  if (resp.statusCode < 200 || resp.statusCode >= 300) return [];
  return _parseList(resp.body);
});

/// Resultado de un sorteo (para ver/editar al ingresar o ver en pendientes).
final drawResultProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, drawId) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/draws/$drawId/results');
  if (resp.statusCode == 404 || resp.statusCode < 200 || resp.statusCode >= 300) return null;
  return _parseMap(resp.body);
});

/// Ingresar resultados (OPERADOR_BACKOFFICE+). Draw debe estar cerrado y pasada la hora del sorteo.
Future<Map<String, dynamic>?> enterResult(WidgetRef ref, String drawId, Map<String, dynamic> results) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.post('/draws/$drawId/results', body: {'results': results});
  if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
  return _parseMap(resp.body);
}

/// Aprobar resultado (solo ADMIN/SUPER_ADMIN).
Future<Map<String, dynamic>?> approveResult(WidgetRef ref, String drawId) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.post('/draws/$drawId/results/approve', body: {});
  if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
  return _parseMap(resp.body);
}

/// Rechazar resultado (solo ADMIN/SUPER_ADMIN).
Future<Map<String, dynamic>?> rejectResult(WidgetRef ref, String drawId, {String? reason}) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.post('/draws/$drawId/results/reject', body: reason != null ? {'reason': reason} : {});
  if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
  return _parseMap(resp.body);
}

/// Fecha para filtrar sorteos en la pestaña Ingresar.
final resultsDateFilterProvider = StateProvider<String>((ref) => '');

/// Lista de sorteos para una fecha (tab Ingresar). Pasar fecha YYYY-MM-DD; si vacía retorna [].
final resultsDrawsForDateProvider = FutureProvider.family<List<dynamic>, String>((ref, date) async {
  if (date.isEmpty) return [];
  final api = ref.watch(apiClientProvider);
  try {
    final resp = await api.get('/draws', queryParams: {'date': date});
    if (resp.statusCode < 200 || resp.statusCode >= 300) return [];
    return _parseList(resp.body);
  } catch (_) {
    return [];
  }
});
