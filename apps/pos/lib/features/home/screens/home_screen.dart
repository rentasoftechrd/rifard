import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/server_time/server_time_provider.dart';
import '../../../core/session/pos_session.dart';
import '../../auth/providers/auth_provider.dart';

/// Menú principal del POS: VENTAS, PAGOS, CUADRE. Hora servidor RD en barra.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(posSessionProvider);
    final session = sessionAsync.valueOrNull;
    if (session != null && !session.hasPoint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/select-point');
      });
    }
    final userAsync = ref.watch(currentUserProvider);
    final timeAsync = ref.watch(serverTimeProvider);

    final pointId = sessionAsync.valueOrNull?.pointId;
    final deviceId = sessionAsync.valueOrNull?.deviceId ?? '';
    final terminalLabel = pointId != null ? 'POS-${pointId.substring(0, 8)}' : 'POS';
    final userName = userAsync.valueOrNull?['fullName'] ?? userAsync.valueOrNull?['email'] ?? 'Cajero';
    final serverTime = timeAsync.valueOrNull?.displayLabel ?? '--:--:--';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Terminal: $terminalLabel | ${userName.length > 12 ? '${userName.substring(0, 12)}…' : userName}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.wifi, color: AppColors.success, size: 18),
            const SizedBox(width: 4),
            const Text('Online', style: TextStyle(color: AppColors.success, fontSize: 12)),
            const SizedBox(width: 12),
            Text('Hora servidor RD: $serverTime', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(apiClientProvider).setToken(null);
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(serverTimeProvider);
          ref.invalidate(posSessionProvider);
          ref.invalidate(currentUserProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            _MenuButton(
              label: 'VENTAS',
              icon: Icons.shopping_cart,
              color: AppColors.primary,
              onTap: () => context.go('/sell'),
            ),
            const SizedBox(height: 12),
            _MenuButton(
              label: 'PAGOS / COBROS',
              icon: Icons.payment,
              color: AppColors.secondary,
              onTap: () => context.go('/payments'),
            ),
            const SizedBox(height: 12),
            _MenuButton(
              label: 'CUADRE / CIERRE',
              icon: Icons.summarize,
              color: const Color(0xFFF59E0B),
              onTap: () => context.go('/closeout'),
            ),
            const SizedBox(height: 32),
            const Divider(color: AppColors.border),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.go('/history'),
              icon: const Icon(Icons.receipt_long, size: 20),
              label: const Text('Consultar Ticket'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {}, // TODO Resultados
              icon: const Icon(Icons.emoji_events_outlined, size: 20),
              label: const Text('Resultados'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(width: 20),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
