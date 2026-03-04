import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Printer setup: Bluetooth thermal printer (ESC/POS).
/// For production, use esc_pos_bluetooth_updated or fix namespace in flutter_bluetooth_basic.
class PrinterSetupScreen extends ConsumerWidget {
  const PrinterSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar impresora')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Conecte una impresora térmica Bluetooth (ESC/POS). '
            'En producción use el paquete esc_pos_bluetooth_updated o configure el plugin.',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/sell'),
            child: const Text('Continuar a venta'),
          ),
        ],
      ),
    );
  }
}
