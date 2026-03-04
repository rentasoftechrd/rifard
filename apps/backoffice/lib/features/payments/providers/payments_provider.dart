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
