import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/http/api_client.dart';

final apiClientProvider = Provider<ApiClient>((_) => ApiClient());

final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.isLoggedIn;
});

final currentUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (await api.token == null) return null;
  final resp = await api.get('/auth/me');
  if (resp.statusCode != 200) return null;
  try {
    return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
  } catch (_) {
    return null;
  }
});
