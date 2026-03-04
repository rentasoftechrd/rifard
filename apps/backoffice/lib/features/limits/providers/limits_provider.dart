import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/http/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../lotteries/providers/lotteries_provider.dart';

Map<String, dynamic> _parse(String body) {
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

/// Fecha para filtrar sorteos al configurar límites (por defecto hoy).
final limitsDateFilterProvider = StateProvider<String>((ref) => '');

/// Lotería seleccionada para el alcance de los límites.
final limitsLotteryIdProvider = StateProvider<String?>((ref) => null);

/// Sorteo seleccionado para el alcance de los límites.
final limitsDrawIdProvider = StateProvider<String?>((ref) => null);

/// Lista de sorteos para la fecha (para elegir alcance lottery + draw).
final limitsDrawsForDateProvider = FutureProvider.family<List<dynamic>, String>((ref, date) async {
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

/// Lista de límites: por defecto todos; filtro opcional (lotteryId/drawId) solo para casos excepcionales.
final limitsListProvider = FutureProvider<List<dynamic>>((ref) async {
  final lotteryId = ref.watch(limitsLotteryIdProvider);
  final drawId = ref.watch(limitsDrawIdProvider);
  final api = ref.watch(apiClientProvider);
  final params = <String, String>{};
  if (lotteryId != null && lotteryId.isNotEmpty) params['lotteryId'] = lotteryId;
  if (drawId != null && drawId.isNotEmpty) params['drawId'] = drawId;
  try {
    final resp = await api.get('/limits', queryParams: params);
    if (resp.statusCode < 200 || resp.statusCode >= 300) return [];
    return _parseList(resp.body);
  } catch (_) {
    return [];
  }
});

/// Crear o actualizar un límite (solo SUPER_ADMIN).
Future<bool> upsertLimit(WidgetRef ref, Map<String, dynamic> body) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.put('/limits', body: body);
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    ref.invalidate(limitsListProvider);
    return true;
  }
  return false;
}

/// Eliminar un límite.
Future<bool> deleteLimit(WidgetRef ref, String id) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.delete('/limits/$id');
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    ref.invalidate(limitsListProvider);
    return true;
  }
  return false;
}
