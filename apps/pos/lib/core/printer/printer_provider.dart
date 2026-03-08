import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermal_printer_plus/thermal_printer.dart';

/// Impresora Bluetooth seleccionada (null si no hay).
final selectedPrinterProvider = StateProvider<PrinterDevice?>((_) => null);

/// Ancho de papel en mm: 58 o 80. Se configura al elegir la impresora.
final printerPaperWidthMmProvider = StateProvider<int>((_) => 80);

/// Ticket pendiente de imprimir en segundo plano (lo asigna Checkout al ir a /sell).
final pendingPrintTicketProvider = StateProvider<Map<String, dynamic>?>((_) => null);
