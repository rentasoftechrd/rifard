import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thermal_printer_plus/thermal_printer.dart';
import '../../../core/http/api_client.dart';
import '../../../core/printer/printer_provider.dart';
import '../../../core/printer/printer_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({super.key, required this.code});
  final String code;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  Map<String, dynamic>? _ticket;
  bool _loading = true;
  String? _error;
  bool _printing = false;
  String? _printMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _printTicket() async {
    if (_ticket == null) return;
    final selected = ref.read(selectedPrinterProvider);
    if (selected == null || selected.address == null || selected.address!.isEmpty) {
      setState(() => _printMessage = 'Seleccione una impresora en Configurar impresora');
      return;
    }
    setState(() {
      _printing = true;
      _printMessage = null;
    });
    try {
      final bytes = await buildTicketBytes(_ticket!);
      final connected = await PrinterManager.instance.connect(
        type: PrinterType.bluetooth,
        model: BluetoothPrinterInput(
          address: selected.address!,
          name: selected.name,
          isBle: false,
          autoConnect: false,
        ),
      );
      if (!connected && mounted) {
        setState(() {
          _printing = false;
          _printMessage = 'No se pudo conectar a la impresora.';
        });
        return;
      }
      final ok = await PrinterManager.instance.send(
        type: PrinterType.bluetooth,
        bytes: bytes,
      );
      if (mounted) {
        setState(() {
          _printing = false;
          _printMessage = ok ? 'Impreso correctamente' : 'Error al enviar a la impresora';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _printing = false;
          _printMessage = 'Error: $e';
        });
      }
    }
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    final resp = await api.get('/tickets/code/${widget.code}');
    if (resp.statusCode == 200) {
      setState(() {
        _ticket = Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
        _loading = false;
      });
    } else {
      setState(() {
        _error = 'Ticket no encontrado';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ticket')),
        body: Center(child: Text(_error!)),
      );
    }
    final t = _ticket!;
    final point = t['point'] as Map<String, dynamic>?;
    final pointLabel = point != null ? (point['name'] ?? point['code'] ?? '') : '';
    final lines = t['lines'] as List<dynamic>? ?? [];
    String? lastLottery;

    return Scaffold(
      appBar: AppBar(title: Text('Ticket ${t['ticketCode'] ?? widget.code}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (pointLabel.isNotEmpty) Text('Pto $pointLabel', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Código: ${t['ticketCode'] ?? ''}'),
          Text('Total: \$${t['totalAmount'] ?? '0'}'),
          Text('Estado: ${t['status'] ?? ''}'),
          const SizedBox(height: 12),
          const Divider(),
          ...lines.map<Widget>((line) {
            final map = line is Map ? Map<String, dynamic>.from(line as Map) : <String, dynamic>{};
            final lottery = map['lottery'] as Map<String, dynamic>?;
            final lotteryName = lottery?['name']?.toString() ?? 'Lotería';
            final showLottery = lastLottery != lotteryName;
            if (showLottery) lastLottery = lotteryName;
            final betType = map['betType'] ?? map['bet_type'] ?? 'quiniela';
            final numbers = map['numbers'] ?? '';
            final am = map['amount'] ?? map['potentialPayout'] ?? 0;
            final amountNum = am is num ? am.toDouble() : (double.tryParse(am.toString()) ?? 0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showLottery) Text(lotteryName, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.secondary)),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('$betType $numbers  \$${amountNum.toStringAsFixed(2)}'),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          if (_printMessage != null)
            Text(_printMessage!,
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          FilledButton.icon(
            onPressed: _printing ? null : _printTicket,
            icon: _printing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print),
            label: Text(_printing ? 'Imprimiendo...' : 'Imprimir ticket'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go('/sell'),
            child: const Text('Nueva venta'),
          ),
        ],
      ),
    );
  }
}

