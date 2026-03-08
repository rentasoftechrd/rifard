/// DTO usado para construir el ticket de impresión (agrupado por lotería, con date/time ya formateados).
class TicketPrintModel {
  const TicketPrintModel({
    required this.ticketNumber,
    required this.date,
    required this.time,
    required this.terminal,
    required this.cashier,
    required this.groups,
    required this.total,
    required this.barcodeValue,
    required this.qrValue,
    required this.notes,
  });

  final String ticketNumber;
  final String date;
  final String time;
  final String terminal;
  final String cashier;
  final List<TicketPrintGroup> groups;
  final num total;
  final String barcodeValue;
  final String qrValue;
  final List<String> notes;

  /// Construye el modelo a partir de la respuesta del API (ticket con lines, point, seller, date, time, qrValue).
  static TicketPrintModel fromApiTicket(Map<String, dynamic> ticket) {
    final ticketNumber =
        ticket['ticketNumber']?.toString() ?? ticket['ticket_code']?.toString() ?? ticket['ticketCode']?.toString() ?? '';
    final date = ticket['date']?.toString() ?? '--/--/----';
    final time = ticket['time']?.toString() ?? '--:--';
    final point = ticket['point'] as Map<String, dynamic>?;
    final terminal = point != null
        ? (point['name']?.toString() ?? point['code']?.toString() ?? 'POS')
        : 'POS';
    final seller = ticket['seller'] as Map<String, dynamic>?;
    final cashier = seller?['fullName']?.toString() ?? '';

    final totalAmount = ticket['totalAmount'] ?? ticket['total_amount'] ?? 0;
    final total = totalAmount is num ? totalAmount : (double.tryParse(totalAmount.toString()) ?? 0);

    final qrValue = ticket['qrValue']?.toString() ?? '';
    final barcodeValue = ticketNumber.isNotEmpty ? ticketNumber : qrValue.split('/').last;

    final lines = ticket['lines'] as List<dynamic>? ?? [];
    final groups = _groupLinesByLottery(lines);

    const defaultNotes = [
      'NO SE PAGA SIN TICKET',
      'NO SE ANULAN TICKETS DESPUES DE 5 MINUTOS',
      'VERIFIQUE SU JUGADA ANTES DE RETIRARSE',
    ];
    final notesList = ticket['notes'] as List<dynamic>?;
    final notes = notesList != null && notesList.isNotEmpty
        ? notesList.map((e) => e.toString()).toList()
        : defaultNotes;

    return TicketPrintModel(
      ticketNumber: ticketNumber,
      date: date,
      time: time,
      terminal: terminal,
      cashier: cashier,
      groups: groups,
      total: total,
      barcodeValue: barcodeValue,
      qrValue: qrValue.isNotEmpty ? qrValue : 'https://ejemplo.com/t/$barcodeValue',
      notes: notes,
    );
  }
}

class TicketPrintGroup {
  const TicketPrintGroup({
    required this.lotteryName,
    required this.subtotal,
    required this.plays,
  });

  final String lotteryName;
  final num subtotal;
  final List<TicketPrintPlay> plays;
}

class TicketPrintPlay {
  const TicketPrintPlay({
    required this.playType,
    required this.number,
    required this.amount,
  });

  final String playType;
  final String number;
  final num amount;
}

List<TicketPrintGroup> _groupLinesByLottery(List<dynamic> lines) {
  final byLottery = <String, List<Map<String, dynamic>>>{};
  for (final line in lines) {
    final map = line is Map ? Map<String, dynamic>.from(line as Map) : <String, dynamic>{};
    final lottery = map['lottery'] as Map<String, dynamic>?;
    final name = lottery?['name']?.toString() ?? 'Lotería';
    byLottery.putIfAbsent(name, () => []).add(map);
  }
  return byLottery.entries.map((e) {
    final plays = e.value.map((line) {
      final betType = line['betType'] ?? line['bet_type'] ?? 'quiniela';
      final playType = _betTypeToAbbrev(betType.toString());
      final numbers = line['numbers']?.toString() ?? '';
      final amount = line['amount'] ?? line['potentialPayout'] ?? 0;
      final amt = amount is num ? amount : (double.tryParse(amount.toString()) ?? 0);
      return TicketPrintPlay(playType: playType, number: numbers, amount: amt);
    }).toList();
    final subtotal = plays.fold<num>(0, (s, p) => s + p.amount);
    return TicketPrintGroup(lotteryName: e.key, subtotal: subtotal, plays: plays);
  }).toList();
}

String _betTypeToAbbrev(String bt) {
  final s = bt.toLowerCase();
  if (s == 'quiniela') return 'Q';
  if (s == 'pale') return 'P';
  if (s == 'tripleta') return 'T';
  if (s == 'superpale') return 'SP';
  return 'Q';
}
