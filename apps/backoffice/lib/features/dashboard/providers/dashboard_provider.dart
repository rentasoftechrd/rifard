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

/// Parámetros para el resumen del dashboard: fecha (YYYY-MM-DD) y rango (day, week, month).
class DashboardParams {
  const DashboardParams({required this.date, this.range = 'day'});
  final String date;
  final String range;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DashboardParams && date == other.date && range == other.range;
  @override
  int get hashCode => Object.hash(date, range);
}

final dashboardSummaryProvider = FutureProvider.family<Map<String, dynamic>, DashboardParams>((ref, params) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/reports/dashboard-summary', queryParams: {'date': params.date, 'range': params.range});
  if (resp.statusCode < 200 || resp.statusCode >= 300) return {};
  return _parse(resp.body);
});

/// Filtro de período: day = Hoy, week = Esta semana, month = Este mes.
final dashboardRangeFilterProvider = StateProvider<String>((ref) => 'day');

/// Hora exacta del último refresco del dashboard (se actualiza cuando llegan los datos).
final lastDashboardRefreshProvider = StateProvider<DateTime?>((ref) => null);

/// Hora actual que se actualiza cada segundo para mostrar un reloj en vivo en el dashboard.
final dashboardCurrentTimeProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});
