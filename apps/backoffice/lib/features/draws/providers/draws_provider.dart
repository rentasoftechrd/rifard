import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/http/api_client.dart';
import '../../auth/providers/auth_provider.dart';

String todayDateStr() {
  final n = DateTime.now().toUtc();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

List<dynamic> _parseList(String body) {
  try {
    return jsonDecode(body) as List<dynamic>;
  } catch (_) {
    return [];
  }
}

Map<String, dynamic> _parseMap(String body) {
  try {
    return Map<String, dynamic>.from(jsonDecode(body) as Map);
  } catch (_) {
    return {};
  }
}

final drawsDateFilterProvider = StateProvider<String>((ref) => todayDateStr());
final drawsLotteryFilterProvider = StateProvider<String?>((ref) => null);

/// Fecha "hoy" del servidor (República Dominicana). Para limitar el date picker y no permitir fechas futuras.
final serverDateProvider = FutureProvider<String>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final resp = await api.get('/health');
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = _parseMap(resp.body);
      final date = data['serverDate']?.toString();
      if (date != null && date.isNotEmpty) return date;
    }
  } catch (_) {}
  return todayDateStr();
});

/// Etiqueta para mostrar en UI: hora del servidor + zona (ej. "27/02/2026 10:30 America/Santo_Domingo").
final serverTimeLabelProvider = FutureProvider<String>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final resp = await api.get('/health');
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = _parseMap(resp.body);
      final display = data['serverTimeDisplay']?.toString();
      final tz = data['timezone']?.toString();
      if (display != null && display.isNotEmpty) {
        return tz != null && tz.isNotEmpty ? '$display $tz' : display;
      }
    }
  } catch (_) {}
  return '';
});

final drawsListProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final date = ref.watch(drawsDateFilterProvider);
  final lotteryId = ref.watch(drawsLotteryFilterProvider);
  final queryParams = <String, String>{'date': date};
  if (lotteryId != null && lotteryId.isNotEmpty) queryParams['lotteryId'] = lotteryId;
  try {
    final resp = await api.get('/draws', queryParams: queryParams);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      // 400/500: devolver lista vacía para no romper la UI; el backend ya envió mensaje en body
      return [];
    }
    return _parseList(resp.body);
  } catch (e) {
    // Red de red o excepción inesperada: lista vacía en lugar de error
    return [];
  }
});

final exposureProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, drawId) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/reports/exposure', queryParams: {'drawId': drawId});
  if (resp.statusCode < 200 || resp.statusCode >= 300) return {};
  return _parseMap(resp.body);
});
