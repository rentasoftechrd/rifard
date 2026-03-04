import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_shell.dart';

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      currentPath: '/audit',
      child: ListView(padding: const EdgeInsets.all(24), children: [
        Text('Auditoría', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Filtro fechas, action, actor, entity; export CSV'))),
      ]),
    );
  }
}
