import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/http/api_client.dart';
import '../../../core/session/pos_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

/// Intervalo de heartbeat (segundos). El backoffice considera online si last_seen <= 60s.
const _heartbeatIntervalSeconds = 20;

class SellScreen extends ConsumerStatefulWidget {
  const SellScreen({super.key});

  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends ConsumerState<SellScreen> {
  List<Map<String, dynamic>> _lotteries = [];
  List<Map<String, dynamic>> _draws = [];
  String? _selectedLotteryId;
  String? _selectedDrawId;
  final _lines = <Map<String, dynamic>>[];
  bool _loading = false;
  String? _error;
  Timer? _heartbeatTimer;
  bool _heartbeatOk = false;
  String? _heartbeatError;
  bool _deviceRegistered = false;
  /// Mensaje del servidor al fallar register-device (ej. "No tiene asignado este punto").
  String? _registerDeviceError;
  /// Error al cargar loterías (ej. 401, sin conexión).
  String? _lotteriesError;
  /// Código HTTP al cargar loterías (para diagnóstico).
  int? _lotteriesStatus;
  /// Código HTTP de register-device (para diagnóstico).
  int? _registerDeviceStatus;
  /// En debug: URL del backend (para verificar a qué servidor se conecta).
  String? _debugApiUrl;
  /// Resultado del diagnóstico (Probar conexión).
  String? _diagnosticMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSessionAndLoad();
      if (kDebugMode) {
        ref.read(apiClientProvider).effectiveBaseUrl.then((url) {
          if (mounted) setState(() => _debugApiUrl = url);
        });
      }
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _initSessionAndLoad() async {
    final session = await ref.read(posSessionProvider.future);
    if (!session.hasPoint) {
      if (mounted) context.go('/select-point');
      return;
    }
    await _loadLotteries();
    final result = await _ensureDeviceRegistered();
    if (mounted) {
      setState(() {
        _deviceRegistered = result.ok;
        _registerDeviceError = result.error;
      });
    }
    _startHeartbeat();
  }

  /// Prueba conectividad: health (sin auth) y pos/points (con auth). Muestra resultado.
  Future<void> _runDiagnostic() async {
    setState(() => _diagnosticMessage = 'Probando…');
    final api = ref.read(apiClientProvider);
    final base = await api.effectiveBaseUrl;
    final session = await ref.read(posSessionProvider.future);
    final buffer = StringBuffer();
    buffer.writeln('Sesión: pointId=${session.pointId ?? "null"} deviceId=${session.deviceId.length > 20 ? "${session.deviceId.substring(0, 20)}…" : session.deviceId}');
    buffer.writeln('');
    try {
      final healthResp = await api.get('/health/pos-connect');
      buffer.writeln('Health (sin login): ${healthResp.statusCode}');
      if (healthResp.statusCode != 200) buffer.writeln('  → Servidor responde pero no OK. Revisa el backend.');
    } catch (e) {
      buffer.writeln('Health: ERROR $e');
      buffer.writeln('  → No se puede conectar a $base. ¿Backend encendido? ¿URL correcta?');
    }
    try {
      final pointsResp = await api.get('/pos/points');
      buffer.writeln('POS Points (con login): ${pointsResp.statusCode}');
      if (pointsResp.statusCode == 200) {
        final list = jsonDecode(pointsResp.body);
        final count = list is List ? list.length : 0;
        buffer.writeln('  → Puntos asignados: $count');
        if (list is List && list.isNotEmpty && session.pointId != null) {
          final ids = list.map((e) => (e as Map)['id']?.toString()).toList();
          final match = ids.contains(session.pointId);
          buffer.writeln('  → pointId de esta sesión está en la lista: $match');
        }
      } else if (pointsResp.statusCode == 401) {
        buffer.writeln('  → Token inválido o expirado. Cierra sesión y vuelve a entrar.');
      } else {
        buffer.writeln('  → ${_messageFromResponse(pointsResp.body)}');
      }
    } catch (e) {
      buffer.writeln('POS Points: ERROR $e');
    }
    buffer.writeln('');
    buffer.writeln('URL: $base');
    if (mounted) setState(() => _diagnosticMessage = buffer.toString());
  }

  static String _messageFromResponse(String body) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>?;
      if (m == null) return body;
      final msg = m['message'];
      if (msg is String) return msg;
      if (msg is List && msg.isNotEmpty && msg.first is String) return msg.first as String;
      return m['error']?.toString() ?? body;
    } catch (_) {
      return body.isEmpty ? 'Error del servidor' : body;
    }
  }

  /// Formato canónico para pointId (igual que en backend/BD): trim + minúsculas.
  static String _canonicalPointId(String? id) => (id ?? '').trim().toLowerCase();

  /// Registra el dispositivo en el backend (necesario para que el heartbeat funcione).
  Future<({bool ok, String? error, int? status})> _ensureDeviceRegistered() async {
    try {
      final session = await ref.read(posSessionProvider.future);
      final api = ref.read(apiClientProvider);
      final pointId = _canonicalPointId(session.pointId);
      final deviceId = (session.deviceId).trim();
      if (pointId.isEmpty) {
        if (mounted) setState(() => _registerDeviceStatus = 400);
        return (ok: false, error: 'No hay punto seleccionado. Vuelve a "Seleccionar punto" y elige uno.', status: 400);
      }
      if (kDebugMode) debugPrint('POS: register-device sending pointId=$pointId deviceId=$deviceId');
      final resp = await api.post('/pos/register-device', body: {
        'deviceId': deviceId,
        'pointId': pointId,
      });
      if (mounted) setState(() => _registerDeviceStatus = resp.statusCode);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (kDebugMode) debugPrint('POS: register-device OK');
        return (ok: true, error: null, status: resp.statusCode);
      }
      final msg = _messageFromResponse(resp.body);
      if (resp.statusCode == 401) return (ok: false, error: 'Sesión expirada (401). Cierra sesión y vuelve a entrar.', status: 401);
      if (resp.statusCode >= 500) return (ok: false, error: 'Error del servidor (${resp.statusCode}). Puede ser fallo de conexión con la base de datos.', status: resp.statusCode);
      if (kDebugMode) debugPrint('POS: register-device failed ${resp.statusCode} $msg');
      return (ok: false, error: msg.isNotEmpty ? msg : 'Error $resp.statusCode', status: resp.statusCode);
    } catch (e, st) {
      if (kDebugMode) debugPrint('POS: register-device error $e\n$st');
      if (mounted) setState(() => _registerDeviceStatus = null);
      return (ok: false, error: 'Sin conexión. Revisa la URL del servidor y que el backend esté encendido.', status: null);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: _heartbeatIntervalSeconds), (_) => _sendHeartbeat());
    _sendHeartbeat();
  }

  Future<void> _sendHeartbeat() async {
    final session = await ref.read(posSessionProvider.future);
    if (!session.hasPoint) return;
    final api = ref.read(apiClientProvider);
    final user = await ref.read(currentUserProvider.future);
    final userId = user?['id']?.toString();
    try {
      final resp = await api.post('/pos/heartbeat', body: {
        'deviceId': (session.deviceId).trim(),
        'pointId': _canonicalPointId(session.pointId),
        if (userId != null) 'sellerId': userId,
        'appVersion': '1.0.0',
      });
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (mounted) setState(() { _heartbeatOk = true; _heartbeatError = null; });
        return;
      }
      if (resp.statusCode == 404 && resp.body.contains('not registered')) {
        if (kDebugMode) debugPrint('POS: heartbeat 404 (device not registered), re-registering...');
        final ok = await _ensureDeviceRegistered();
        if (ok) {
          await _sendHeartbeat();
          return;
        }
      }
      if (kDebugMode) debugPrint('POS: heartbeat failed ${resp.statusCode} ${resp.body}');
      if (mounted) setState(() { _heartbeatOk = false; _heartbeatError = '${resp.statusCode}'; });
    } catch (e, st) {
      if (kDebugMode) debugPrint('POS: heartbeat error $e\n$st');
      if (mounted) setState(() { _heartbeatOk = false; _heartbeatError = 'Sin conexión'; });
    }
  }

  Future<void> _loadLotteries() async {
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.get('/lotteries');
      if (mounted) setState(() => _lotteriesStatus = resp.statusCode);
      if (resp.statusCode == 200) {
        final data = _parseList(resp.body);
        if (mounted) setState(() { _lotteries = data; _lotteriesError = null; });
        return;
      }
      String msg = _messageFromResponse(resp.body);
      if (resp.statusCode == 401) msg = 'Sesión expirada. Cierra sesión y vuelve a entrar.';
      if (resp.statusCode >= 500) msg = 'Error del servidor ($resp.statusCode). Puede ser fallo de conexión con la base de datos.';
      if (mounted) setState(() => _lotteriesError = 'Loterías ($resp.statusCode): $msg');
    } catch (e) {
      if (mounted) setState(() {
        _lotteriesStatus = null;
        _lotteriesError = 'No se pudieron cargar las loterías. Revisa la URL del servidor (misma que el backoffice) y que el backend esté encendido.';
      });
    }
  }

  Future<void> _loadDraws() async {
    if (_selectedLotteryId == null) return;
    final api = ref.read(apiClientProvider);
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final resp = await api.get('/draws', queryParams: {'date': date, 'lotteryId': _selectedLotteryId!});
    if (resp.statusCode == 200) {
      final data = _parseList(resp.body);
      setState(() => _draws = data);
    }
  }

  List<Map<String, dynamic>> _parseList(String s) {
    try {
      final decoded = jsonDecode(s);
      if (decoded is List) return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (decoded is Map && decoded['data'] != null) return _parseList(jsonEncode(decoded['data']));
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _sell() async {
    if (_lines.isEmpty) {
      setState(() => _error = 'Agregar al menos una línea');
      return;
    }
    final session = await ref.read(posSessionProvider.future);
    if (!session.hasPoint) {
      if (mounted) context.go('/select-point');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.post('/tickets', body: {
        'pointId': session.pointId,
        'deviceId': session.deviceId,
        'lines': _lines.map((l) => {
              'lotteryId': l['lotteryId'],
              'drawId': l['drawId'],
              'betType': l['betType'] ?? 'quiniela',
              'numbers': l['numbers'],
              'amount': l['amount'],
            }),
      });
      final data = resp.body.isNotEmpty ? jsonDecode(resp.body) as Map : {};
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        final code = data['ticketCode'] ?? data['ticket_code'];
        if (code != null && mounted) context.go('/sell/ticket/$code');
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'Error al crear ticket';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(posSessionProvider);
    final deviceId = sessionAsync.valueOrNull?.deviceId;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Venta'),
            if (deviceId != null)
              Tooltip(
                message: deviceId,
                child: Text(
                  'Device: ${deviceId.length > 20 ? '${deviceId.substring(0, 20)}…' : deviceId}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => context.go('/history'), child: const Text('Historial')),
          TextButton(onPressed: () => context.go('/void'), child: const Text('Anular')),
          TextButton(onPressed: () => context.go('/closeout'), child: const Text('Cierre')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (kDebugMode && _debugApiUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('API: $_debugApiUrl', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  if (sessionAsync.valueOrNull?.pointId != null)
                    Text('Punto ID: ${sessionAsync.valueOrNull!.pointId}', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ),
          DropdownButtonFormField<String>(
            value: _selectedLotteryId,
            decoration: InputDecoration(
              labelText: 'Lotería',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            ),
            dropdownColor: AppColors.surface,
            items: _lotteries.map((l) => DropdownMenuItem(value: l['id']?.toString(), child: Text(l['name']?.toString() ?? '', style: const TextStyle(color: AppColors.textPrimary)))).toList(),
            onChanged: (v) {
              setState(() {
                _selectedLotteryId = v;
                _selectedDrawId = null;
                _draws = [];
              });
              _loadDraws();
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedDrawId,
            decoration: InputDecoration(
              labelText: 'Sorteo',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            ),
            dropdownColor: AppColors.surface,
            items: _draws.map((d) => DropdownMenuItem(value: d['id']?.toString(), child: Text('${d['drawTime'] ?? d['draw_time']}', style: const TextStyle(color: AppColors.textPrimary)))).toList(),
            onChanged: _selectedLotteryId == null ? null : (v) => setState(() => _selectedDrawId = v),
          ),
          if (_lotteriesError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.danger)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_lotteriesError!, style: TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      setState(() => _lotteriesError = null);
                      await _loadLotteries();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reintentar cargar loterías'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
          if (!_deviceRegistered) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.warning)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('No se pudo registrar el dispositivo${_registerDeviceStatus != null ? " ($_registerDeviceStatus)" : ""}.', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
                    ],
                  ),
                  if (_registerDeviceError != null && _registerDeviceError!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_registerDeviceError!, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                  const SizedBox(height: 4),
                  Text('Debes entrar con el mismo usuario que tiene el punto asignado en el backoffice (Personas → Puntos). Usa la misma URL del servidor que el backoffice.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _runDiagnostic,
            icon: const Icon(Icons.bug_report_outlined, size: 18),
            label: const Text('Probar conexión (diagnóstico)'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
          ),
          if (_diagnosticMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              child: SelectableText(_diagnosticMessage!, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), maxLines: 15),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: _loading ? null : _sell,
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Vender'),
          ),
        ],
      ),
    );
  }
}
