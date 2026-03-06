import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermal_printer_plus/thermal_printer.dart';

/// Impresora Bluetooth seleccionada (null si no hay).
final selectedPrinterProvider = StateProvider<PrinterDevice?>((_) => null);
