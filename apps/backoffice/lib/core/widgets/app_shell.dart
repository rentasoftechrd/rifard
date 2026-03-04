import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.currentPath, required this.child});
  final String currentPath;
  final Widget child;

  static const _navItems = [
    ('/dashboard', 'Dashboard', Icons.dashboard),
    ('/lotteries', 'Loterías', Icons.confirmation_number),
    ('/draws', 'Sorteos', Icons.event),
    ('/results', 'Resultados', Icons.assignment),
    ('/limits', 'Límites', Icons.tune),
    ('/pagos', 'Precios', Icons.payments),
    ('/payments', 'Pagos', Icons.paid),
    ('/pos-connected', 'POS Conectados', Icons.point_of_sale),
    ('/users', 'Usuarios', Icons.people),
    ('/vendors', 'Vendedores', Icons.storefront),
    ('/reports', 'Reportes', Icons.assessment),
    ('/audit', 'Auditoría', Icons.history),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            backgroundColor: AppColors.surface,
            selectedIndex: _navItems.indexWhere((e) => e.$1 == currentPath).clamp(0, _navItems.length - 1),
            onDestinationSelected: (i) => context.go(_navItems[i].$1),
            destinations: _navItems.map((e) => NavigationRailDestination(icon: Icon(e.$3), label: Text(e.$2))).toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                AppBar(
                  title: const Text('Rifard Backoffice'),
                  actions: [
                    IconButton(icon: const Icon(Icons.dark_mode), onPressed: () {}),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () async {
                        await ref.read(apiClientProvider).setToken(null);
                        if (context.mounted) context.go('/login');
                      },
                    ),
                  ],
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
