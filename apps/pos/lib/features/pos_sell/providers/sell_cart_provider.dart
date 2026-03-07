import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Una jugada del carrito (línea de ticket).
class CartLine {
  const CartLine({
    required this.lotteryId,
    required this.drawId,
    required this.betType,
    required this.numbers,
    required this.amount,
    this.lotteryName,
    this.drawTime,
  });

  final String lotteryId;
  final String drawId;
  final String betType;
  final String numbers;
  final num amount;
  final String? lotteryName;
  final String? drawTime;

  Map<String, dynamic> toTicketLine() {
    // El backend espera los números separados por espacio: "02 14" o "09 58 00".
    // En la UI usamos guiones ("02-14", "09-58-00"), así que aquí convertimos.
    final numbersForApi = numbers.replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return {
      'lotteryId': lotteryId,
      'drawId': drawId,
      'betType': betType,
      'numbers': numbersForApi,
      'amount': amount,
    };
  }
}

/// Estado del carrito de venta (para pasar a pantalla Pago).
class SellCartState {
  const SellCartState({
    this.lines = const [],
    this.lotteryName,
    this.drawTime,
  });

  final List<CartLine> lines;
  final String? lotteryName;
  final String? drawTime;

  double get total => lines.fold(0, (s, l) => s + (l.amount is int ? (l.amount as int).toDouble() : (l.amount as double)));
  bool get isEmpty => lines.isEmpty;
}

/// Provider del carrito: lo llena la pantalla Ventas y lo lee la pantalla Pago.
final sellCartProvider = StateNotifierProvider<SellCartNotifier, SellCartState>((ref) => SellCartNotifier());

/// Lo pone en true el Checkout antes de ir a /sell para que la pantalla de ventas limpie el formulario.
final clearSellFormAfterPaymentProvider = StateProvider<bool>((ref) => false);

class SellCartNotifier extends StateNotifier<SellCartState> {
  SellCartNotifier() : super(const SellCartState());

  void setCart(List<CartLine> lines, {String? lotteryName, String? drawTime}) {
    state = SellCartState(lines: lines, lotteryName: lotteryName, drawTime: drawTime);
  }

  void clear() {
    state = const SellCartState();
  }
}
