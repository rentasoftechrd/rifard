import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/http/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// Punto de venta (POS) para listado backoffice.
class PosPointItem {
  PosPointItem({
    required this.id,
    required this.name,
    required this.code,
    this.address,
    required this.active,
    required this.assignmentsCount,
    required this.devicesCount,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String name;
  final String code;
  final String? address;
  final bool active;
  final int assignmentsCount;
  final int devicesCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static PosPointItem fromJson(Map<String, dynamic> m) {
    return PosPointItem(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      code: m['code']?.toString() ?? '',
      address: m['address']?.toString(),
      active: m['active'] == true,
      assignmentsCount: (m['assignmentsCount'] is int) ? m['assignmentsCount'] as int : 0,
      devicesCount: (m['devicesCount'] is int) ? m['devicesCount'] as int : 0,
      createdAt: _parseDate(m['createdAt']),
      updatedAt: _parseDate(m['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

Future<List<PosPointItem>> fetchPosPointsForAdmin(Ref ref) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.get('/pos/points-admin');
  if (resp.statusCode != 200) return [];
  try {
    final list = jsonDecode(resp.body) as List<dynamic>? ?? [];
    return list.map<PosPointItem>((e) => PosPointItem.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    if (kDebugMode) debugPrint('fetchPosPointsForAdmin parse error: $e');
    return [];
  }
}

final posPointsAdminProvider = FutureProvider.autoDispose<List<PosPointItem>>((ref) => fetchPosPointsForAdmin(ref));

/// Resultado de crear/actualizar con posible error del backend.
Future<({Map<String, dynamic>? data, String? error})> createPosPointWithError(dynamic ref, {required String name, required String code, String? address, bool active = true}) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.post('/pos/points', body: {'name': name, 'code': code, if (address != null && address.isNotEmpty) 'address': address, 'active': active});
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    ref.invalidate(posPointsAdminProvider);
    try {
      final data = jsonDecode(resp.body) as Map<String, dynamic>?;
      return (data: data, error: null);
    } catch (_) {
      return (data: <String, dynamic>{}, error: null);
    }
  }
  final msg = _errorMessageFromBody(resp.body);
  if (kDebugMode) debugPrint('createPosPoint failed: ${resp.statusCode} $msg');
  return (data: null, error: msg);
}

Future<({bool ok, String? error})> updatePosPointWithError(dynamic ref, String id, {String? name, String? code, String? address, bool? active}) async {
  final api = ref.read(apiClientProvider);
  final body = <String, dynamic>{};
  if (name != null) body['name'] = name;
  if (code != null) body['code'] = code;
  if (address != null) body['address'] = address;
  if (active != null) body['active'] = active;
  final resp = await api.put('/pos/points/$id', body: body);
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    ref.invalidate(posPointsAdminProvider);
    return (ok: true, error: null);
  }
  final msg = _errorMessageFromBody(resp.body);
  if (kDebugMode) debugPrint('updatePosPoint failed: ${resp.statusCode} $msg');
  return (ok: false, error: msg);
}

Future<({bool ok, String? error})> deactivatePosPointWithError(dynamic ref, String id) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.delete('/pos/points/$id');
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    ref.invalidate(posPointsAdminProvider);
    return (ok: true, error: null);
  }
  final msg = _errorMessageFromBody(resp.body);
  if (kDebugMode) debugPrint('deactivatePosPoint failed: ${resp.statusCode} $msg');
  return (ok: false, error: msg);
}

String _errorMessageFromBody(String body) {
  try {
    final m = jsonDecode(body) as Map<String, dynamic>?;
    if (m == null) return 'Error desconocido';
    final msg = m['message'];
    if (msg is String) return msg;
    if (msg is List && msg.isNotEmpty && msg.first is String) return msg.first as String;
    return m['error']?.toString() ?? 'Error desconocido';
  } catch (_) {
    return body.isNotEmpty ? body : 'Error desconocido';
  }
}
