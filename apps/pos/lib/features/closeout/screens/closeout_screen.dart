import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/http/api_client.dart';
import '../../../core/session/pos_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/server_time/server_time_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Pantalla Cuadre/Cierre: rango (fecha servidor), resumen Ventas, Anulaciones, Net, Tickets. Hora servidor RD.
class CloseoutScreen extends ConsumerStatefulWidget {
  const CloseoutScreen({super.key});

  @override
  ConsumerState<CloseoutScreen> createState() => _CloseoutScreenState();
}

class _CloseoutScreenState extends ConsumerState<CloseoutScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = await ref.read(posSessionProvider.future);
    if (!session.hasPoint) {
      if (mounted) setState(() { _error = 'Seleccione un punto.'; _loading = false; });
      return;
    }
    final timeResp = await ref.read(apiClientProvider).get('/health/time');
    String dateStr = DateTime.now().toIso8601String().substring(0, 10);
    if (timeResp.statusCode == 200 && timeResp.body.isNotEmpty) {
      try {
        final t = json.decode(timeResp.body) as Map<String, dynamic>?;
        if (t?['serverDate'] != null) dateStr = t!['serverDate'] as String;
      } catch (_) {}
    }
    setState(() { _error = null; _loading = true; });
    try {
      final api = ref.read(apiClientProvider);
      final pointId = (session.pointId ?? '').trim().toLowerCase();
      final resp = await api.get('/pos/closeout', queryParams: {'date': dateStr, 'pointId': pointId});
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final data = json.decode(resp.body) as Map<String, dynamic>?;
        if (mounted) setState(() { _data = data; _loading = false; });
      } else {
        final msg = _messageFromBody(resp.body);
        if (mounted) setState(() { _error = msg ?? 'Error ${resp.statusCode}'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String? _messageFromBody(String body) {
    try {
      final m = json.decode(body) as Map<String, dynamic>?;
      return m?['message']?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeAsync = ref.watch(serverTimeProvider);
    final date = _data?['date']?.toString() ?? '—';
    final salesAmount = (_data?['sales'] as Map?)?['totalAmount'];
    final ticketCount = (_data?['sales'] as Map?)?['ticketCount'] ?? 0;
    final voidsCount = (_data?['voids'] as Map?)?['count'] ?? 0;
    final voidsAmount = (_data?['voids'] as Map?)?['totalAmount'];
    final net = _data?['net'];
    final salesTotal = salesAmount is num ? salesAmount.toDouble() : 0.0;
    final voidsTotal = voidsAmount is num ? voidsAmount.toDouble() : 0.0;
    final netTotal = net is num ? net.toDouble() : (salesTotal - voidsTotal);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home')),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('CUADRE DE TURNO'),
            Text('Hora servidor RD: ${timeAsync.valueOrNull?.displayLabel ?? "—"}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary)),
                        const SizedBox(height: 24),
                        FilledButton(onPressed: _load, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text('Rango', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('$date 12:00 AM — $date 11:59 PM', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 24),
                    const Text('Resumen', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 12),
                    Card(
                      color: AppColors.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _row('Ventas:', '\$${salesTotal.toStringAsFixed(0)}'),
                            _row('Anulaciones:', '-\$${voidsTotal.toStringAsFixed(0)} ($voidsCount)'),
                            const Divider(height: 24),
                            _row('Net:', '\$${netTotal.toStringAsFixed(0)}', bold: true),
                            _row('Tickets:', '$ticketCount'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _load,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Generar reporte'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cierre de turno registrado (implementar POST si se requiere)')));
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondary, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Cerrar turno'),
                    ),
                  ],
                ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textMuted, fontWeight: bold ? FontWeight.w600 : null)),
          Text(value, style: TextStyle(color: AppColors.textPrimary, fontWeight: bold ? FontWeight.bold : null)),
        ],
      ),
    );
  }
}
