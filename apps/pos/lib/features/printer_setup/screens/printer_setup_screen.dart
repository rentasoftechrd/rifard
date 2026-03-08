import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thermal_printer_plus/thermal_printer.dart';
import '../../../core/printer/printer_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Configurar impresora: escanear Bluetooth, seleccionar dispositivo y conectar.
class PrinterSetupScreen extends ConsumerStatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  ConsumerState<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends ConsumerState<PrinterSetupScreen> {
  final List<PrinterDevice> _devices = [];
  bool _scanning = false;
  StreamSubscription<PrinterDevice>? _scanSub;

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();
  }

  void _startScan() async {
    await _requestPermissions();
    setState(() {
      _devices.clear();
      _scanning = true;
    });
    _scanSub = PrinterManager.instance
        .discovery(type: PrinterType.bluetooth, isBle: false)
        .listen((device) {
      if (!mounted) return;
      final addr = device.address;
      if (addr != null && addr.isNotEmpty && !_devices.any((d) => d.address == addr)) {
        setState(() => _devices.add(device));
      }
    });
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        _scanSub?.cancel();
        setState(() => _scanning = false);
      }
    });
  }

  void _stopScan() {
    _scanSub?.cancel();
    setState(() => _scanning = false);
  }

  Future<void> _selectPrinter(PrinterDevice device) async {
    final connected = await PrinterManager.instance.connect(
      type: PrinterType.bluetooth,
      model: BluetoothPrinterInput(
        address: device.address ?? '',
        name: device.name,
        isBle: false,
        autoConnect: false,
      ),
    );
    if (!mounted) return;
    if (!connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar. Intente de nuevo.')),
      );
      return;
    }
    // Pedir ancho de papel para ajustar la impresión
    final paperMm = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ancho de papel'),
        content: const Text(
          'Seleccione el ancho del rollo de su impresora para que el ticket se ajuste correctamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(58),
            child: const Text('58 mm'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(80),
            child: const Text('80 mm'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final width = paperMm ?? 80;
    ref.read(selectedPrinterProvider.notifier).state = device;
    ref.read(printerPaperWidthMmProvider.notifier).state = width;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conectado: ${device.name} · Papel $width mm'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedPrinterProvider);
    final paperMm = ref.watch(printerPaperWidthMmProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar impresora')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Conecte una impresora térmica Bluetooth (ESC/POS). Busque dispositivos y toque uno para seleccionarla.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 16),
          if (selected != null)
            Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Conectado a',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                          Text(selected.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          Text('Papel: ${paperMm}mm',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _scanning ? null : _startScan,
            icon: _scanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.bluetooth_searching),
            label: Text(_scanning ? 'Buscando...' : 'Buscar impresoras'),
          ),
          if (_scanning)
            TextButton(
              onPressed: _stopScan,
              child: const Text('Detener búsqueda'),
            ),
          const SizedBox(height: 24),
          if (_devices.isEmpty && !_scanning)
            Center(
                child: Text('No se encontraron dispositivos',
                    style: TextStyle(color: AppColors.textMuted))),
          if (_devices.isNotEmpty) ...[
            const Text('Dispositivos encontrados',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._devices.map((printer) => ListTile(
                  leading: const Icon(Icons.print),
                  title: Text(printer.name),
                  subtitle: Text(printer.address ?? ''),
                  onTap: () => _selectPrinter(printer),
                )),
          ],
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Volver al menú'),
          ),
        ],
      ),
    );
  }
}
