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

List<dynamic> _parseList(String body) {
  try {
    return jsonDecode(body) as List<dynamic>? ?? [];
  } catch (_) {
    return [];
  }
}

/// GET /personas?page=&limit=&tipo=
final personasListProvider = FutureProvider.family<Map<String, dynamic>, ({int page, int limit, String? tipo})>((ref, params) async {
  final api = ref.watch(apiClientProvider);
  final queryParams = <String, String>{
    'page': '${params.page}',
    'limit': '${params.limit}',
  };
  if (params.tipo != null && params.tipo!.isNotEmpty) queryParams['tipo'] = params.tipo!;
  final resp = await api.get('/personas', queryParams: queryParams);
  if (resp.statusCode != 200) return {'data': <dynamic>[], 'meta': {'total': 0, 'page': params.page, 'limit': params.limit}};
  return _parse(resp.body);
});

/// Result: (data, errorMessage). On success data is non-null; on failure errorMessage is non-null.
Future<({Map<String, dynamic>? data, String? error})> createPersonaWithError(dynamic ref, Map<String, dynamic> body) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.post('/personas', body: body);
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    ref.invalidate(personasListProvider);
    return (data: _parse(resp.body), error: null);
  }
  // Debug: ver en consola qué devolvió el backend
  debugPrint('POST /personas failed: ${resp.statusCode} ${resp.body}');
  final msg = _errorMessageFromBody(resp.body);
  return (data: null, error: msg);
}

Future<Map<String, dynamic>?> createPersona(dynamic ref, Map<String, dynamic> body) async {
  final result = await createPersonaWithError(ref, body);
  return result.data;
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

/// Result: (data, errorMessage).
Future<({Map<String, dynamic>? data, String? error})> updatePersonaWithError(dynamic ref, String id, Map<String, dynamic> body) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.put('/personas/$id', body: body);
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    ref.invalidate(personasListProvider);
    return (data: _parse(resp.body), error: null);
  }
  debugPrint('PUT /personas/$id failed: ${resp.statusCode} ${resp.body}');
  final msg = _errorMessageFromBody(resp.body);
  return (data: null, error: msg);
}

/// PUT /personas/:id
Future<Map<String, dynamic>?> updatePersona(dynamic ref, String id, Map<String, dynamic> body) async {
  final result = await updatePersonaWithError(ref, id, body);
  return result.data;
}
