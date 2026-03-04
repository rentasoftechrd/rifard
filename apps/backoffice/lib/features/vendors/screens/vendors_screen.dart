import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_shell.dart';

class VendorsScreen extends ConsumerWidget {
  const VendorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      currentPath: '/vendors',
      child: ListView(padding: const EdgeInsets.all(24), children: [
        Text('Vendedores', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Lista sellers, comisión %, puntos asignados'))),
      ]),
    );
  }
}
