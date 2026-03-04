import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CloseoutScreen extends ConsumerWidget {
  const CloseoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre del día'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/sell')),
      ),
      body: const Center(
        child: Text('Resumen: ventas, tickets, anulaciones, comisión (implementar con API /reports/daily-sales y /reports/commissions)'),
      ),
    );
  }
}
