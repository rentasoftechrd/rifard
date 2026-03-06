import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/server_time/server_time_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Pantalla Pagos / Cobros. Por ahora placeholder; luego: consultar ticket y marcar pago.
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  @override
  Widget build(BuildContext context) {
    final timeAsync = ref.watch(serverTimeProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pagos / Cobros'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          timeAsync.when(
            data: (t) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  t?.displayLabel ?? '—',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Pagos / Cobros',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Consultar ticket y registrar cobro.\n(En construcción)',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/history'),
              icon: const Icon(Icons.confirmation_number_outlined),
              label: const Text('Ir a Consultar Ticket'),
            ),
          ],
        ),
      ),
    );
  }
}
