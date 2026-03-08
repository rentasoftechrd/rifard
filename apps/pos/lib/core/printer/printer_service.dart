import 'package:esc_pos_utils_updated/esc_pos_utils_updated.dart';
import 'package:thermal_printer_plus/thermal_printer.dart';

import 'ticket_print_model.dart';

/// Envía el ticket a la impresora Bluetooth. Desconecta, reconecta y espera antes de enviar (mejor compatibilidad Android).
Future<bool> sendTicketToPrinter(Map<String, dynamic> ticketData, dynamic printerDevice,
    {int paperWidthMm = 80}) async {
  final address = printerDevice.address?.toString();
  if (address == null || address.isEmpty) return false;
  try {
    final bytes = await buildTicketBytes(ticketData, paperWidthMm: paperWidthMm);
    if (bytes.isEmpty) return false;
    try {
      await PrinterManager.instance.disconnect(type: PrinterType.bluetooth);
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (_) {}
    final connected = await PrinterManager.instance.connect(
      type: PrinterType.bluetooth,
      model: BluetoothPrinterInput(
        address: address,
        name: printerDevice.name,
        isBle: false,
        autoConnect: true,
      ),
    );
    if (!connected) return false;
    await Future.delayed(const Duration(milliseconds: 600));
    final ok = await PrinterManager.instance.send(type: PrinterType.bluetooth, bytes: bytes);
    return ok;
  } catch (_) {
    return false;
  }
}

/// Ancho en caracteres aproximado (monoespaciado): 58mm ~ 32, 80mm ~ 48.
int _charsPerLine(int paperWidthMm) => paperWidthMm == 58 ? 32 : 48;

/// Construye los bytes ESC/POS del ticket. Soporta 58mm y 80mm.
/// Usa el diseño oficial: encabezado, ticket/date/time/terminal/cajero, jugadas por lotería, total, QR, barcode, notas.
Future<List<int>> buildTicketBytes(Map<String, dynamic> ticket, {int paperWidthMm = 80}) async {
  final model = TicketPrintModel.fromApiTicket(ticket);
  final paperSize = paperWidthMm == 58 ? PaperSize.mm58 : PaperSize.mm80;
  final profile = await CapabilityProfile.load();
  final generator = Generator(paperSize, profile);
  final chars = _charsPerLine(paperWidthMm);
  List<int> bytes = [];

  String sepEq() => '=' * chars;
  String sepDash() => '-' * chars;

  bytes += generator.reset();

  // ----- Encabezado -----
  bytes += generator.text(sepEq(), linesAfter: 0);
  bytes += generator.text('LOTERIA R', styles: PosStyles(align: PosAlign.center, bold: true), linesAfter: 0);
  bytes += generator.text('Sistema Autorizado', styles: PosStyles(align: PosAlign.center), linesAfter: 0);
  bytes += generator.text(sepEq(), linesAfter: 1);

  bytes += generator.text('Ticket   : ${model.ticketNumber}', linesAfter: 0);
  bytes += generator.text('Fecha    : ${model.date}', linesAfter: 0);
  bytes += generator.text('Hora     : ${model.time}', linesAfter: 0);
  bytes += generator.text('Terminal : ${model.terminal}', linesAfter: 0);
  bytes += generator.text('Cajero   : ${model.cashier}', linesAfter: 1);

  bytes += generator.hr(ch: '-', linesAfter: 0);
  bytes += generator.text('JUGADAS', styles: PosStyles(align: PosAlign.center, bold: true), linesAfter: 0);
  bytes += generator.hr(ch: '-', linesAfter: 1);

  // ----- Jugadas por lotería -----
  // PosColumn width is 1..12 (units of 1/12 of line)
  const wJgo = 2;
  const wNumero = 6;
  const wApuesta = 4;
  for (final group in model.groups) {
    bytes += generator.text('LOTERIA: ${group.lotteryName.toUpperCase()}',
        styles: PosStyles(bold: true), linesAfter: 1);
    bytes += generator.row([
      PosColumn(text: 'JGO', width: wJgo, styles: PosStyles(bold: true)),
      PosColumn(text: 'NUMERO', width: wNumero, styles: PosStyles(bold: true)),
      PosColumn(text: 'APUESTA', width: wApuesta, styles: PosStyles(align: PosAlign.right, bold: true)),
    ]);
    for (final play in group.plays) {
      bytes += generator.row([
        PosColumn(text: play.playType, width: wJgo),
        PosColumn(text: play.number, width: wNumero),
        PosColumn(text: _formatAmount(play.amount), width: wApuesta, styles: PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr(ch: '-', linesAfter: 0);
    bytes += generator.row([
      PosColumn(text: 'SUBTOTAL', width: wJgo + wNumero, styles: PosStyles(bold: true)),
      PosColumn(text: _formatAmount(group.subtotal), width: wApuesta, styles: PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += generator.emptyLines(1);
  }

  // ----- Total -----
  bytes += generator.text(sepEq(), linesAfter: 0);
  bytes += generator.row([
    PosColumn(text: 'TOTAL', width: wJgo + wNumero, styles: PosStyles(bold: true)),
    PosColumn(text: _formatAmount(model.total), width: wApuesta, styles: PosStyles(align: PosAlign.right, bold: true)),
  ]);
  bytes += generator.text(sepEq(), linesAfter: 1);

  // ----- QR -----
  bytes += generator.text('ESCANEA PARA VALIDAR', styles: PosStyles(align: PosAlign.center), linesAfter: 1);
  try {
    final qrSize = paperWidthMm == 58 ? QRSize.Size3 : QRSize.Size4;
    bytes += generator.qrcode(model.qrValue, align: PosAlign.center, size: qrSize, cor: QRCorrection.M);
  } catch (_) {
    bytes += generator.text('[QR: ${model.qrValue}]', styles: PosStyles(align: PosAlign.center, fontType: PosFontType.fontB));
  }
  bytes += generator.emptyLines(1);

  // ----- Barcode: valor legible (muchas impresoras no dibujan CODE128 bien con este driver) -----
  bytes += generator.text(model.barcodeValue, styles: PosStyles(align: PosAlign.center), linesAfter: 0);
  bytes += generator.text('CODE 128', styles: PosStyles(align: PosAlign.center), linesAfter: 1);

  bytes += generator.hr(ch: '-', linesAfter: 0);
  for (final note in model.notes) {
    bytes += generator.text(
      note,
      styles: PosStyles(align: PosAlign.center),
      linesAfter: 0,
      maxCharsPerLine: chars,
    );
  }
  bytes += generator.hr(ch: '-', linesAfter: 0);
  bytes += generator.text('GRACIAS POR JUGAR', styles: PosStyles(align: PosAlign.center, bold: true), linesAfter: 0);
  bytes += generator.text(sepEq(), linesAfter: 1);
  bytes += generator.feed(2);
  bytes += generator.cut();

  return bytes;
}

String _formatAmount(num a) {
  if (a == a.truncate()) return '\$${a.toInt()}';
  return '\$${a.toStringAsFixed(2)}';
}
