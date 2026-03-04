import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/http/api_client.dart';
import '../../../core/session/pos_session.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSessionAndLoad());
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
    _loadLotteries();
    await _ensureDeviceRegistered();
    _startHeartbeat();
  }

  /// Registra el dispositivo en el backend si no existe (para que el heartbeat funcione).
  Future<void> _ensureDeviceRegistered() async {
    try {
      final session = await ref.read(posSessionProvider.future);
      final api = ref.read(apiClientProvider);
      await api.post('/pos/register-device', body: {
        'deviceId': session.deviceId,
        'pointId': session.pointId,
      });
    } catch (_) {}
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: _heartbeatIntervalSeconds), (_) => _sendHeartbeat());
    _sendHeartbeat();
  }

  Future<void> _sendHeartbeat() async {
    try {
      final session = await ref.read(posSessionProvider.future);
      if (!session.hasPoint) return;
      final api = ref.read(apiClientProvider);
      final user = await ref.read(currentUserProvider.future);
      final userId = user?['id']?.toString();
      await api.post('/pos/heartbeat', body: {
        'deviceId': session.deviceId,
        'pointId': session.pointId,
        if (userId != null) 'sellerId': userId,
        'appVersion': '1.0.0',
      });
    } catch (_) {}
  }

  Future<void> _loadLotteries() async {
    final api = ref.read(apiClientProvider);
    final resp = await api.get('/lotteries');
    if (resp.statusCode == 200) {
      final data = _parseList(resp.body);
      setState(() => _lotteries = data);
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
          DropdownButtonFormField<String>(
            value: _selectedLotteryId,
            decoration: const InputDecoration(labelText: 'Lotería'),
            items: _lotteries.map((l) => DropdownMenuItem(value: l['id']?.toString(), child: Text(l['name']?.toString() ?? ''))).toList(),
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
            decoration: const InputDecoration(labelText: 'Sorteo'),
            items: _draws.map((d) => DropdownMenuItem(value: d['id']?.toString(), child: Text('${d['drawTime'] ?? d['draw_time']}'))).toList(),
            onChanged: _selectedLotteryId == null ? null : (v) => setState(() => _selectedDrawId = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _sell,
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Vender'),
          ),
        ],
      ),
    );
  }
}
