import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _keyPointId = 'rifard_pos_point_id';
const _keyDeviceId = 'rifard_pos_device_id';

final _storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

/// Obtiene el pointId guardado (null si no ha seleccionado punto).
Future<String?> getPointId() => _storage.read(key: _keyPointId);

/// Formato canónico: mismo que espera el backend (trim + minúsculas para UUID).
String? _normalizePointId(String? id) {
  final v = id?.trim();
  if (v == null || v.isEmpty) return null;
  return v.toLowerCase();
}

/// Guarda el pointId al seleccionar punto (se guarda en formato canónico para coincidir con la BD).
Future<void> setPointId(String? id) async {
  final v = _normalizePointId(id);
  if (v == null || v.isEmpty) {
    await _storage.delete(key: _keyPointId);
  } else {
    await _storage.write(key: _keyPointId, value: v);
  }
}

/// Obtiene el deviceId; si no existe lo genera y persiste (único por instalación).
Future<String> getDeviceId() async {
  var id = await _storage.read(key: _keyDeviceId);
  if (id == null || id.isEmpty) {
    id = 'pos-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999999)}';
    await _storage.write(key: _keyDeviceId, value: id);
  }
  return id;
}

/// Limpia la sesión (punto). El deviceId se mantiene.
Future<void> clearSession() => setPointId(null);

/// Sesión actual: pointId (puede ser null) y deviceId (siempre presente).
final posSessionProvider = FutureProvider<PosSession>((ref) async {
  final pointId = await getPointId();
  final deviceId = await getDeviceId();
  return PosSession(pointId: pointId, deviceId: deviceId);
});

class PosSession {
  const PosSession({this.pointId, required this.deviceId});
  final String? pointId;
  final String deviceId;
  bool get hasPoint => pointId != null && pointId!.isNotEmpty;
}
