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

Future<bool> updatePayout(WidgetRef ref, String betType, String variant, double multiplier) async {
  final api = ref.read(apiClientProvider);
  final body = <String, dynamic>{'betType': betType, 'multiplier': multiplier};
  if (variant.isNotEmpty) body['variant'] = variant;
  final resp = await api.put('/payouts', body: body);
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    ref.invalidate(payoutsListProvider);
    return true;
  }
  return false;
}
