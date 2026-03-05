import 'dart:convert';
import 'package:flutter/foundation.dart';
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

String _errorMessageFromBody(String body) {
  try {
    final m = jsonDecode(body);
    if (m is Map) {
      final msg = m['message'];
      if (msg is String) return msg;
      if (msg is List && msg.isNotEmpty) return msg.map((e) => e.toString()).join(', ');
    }
  } catch (_) {}
  return 'Error al guardar';
}

/// GET /users?page=&limit= -> { data: [], meta: { total, page, limit } }
final usersListProvider = FutureProvider.family<Map<String, dynamic>, ({int page, int limit})>((ref, params) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/users', queryParams: {'page': '${params.page}', 'limit': '${params.limit}'});
  if (resp.statusCode != 200) return {'data': <dynamic>[], 'meta': {'total': 0, 'page': params.page, 'limit': params.limit}};
  return _parse(resp.body);
});

/// GET /users/roles -> List<{ id, code, name }>
final rolesListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/users/roles');
  if (resp.statusCode != 200) return [];
  try {
    final list = jsonDecode(resp.body) as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (_) {
    return [];
  }
});

/// GET /users/:id
Future<Map<String, dynamic>?> fetchUser(Ref ref, String id) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.get('/users/$id');
  if (resp.statusCode != 200) return null;
  return _parse(resp.body);
}

/// POST /users — devuelve (data, error) para mostrar el mensaje del backend.
Future<({Map<String, dynamic>? data, String? error})> createUserWithError(dynamic ref, Map<String, dynamic> body) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.post('/users', body: body);
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    ref.invalidate(usersListProvider);
    return (data: _parse(resp.body), error: null);
  }
  debugPrint('POST /users failed: ${resp.statusCode} ${resp.body}');
  return (data: null, error: _errorMessageFromBody(resp.body));
}

Future<Map<String, dynamic>?> createUser(dynamic ref, Map<String, dynamic> body) async {
  final result = await createUserWithError(ref, body);
  return result.data;
}

/// PUT /users/:id — devuelve (data, error) para mostrar el mensaje del backend.
Future<({Map<String, dynamic>? data, String? error})> updateUserWithError(dynamic ref, String id, Map<String, dynamic> body) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.put('/users/$id', body: body);
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    ref.invalidate(usersListProvider);
    return (data: _parse(resp.body), error: null);
  }
  debugPrint('PUT /users/$id failed: ${resp.statusCode} ${resp.body}');
  return (data: null, error: _errorMessageFromBody(resp.body));
}

Future<Map<String, dynamic>?> updateUser(dynamic ref, String id, Map<String, dynamic> body) async {
  final result = await updateUserWithError(ref, id, body);
  return result.data;
}

/// PUT /users/:id/roles
Future<Map<String, dynamic>?> assignRoles(dynamic ref, String userId, List<String> roleIds) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.put('/users/$userId/roles', body: {'roleIds': roleIds});
  if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
  ref.invalidate(usersListProvider);
  return _parse(resp.body);
}

/// PUT /users/:id/activate  body: { active: bool }
Future<bool> setUserActive(dynamic ref, String userId, bool active) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.put('/users/$userId/activate', body: {'active': active});
  if (resp.statusCode < 200 || resp.statusCode >= 300) return false;
  ref.invalidate(usersListProvider);
  return true;
}

String? getErrorMessage(String body) {
  try {
    final m = jsonDecode(body) as Map<String, dynamic>?;
    return m?['message']?.toString();
  } catch (_) {
    return null;
  }
}
