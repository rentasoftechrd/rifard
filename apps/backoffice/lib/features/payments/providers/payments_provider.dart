import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/http/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// Buscar ticket por código para cobro: líneas ganadoras, monto total, si ya fue pagado.
Future<Map<String, dynamic>?> getTicketForPayment(WidgetRef ref, String code) async {
  if (code.trim().isEmpty) return null;
  final api = ref.read(apiClientProvider);
  final resp = await api.get('/tickets/code/${Uri.encodeComponent(code.trim())}/payment');
  if (resp.statusCode != 200) return null;
  try {
    return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
  } catch (_) {
    return null;
  }
}

/// Marcar ticket como pagado (cobro de premio).
Future<Map<String, dynamic>?> markTicketAsPaid(WidgetRef ref, String ticketId) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.post('/tickets/$ticketId/pay');
  if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
  try {
    return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
  } catch (_) {
    return null;
  }
}

/// Parámetros para listar tickets ganadores del día. [date] YYYY-MM-DD, [lotteryId] opcional.
class WinnersQuery {
  const WinnersQuery({required this.date, this.lotteryId});
  final String date;
  final String? lotteryId;
}

/// Lista tickets ganadores para una fecha (y opcionalmente por lotería).
final winningTicketsProvider = FutureProvider.family<List<dynamic>, WinnersQuery>((ref, q) async {
  final api = ref.watch(apiClientProvider);
  final uri = q.lotteryId != null && q.lotteryId!.isNotEmpty
      ? '/tickets/winners?date=${Uri.encodeComponent(q.date)}&lotteryId=${Uri.encodeComponent(q.lotteryId!)}'
      : '/tickets/winners?date=${Uri.encodeComponent(q.date)}';
  try {
    final resp = await api.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return [];
    if (resp.body.isEmpty) return [];
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return [];
    return List<dynamic>.from(decoded);
  } catch (_) {
    return [];
  }
});

/// Parámetros para historial de ganadores.
class WinnersHistoryQuery {
  const WinnersHistoryQuery({required this.from, required this.to});
  final String from;
  final String to;
}

/// Lista tickets ganadores en rango de fechas (historial).
final winningTicketsHistoryProvider = FutureProvider.family<List<dynamic>, WinnersHistoryQuery>((ref, q) async {
  final api = ref.watch(apiClientProvider);
  final uri = '/tickets/winners/history?from=${Uri.encodeComponent(q.from)}&to=${Uri.encodeComponent(q.to)}';
  try {
    final resp = await api.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return [];
    if (resp.body.isEmpty) return [];
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return [];
    return List<dynamic>.from(decoded);
  } catch (_) {
    return [];
  }
});
