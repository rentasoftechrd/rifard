import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/http/api_client.dart';
import '../../auth/providers/auth_provider.dart';

Map<String, dynamic> _parse(String body) {
  try {
    return Map<String, dynamic>.from(jsonDecode(body) as Map);
  } catch (_) {
    return {};
  }
}

final dashboardSummaryProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, date) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/reports/dashboard-summary', queryParams: {'date': date});
  if (resp.statusCode < 200 || resp.statusCode >= 300) return {};
  return _parse(resp.body);
});

/// Hora exacta del último refresco del dashboard (se actualiza cuando llegan los datos).
final lastDashboardRefreshProvider = StateProvider<DateTime?>((ref) => null);

/// Hora actual que se actualiza cada segundo para mostrar un reloj en vivo en el dashboard.
final dashboardCurrentTimeProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});
