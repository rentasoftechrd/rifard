import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/http/api_client.dart';
import '../../../core/session/pos_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/server_time/server_time_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/sell_cart_provider.dart';

/// Tipo de jugada: Q=Quiniela, P=Pale, T=Tripleta, S=Super Pale.
const _tipoLetters = ['Q', 'P', 'T', 'S'];

/// Formatea dígitos según tipo: Q=00, P/S=00-00, T=00-00-00.
String _formatNumberByTipo(String digitsOnly, String tipo) {
  if (digitsOnly.isEmpty) return '';
  final digits = digitsOnly.replaceAll(RegExp(r'\D'), '');
  if (tipo == 'Q') return digits.length > 2 ? digits.substring(0, 2) : digits;
  if (tipo == 'P' || tipo == 'S') {
    final d = digits.length > 4 ? digits.substring(0, 4) : digits;
    if (d.length <= 2) return d;
    return '${d.substring(0, 2)}-${d.substring(2)}';
  }
  if (tipo == 'T') {
    final d = digits.length > 6 ? digits.substring(0, 6) : digits;
    if (d.length <= 2) return d;
    if (d.length <= 4) return '${d.substring(0, 2)}-${d.substring(2)}';
    return '${d.substring(0, 2)}-${d.substring(2, 4)}-${d.substring(4)}';
  }
  return digits;
}

/// Máximo de dígitos por tipo (sin contar guiones).
int _maxDigitsForTipo(String tipo) => tipo == 'Q' ? 2 : (tipo == 'T' ? 6 : 4);

/// Convierte letra a betType del API.
String _betTypeFromTipo(String tipo) {
  switch (tipo) {
    case 'Q': return 'quiniela';
    case 'P': return 'pale';
    case 'T': return 'tripleta';
    case 'S': return 'superpale';
    default: return 'quiniela';
  }
}

/// Convierte betType del API a letra para mostrar.
String _tipoLetterFromBetType(String? betType) {
  switch (betType) {
    case 'quiniela': return 'Q';
    case 'pale': return 'P';
    case 'tripleta': return 'T';
    case 'superpale': return 'S';
    default: return 'Q';
  }
}

/// Formateador de entrada: solo dígitos y formato 00, 00-00 o 00-00-00 según tipo.
class _NumberFormatFormatter extends TextInputFormatter {
  _NumberFormatFormatter(this.tipo);
  final String tipo;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final max = _maxDigitsForTipo(tipo);
    final truncated = digits.length > max ? digits.substring(0, max) : digits;
    final formatted = _formatNumberByTipo(truncated, tipo);
    if (formatted == newValue.text) return newValue;
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final digitsBeforeCursor = newValue.text.substring(0, cursor).replaceAll(RegExp(r'\D'), '').length;
    final d = digitsBeforeCursor > max ? max : digitsBeforeCursor;
    int newOffset = formatted.length;
    if (tipo == 'Q') newOffset = d;
    else if (tipo == 'P' || tipo == 'S') newOffset = d <= 2 ? d : d + 1;
    else if (tipo == 'T') newOffset = d <= 2 ? d : (d <= 4 ? d + 1 : d + 2);
    if (newOffset > formatted.length) newOffset = formatted.length;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

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
  /// True mientras se cargan loterías y se registra el dispositivo al entrar en la pantalla.
  bool _loadingInitial = true;
  final _numberController = TextEditingController();
  final _amountController = TextEditingController(text: '50');
  /// Tipo de jugada: Q=Quiniela, P=Pale, T=Tripleta, S=Super Pale.
  String _tipoJugada = 'Q';

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
    _numberController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _addLine() {
    final numStr = _numberController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (numStr.isEmpty) {
      setState(() => _error = 'Ingrese el número');
      return;
    }
    if (_selectedLotteryId == null || _selectedDrawId == null) {
      setState(() => _error = 'Seleccione lotería y sorteo');
      return;
    }
    final minDigits = _tipoJugada == 'Q' ? 2 : (_tipoJugada == 'T' ? 6 : 4);
    if (numStr.length < minDigits) {
      setState(() => _error = 'Número incompleto. $minDigits dígitos para ${_tipoJugada == "Q" ? "Quiniela" : _tipoJugada == "T" ? "Tripleta" : "Pale/Super Pale"}.');
      return;
    }
    final amountRaw = _amountController.text.trim().replaceAll(RegExp(r'[^\d.]'), '');
    final amount = int.tryParse(amountRaw) ?? double.tryParse(amountRaw)?.toInt();
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Ingrese un monto válido');
      return;
    }
    final numbersFormatted = _formatNumberByTipo(numStr, _tipoJugada);
    setState(() {
      _error = null;
      _lines.add({
        'lotteryId': _selectedLotteryId,
        'drawId': _selectedDrawId,
        'betType': _betTypeFromTipo(_tipoJugada),
        'tipoLetter': _tipoJugada,
        'numbers': numbersFormatted,
        'amount': amount,
      });
      _numberController.clear();
    });
  }

  void _clearCart() {
    setState(() {
      _lines.clear();
      _error = null;
    });
  }

  void _goToPayment() {
    if (_lines.isEmpty) {
      setState(() => _error = 'Agregue al menos una jugada');
      return;
    }
    if (_selectedLotteryId == null || _selectedDrawId == null) {
      setState(() => _error = 'Seleccione lotería y sorteo');
      return;
    }
    final lotteryName = _lotteries.cast<Map<String, dynamic>?>().firstWhere((l) => l?['id'] == _selectedLotteryId, orElse: () => null)?['name']?.toString();
    final drawTime = _draws.cast<Map<String, dynamic>?>().firstWhere((d) => d?['id'] == _selectedDrawId, orElse: () => null)?['drawTime']?.toString() ?? '';
    final cartLines = _lines.map((l) => CartLine(
      lotteryId: l['lotteryId'] as String,
      drawId: l['drawId'] as String,
      betType: l['betType'] as String? ?? 'quiniela',
      numbers: l['numbers'] as String,
      amount: l['amount'] as num,
      lotteryName: lotteryName,
      drawTime: drawTime,
    )).toList();
    ref.read(sellCartProvider.notifier).setCart(cartLines, lotteryName: lotteryName, drawTime: drawTime);
    context.push('/payment');
  }

  Future<void> _initSessionAndLoad() async {
    if (!mounted) return;
    setState(() => _loadingInitial = true);
    try {
      final session = await ref.read(posSessionProvider.future);
      if (!session.hasPoint) {
        if (mounted) context.go('/select-point');
        return;
      }
      final api = ref.read(apiClientProvider);
      await api.refreshTokenIfExpiredOrSoon(minMinutes: 2);
      if (!mounted) return;
      await _loadLotteries();
      if (!mounted) return;
      final result = await _ensureDeviceRegistered();
      if (mounted) {
        setState(() {
          _deviceRegistered = result.ok;
          _registerDeviceError = result.error;
        });
      }
      _startHeartbeat();
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  /// Decodifica el payload del JWT (sin verificar firma) y devuelve texto de expiración para diagnóstico.
  static String _tokenExpiryForDiagnostic(String? token) {
    if (token == null || token.isEmpty) return 'Sin token';
    try {
      final parts = token.split('.');
      if (parts.length != 3) return 'Token con formato inválido';
      String payload = parts[1];
      payload += '=='.substring(0, (4 - payload.length % 4) % 4);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>?;
      final exp = map?['exp'];
      if (exp == null) return 'Token sin exp';
      final expSec = exp is int ? exp : (exp as num).toInt();
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      if (expSec <= now) {
        final minAgo = (now - expSec) ~/ 60;
        return 'Token EXPIRADO hace ~$minAgo min (por eso 401). Cierra sesión y entra de nuevo.';
      }
      final dt = DateTime.fromMillisecondsSinceEpoch(expSec * 1000, isUtc: true);
      final minLeft = (expSec - now) ~/ 60;
      return 'Token válido hasta ~${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} UTC ($minLeft min restantes)';
    } catch (_) {
      return 'No se pudo leer exp del token';
    }
  }

  /// Prueba conectividad: health (sin auth) y pos/points (con auth). Muestra resultado.
  Future<void> _runDiagnostic() async {
    setState(() => _diagnosticMessage = 'Probando…');
    final api = ref.read(apiClientProvider);
    final base = await api.effectiveBaseUrl;
    final session = await ref.read(posSessionProvider.future);
    final token = await api.token;
    final buffer = StringBuffer();
    buffer.writeln('Sesión:');
    buffer.writeln('  pointId=${session.pointId ?? "null"} (punto de venta)');
    buffer.writeln('  deviceId=${session.deviceId.length > 20 ? "${session.deviceId.substring(0, 20)}…" : session.deviceId} (terminal)');
    buffer.writeln('  (No se comparan entre sí: el backend valida pointId con tus puntos asignados y deviceId con el dispositivo.)');
    buffer.writeln('');
    buffer.writeln('Token: ${_tokenExpiryForDiagnostic(token)}');
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
          final canonical = _canonicalPointId(session.pointId);
          final ids = list.map((e) => ((e as Map)['id']?.toString() ?? '').trim().toLowerCase()).toList();
          final match = ids.contains(canonical);
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
    if (session.pointId != null && session.pointId!.isNotEmpty) {
      buffer.writeln('');
      final check = await _checkAssignment(_canonicalPointId(session.pointId));
      buffer.writeln('Check asignación: ${check.assigned ? "SÍ" : "NO"}');
      if (check.message != null) buffer.writeln('  → ${check.message}');
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

  /// Comprueba si el usuario tiene este punto asignado (mismo criterio que el backend).
  /// Devuelve statusCode para detectar 404 (backend sin esta ruta).
  Future<({bool assigned, String? message, int? statusCode})> _checkAssignment(String pointId) async {
    if (pointId.isEmpty) return (assigned: false, message: 'No hay pointId.', statusCode: null);
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.get('/pos/check-assignment', queryParams: {'pointId': pointId});
      if (resp.statusCode != 200) {
        String msg = _messageFromResponse(resp.body);
        if (resp.statusCode == 404 && msg.toLowerCase().contains('cannot get')) {
          msg = 'Backend desactualizado (falta ruta check-assignment). Actualiza el backend en el servidor.';
        }
        return (assigned: false, message: msg, statusCode: resp.statusCode);
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>?;
      final assigned = data?['assigned'] == true;
      final message = data?['message']?.toString();
      return (assigned: assigned, message: message, statusCode: resp.statusCode);
    } catch (_) {
      return (assigned: false, message: 'No se pudo verificar la asignación.', statusCode: null);
    }
  }

  /// Conexión en un solo flujo: (1) verificar asignación, (2) registrar dispositivo.
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
      // 1) Verificar asignación (si el backend tiene la ruta). Si 404, intentar registrar igual (backend antiguo).
      final check = await _checkAssignment(pointId);
      if (check.statusCode == 404) {
        if (kDebugMode) debugPrint('POS: check-assignment 404, trying register-device anyway (old backend)');
      } else if (!check.assigned) {
        if (mounted) setState(() => _registerDeviceStatus = check.statusCode ?? 403);
        return (ok: false, error: check.message ?? 'Este punto no está asignado a tu usuario.', status: check.statusCode ?? 403);
      } else if (kDebugMode) {
        debugPrint('POS: check-assignment OK, registering device pointId=$pointId deviceId=$deviceId');
      }
      // 2) Registrar dispositivo
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
      return (ok: false, error: msg.isNotEmpty ? msg : 'Error ${resp.statusCode}', status: resp.statusCode);
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
        final result = await _ensureDeviceRegistered();
        if (result.ok) {
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
      if (resp.statusCode >= 500) msg = 'Error del servidor (${resp.statusCode}). Puede ser fallo de conexión con la base de datos.';
      if (mounted) setState(() => _lotteriesError = 'Loterías (${resp.statusCode}): $msg');
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
        'pointId': _canonicalPointId(session.pointId),
        'deviceId': (session.deviceId).trim(),
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
    final timeAsync = ref.watch(serverTimeProvider);
    String lotteryName = 'Venta';
    if (_selectedLotteryId != null) {
      try {
        final l = _lotteries.firstWhere((e) => e['id'] == _selectedLotteryId);
        lotteryName = l['name']?.toString() ?? 'Venta';
      } catch (_) {}
    }
    String drawTimeStr = '';
    if (_selectedDrawId != null) {
      try {
        final d = _draws.firstWhere((e) => e['id'] == _selectedDrawId);
        drawTimeStr = d['drawTime']?.toString() ?? d['draw_time']?.toString() ?? '';
      } catch (_) {}
    }
    final subtitle = drawTimeStr.isNotEmpty ? '$lotteryName | Sorteo $drawTimeStr' : lotteryName;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home')),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('VENTA - $subtitle', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
            Text('Hora servidor RD: ${timeAsync.valueOrNull?.displayLabel ?? "—"}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Verificar conexión',
            onPressed: () async {
              setState(() => _diagnosticMessage = 'Probando…');
              await _runDiagnostic();
              if (!mounted) return;
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Diagnóstico de conexión'),
                  content: SingleChildScrollView(
                    child: SelectableText(_diagnosticMessage ?? 'Sin resultado', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.wifi_find),
          ),
          TextButton(onPressed: () => context.go('/history'), child: const Text('Historial')),
          TextButton(onPressed: () => context.go('/void'), child: const Text('Anular')),
          TextButton(onPressed: () => context.go('/closeout'), child: const Text('Cierre')),
        ],
      ),
      body: _loadingInitial
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text('Cargando loterías y datos…', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('Comprobando conexión con el servidor', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            )
          : ListView(
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
          const SizedBox(height: 16),
          const Text('Tipo de jugada', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final t in _tipoLetters)
                ChoiceChip(
                  label: Text(t, style: TextStyle(color: _tipoJugada == t ? Colors.white : AppColors.textPrimary)),
                  selected: _tipoJugada == t,
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _tipoJugada = t;
                      _numberController.clear();
                    }
                  }),
                  selectedColor: AppColors.secondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              const SizedBox(width: 8),
              Text('Q=Quiniela  P=Pale  T=Tripleta  S=Super Pale', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Entrada rápida', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _numberController,
                  decoration: InputDecoration(
                    labelText: 'Número',
                    hintText: _tipoJugada == 'Q' ? '00' : (_tipoJugada == 'T' ? '00-00-00' : '00-00'),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_maxDigitsForTipo(_tipoJugada)),
                    _NumberFormatFormatter(_tipoJugada),
                  ],
                  onSubmitted: (_) => _addLine(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Monto',
                    hintText: '50',
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  onSubmitted: (_) => _addLine(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Agregar'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
              ),
            ],
          ),
          if (_lines.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Jugadas', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 4),
            Card(
              color: AppColors.surface,
              child: Column(
                children: [
                  // Encabezado: Tipo | Número | Monto
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 28, child: Text('Tipo', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                        Expanded(child: Text('Número', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                        SizedBox(width: 56, child: Text('Monto', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  for (var i = 0; i < _lines.length; i++)
                    ListTile(
                      dense: true,
                      title: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(_tipoLetterFromBetType(_lines[i]['betType'] as String?), style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          Expanded(child: Text('${_lines[i]['numbers']}', style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace'))),
                          Text('\$${_lines[i]['amount']}', style: const TextStyle(color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                        Text('\$${_lines.fold<num>(0, (s, l) => s + (l['amount'] as num)).toStringAsFixed(0)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(onPressed: _clearCart, child: const Text('Limpiar')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => setState(() => _error = null), child: const Text('Validar')),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _goToPayment,
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Ir a Pago'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
                ),
              ],
            ),
          ],
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
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          setState(() => _lotteriesError = null);
                          await ref.read(apiClientProvider).refreshTokenIfExpiredOrSoon(minMinutes: 2);
                          await _loadLotteries();
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reintentar cargar loterías'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                      ),
                      if (_lotteriesStatus == 401) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                            await ref.read(apiClientProvider).setToken(null);
                            if (mounted) context.go('/login');
                          },
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Cerrar sesión'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                        ),
                      ],
                    ],
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
                  if (_registerDeviceStatus == 401) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        await ref.read(apiClientProvider).setToken(null);
                        if (mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Cerrar sesión e iniciar de nuevo'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    ),
                  ],
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
        ],
      ),
    );
  }
}
