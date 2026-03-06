import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../http/api_client.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Respuesta de GET /health/time. Toda la hora viene del servidor (RD).
class ServerTime {
  const ServerTime({
    required this.serverTimeUtc,
    required this.serverTimeLocal,
    required this.serverDate,
    required this.timezone,
    required this.offsetMinutes,
  });
  final String serverTimeUtc;
  final String serverTimeLocal;
  final String serverDate;
  final String timezone;
  final int offsetMinutes;

  /// Para mostrar en UI: "Hora servidor (RD): 05:42:18 PM"
  String get displayLabel => serverTimeLocal;
}

/// Obtiene la hora del servidor (público, no requiere login).
Future<ServerTime?> fetchServerTime(ApiClient api) async {
  try {
    final resp = await api.get('/health/time');
    if (resp.statusCode != 200) return null;
    final map = jsonDecode(resp.body) as Map<String, dynamic>?;
    if (map == null) return null;
    return ServerTime(
      serverTimeUtc: map['serverTimeUtc']?.toString() ?? '',
      serverTimeLocal: map['serverTimeLocal']?.toString() ?? '',
      serverDate: map['serverDate']?.toString() ?? '',
      timezone: map['timezone']?.toString() ?? 'America/Santo_Domingo',
      offsetMinutes: (map['offsetMinutes'] is int) ? map['offsetMinutes'] as int : -240,
    );
  } catch (_) {
    return null;
  }
}

/// Hora del servidor (RD). Se puede invalidar para refrescar.
final serverTimeProvider = FutureProvider.autoDispose<ServerTime?>((ref) {
  final api = ref.watch(apiClientProvider);
  return fetchServerTime(api);
});
