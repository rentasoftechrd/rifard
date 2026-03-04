import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/http/api_client.dart';
import '../../auth/providers/auth_provider.dart';

List<dynamic> _parseList(String body) {
  try {
    return jsonDecode(body) as List<dynamic>;
  } catch (_) {
    return [];
  }
}

final payoutsListProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/payouts');
  if (resp.statusCode < 200 || resp.statusCode >= 300) return [];
  return _parseList(resp.body);
});

Future<bool> updatePayout(WidgetRef ref, String betType, double multiplier) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.put('/payouts', body: {'betType': betType, 'multiplier': multiplier});
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    ref.invalidate(payoutsListProvider);
    return true;
  }
  return false;
}
