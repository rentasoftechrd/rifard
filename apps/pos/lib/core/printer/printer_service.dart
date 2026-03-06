import 'package:esc_pos_utils_updated/esc_pos_utils_updated.dart';

/// Construye los bytes ESC/POS del ticket para impresora Bluetooth.
/// Formato: Pto X, fecha/hora, Ticket no., líneas por lotería, Total.
Future<List<int>> buildTicketBytes(Map<String, dynamic> ticket) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm80, profile);
  List<int> bytes = [];

  final point = ticket['point'] as Map<String, dynamic>?;
  final pointLabel = point != null
      ? (point['name']?.toString() ?? point['code']?.toString() ?? 'Pto')
      : 'Pto';
  final ticketCode = ticket['ticketCode'] ?? ticket['ticket_code'] ?? '';
  final totalAmount = ticket['totalAmount'] ?? ticket['total_amount'] ?? 0;
  String dateStr = '';
  String timeStr = '';
  final created = ticket['createdAt'] ?? ticket['created_at'];
  if (created != null) {
    try {
      final dt = DateTime.tryParse(created.toString());
      if (dt != null) {
        dateStr =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
        timeStr =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
  }
  if (dateStr.isEmpty) dateStr = '--/--/----';
  if (timeStr.isEmpty) timeStr = '--:--:--';

  bytes += generator.reset();
  bytes += generator.text('Pto $pointLabel',
      styles: PosStyles(align: PosAlign.center, bold: true), linesAfter: 0);
  bytes += generator.text('$dateStr : $timeStr',
      styles: PosStyles(align: PosAlign.center), linesAfter: 0);
  bytes += generator.text('Ticket no.: $ticketCode',
      styles: PosStyles(align: PosAlign.center), linesAfter: 1);
  bytes += generator.hr(ch: '-', linesAfter: 1);

  final lines = ticket['lines'] as List<dynamic>? ?? [];
  if (lines.isEmpty) {
    bytes += generator.text('Sin jugadas', linesAfter: 1);
  } else {
    String? lastLotteryName;
    for (final line in lines) {
      final map = line is Map
          ? Map<String, dynamic>.from(line as Map)
          : <String, dynamic>{};
      final lottery = map['lottery'] as Map<String, dynamic>?;
      final lotteryName = lottery?['name']?.toString() ?? 'Lotería';
      if (lastLotteryName != lotteryName) {
        if (lastLotteryName != null) bytes += generator.emptyLines(1);
        bytes += generator.text(lotteryName,
            styles: PosStyles(bold: true), linesAfter: 0);
        lastLotteryName = lotteryName;
      }
      final betType =
          _betTypeLabel(map['betType'] ?? map['bet_type'] ?? 'quiniela');
      final numbers = map['numbers']?.toString() ?? '';
      final amount = map['amount'] ?? map['potentialPayout'] ?? 0;
      final amountStr = _formatAmount(amount);
      final desc = '$betType $numbers';
      bytes += generator.row([
        PosColumn(text: desc, width: 7),
        PosColumn(
            text: amountStr,
            width: 3,
            styles: PosStyles(align: PosAlign.right)),
      ]);
    }
  }

  bytes += generator.hr(ch: '-', linesAfter: 1);
  bytes += generator.row([
    PosColumn(text: 'Total', width: 6, styles: PosStyles(bold: true)),
    PosColumn(
      text: _formatAmount(totalAmount),
      width: 4,
      styles: PosStyles(align: PosAlign.right, bold: true),
    ),
  ]);
  bytes += generator.feed(2);
  bytes += generator.cut();

  return bytes;
}

String _betTypeLabel(dynamic bt) {
  final s = bt.toString().toLowerCase();
  if (s == 'quiniela') return 'Quiniela';
  if (s == 'pale') return 'Pale';
  if (s == 'tripleta') return 'Tripleta';
  if (s == 'superpale') return 'Super Pale';
  return 'Quiniela';
}

String _formatAmount(dynamic a) {
  if (a == null) return '0.00';
  final n = a is num ? a.toDouble() : (double.tryParse(a.toString()) ?? 0);
  return n.toStringAsFixed(2);
}
