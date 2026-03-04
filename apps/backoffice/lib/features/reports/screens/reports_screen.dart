import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_shell.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      currentPath: '/reports',
      child: ListView(padding: const EdgeInsets.all(24), children: [
        Text('Reportes', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Daily Sales | Commissions | Voids | Exposure'))),
      ]),
    );
  }
}
