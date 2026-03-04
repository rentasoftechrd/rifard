import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/sell')),
      ),
      body: const Center(child: Text('Lista de tickets del día (implementar con API /reports/daily-sales)')),
    );
  }
}
