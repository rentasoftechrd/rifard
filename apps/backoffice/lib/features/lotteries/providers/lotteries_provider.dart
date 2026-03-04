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

List<dynamic> _parseList(String body) {
  try {
    return jsonDecode(body) as List<dynamic>;
  } catch (_) {
    return [];
  }
}

final lotteriesListProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/lotteries');
  if (resp.statusCode < 200 || resp.statusCode >= 300) return [];
  return _parseList(resp.body);
});
