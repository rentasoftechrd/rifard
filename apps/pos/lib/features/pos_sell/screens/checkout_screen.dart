import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thermal_printer_plus/thermal_printer.dart';
import '../../../core/http/api_client.dart';
import '../../../core/printer/printer_provider.dart';
import '../../../core/printer/printer_service.dart';
import '../../../core/session/pos_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/server_time/server_time_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/sell_cart_provider.dart';

/// Pantalla Pago: total, método (Efectivo/Otro), Recibido, Devuelta. Confirmar Pago → POST /tickets.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _efectivo = true;
  final _recibidoController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _recibidoController.dispose();
    super.dispose();
  }

  double _recibidoValue() => double.tryParse(_recibidoController.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  double _devueltaValue(double total) => _recibidoValue() - total;

  static String _extractErrorMessage(Map<String, dynamic> data, int statusCode) {
    final m = data['message'];
    if (m == null) return 'Error $statusCode';
    if (m is String) return m;
    if (m is Map) {
      final s = m['message'] ?? m['detail'];
      return s?.toString() ?? 'Error $statusCode';
    }
    return m.toString();
  }

  /// Envía el ticket a la impresora configurada. Devuelve true si imprimió, false si no hay impresora o falló.
  Future<bool> _printTicketIfConfigured(Map<String, dynamic> ticketData) async {
    final selected = ref.read(selectedPrinterProvider);
    if (selected == null || selected.address == null || selected.address!.isEmpty) return false;
    try {
      final bytes = await buildTicketBytes(ticketData);
      if (bytes.isEmpty) return false;
      await Future.delayed(const Duration(milliseconds: 300));
      final connected = await PrinterManager.instance.connect(
        type: PrinterType.bluetooth,
        model: BluetoothPrinterInput(
          address: selected.address!,
          name: selected.name,
          isBle: false,
          autoConnect: false,
        ),
      );
      if (!connected) return false;
      final ok = await PrinterManager.instance.send(type: PrinterType.bluetooth, bytes: bytes);
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> _confirmarPago() async {
    final cart = ref.read(sellCartProvider);
    if (cart.isEmpty) {
      setState(() => _error = 'No hay jugadas. Vuelva a Ventas.');
      return;
    }
    final session = await ref.read(posSessionProvider.future);
    if (!session.hasPoint) {
      setState(() => _error = 'Sesión sin punto. Vuelva al menú.');
      return;
    }
    final total = cart.total;
    if (_efectivo && _recibidoValue() < total) {
      setState(() => _error = 'Recibido debe ser mayor o igual al total.');
      return;
    }
    setState(() { _error = null; _loading = true; });
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.post('/tickets', body: {
        'pointId': (session.pointId ?? '').trim().toLowerCase(),
        'deviceId': (session.deviceId).trim(),
        'lines': cart.lines.map((l) => l.toTicketLine()).toList(),
      });
      final data = resp.body.isNotEmpty ? json.decode(resp.body) as Map<String, dynamic> : <String, dynamic>{};
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        // Ticket guardado en BD. Obtener ticket completo para imprimir (misma forma que detalle).
        Map<String, dynamic>? ticketForPrint = data;
        final code = data['ticketCode'] ?? data['ticket_code']?.toString();
        if (code != null && code.toString().isNotEmpty) {
          try {
            final getResp = await api.get('/tickets/code/${code.toString()}');
            if (getResp.statusCode == 200 && getResp.body.isNotEmpty) {
              ticketForPrint = json.decode(getResp.body) as Map<String, dynamic>?;
            }
          } catch (_) {}
        }
        ref.read(sellCartProvider.notifier).clear();
        if (mounted) {
          setState(() => _loading = false);
          final printed = ticketForPrint != null ? await _printTicketIfConfigured(ticketForPrint) : false;
          if (mounted) {
            if (!printed) {
              final hasPrinter = ref.read(selectedPrinterProvider) != null;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    hasPrinter
                        ? 'Ticket guardado. No se pudo imprimir.'
                        : 'Ticket guardado. Configure una impresora en menú para imprimir.',
                  ),
                ),
              );
            }
            ref.read(clearSellFormAfterPaymentProvider.notifier).state = true;
            context.go('/sell');
          }
        }
      } else {
        String msg = _extractErrorMessage(data, resp.statusCode);
        if (resp.statusCode >= 500 && resp.body.isNotEmpty) {
          try {
            final decoded = json.decode(resp.body) as Map<String, dynamic>?;
            if (decoded != null) {
              final extracted = _extractErrorMessage(decoded, resp.statusCode);
              if (extracted.isNotEmpty && extracted != 'Error ${resp.statusCode}') msg = extracted;
              else msg = 'Error del servidor (${resp.statusCode}). Revisa backend y datos del ticket.';
            } else {
              msg = 'Error del servidor (${resp.statusCode}). Revisa backend y datos del ticket.';
            }
          } catch (_) {
            msg = 'Error del servidor (${resp.statusCode}). Revisa logs del backend.';
          }
        }
        if (mounted) setState(() {
          _error = msg;
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
    final cart = ref.watch(sellCartProvider);
    final timeAsync = ref.watch(serverTimeProvider);

    if (cart.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/sell');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('PAGO'),
            Text('Hora servidor RD: ${timeAsync.valueOrNull?.displayLabel ?? "—"}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text('\$${cart.total.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Método de pago', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Radio<bool>(value: true, groupValue: _efectivo, onChanged: (v) => setState(() => _efectivo = true), activeColor: AppColors.primary),
              const Text('Efectivo', style: TextStyle(color: AppColors.textPrimary)),
              const SizedBox(width: 24),
              Radio<bool>(value: false, groupValue: _efectivo, onChanged: (v) => setState(() => _efectivo = false), activeColor: AppColors.primary),
              const Text('Otro', style: TextStyle(color: AppColors.textPrimary)),
            ],
          ),
          if (_efectivo) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _recibidoController,
              decoration: const InputDecoration(labelText: 'Recibido', hintText: '0'),
              style: const TextStyle(color: AppColors.textPrimary),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            if (_recibidoValue() >= cart.total && cart.total > 0) ...[
              const SizedBox(height: 8),
              Text('Devuelta: \$${_devueltaValue(cart.total).toStringAsFixed(0)}', style: const TextStyle(color: AppColors.secondary, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _loading ? null : _confirmarPago,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _loading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Confirmar Pago'),
          ),
        ],
      ),
    );
  }
}
