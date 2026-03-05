import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart' deferred as dashboard;
import '../../features/lotteries/screens/lotteries_screen.dart' deferred as lotteries;
import '../../features/draws/screens/draws_screen.dart' deferred as draws;
import '../../features/results/screens/results_screen.dart' deferred as results;
import '../../features/limits/screens/limits_screen.dart' deferred as limits;
import '../../features/pagos/screens/pagos_screen.dart' deferred as pagos;
import '../../features/payments/screens/payments_screen.dart' deferred as payments;
import '../../features/pos/screens/pos_screen.dart' deferred as pos;
import '../../features/pos_connected/screens/pos_connected_screen.dart' deferred as pos_connected;
import '../../features/users/screens/users_screen.dart' deferred as users;
import '../../features/personas/screens/personas_screen.dart' deferred as personas;
import '../../features/reports/screens/reports_screen.dart' deferred as reports;
import '../../features/audit/screens/audit_screen.dart' deferred as audit;

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Carga un módulo diferido y muestra la pantalla; reduce el tamaño del bundle inicial.
class _DeferredRoute extends StatefulWidget {
  const _DeferredRoute({required this.load, required this.builder});

  final Future<void> Function() load;
  final Widget Function() builder;

  @override
  State<_DeferredRoute> createState() => _DeferredRouteState();
}

class _DeferredRouteState extends State<_DeferredRoute> {
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    widget.load().then((_) {
      if (mounted) setState(() => _loaded = true);
    }).catchError((e, _) {
      if (mounted) setState(() => _error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('Error al cargar: $_error'));
    }
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.builder();
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final isLoggedInAsync = ref.watch(isLoggedInProvider);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final onLogin = state.matchedLocation == '/login';
      return isLoggedInAsync.when(
        data: (loggedIn) {
          if (!loggedIn && !onLogin) return '/login';
          if (loggedIn && onLogin) return '/dashboard';
          return null;
        },
        loading: () => null,
        error: (_, __) => onLogin ? null : '/login',
      );
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => _DeferredRoute(load: dashboard.loadLibrary, builder: () => dashboard.DashboardScreen()),
      ),
      GoRoute(path: '/lotteries', builder: (_, __) => _DeferredRoute(load: lotteries.loadLibrary, builder: () => lotteries.LotteriesScreen())),
      GoRoute(path: '/draws', builder: (_, __) => _DeferredRoute(load: draws.loadLibrary, builder: () => draws.DrawsScreen())),
      GoRoute(path: '/results', builder: (_, __) => _DeferredRoute(load: results.loadLibrary, builder: () => results.ResultsScreen())),
      GoRoute(path: '/limits', builder: (_, __) => _DeferredRoute(load: limits.loadLibrary, builder: () => limits.LimitsScreen())),
      GoRoute(path: '/pagos', builder: (_, __) => _DeferredRoute(load: pagos.loadLibrary, builder: () => pagos.PagosScreen())),
      GoRoute(path: '/payments', builder: (_, __) => _DeferredRoute(load: payments.loadLibrary, builder: () => payments.PaymentsScreen())),
      GoRoute(path: '/pos', builder: (_, __) => _DeferredRoute(load: pos.loadLibrary, builder: () => pos.PosScreen())),
      GoRoute(path: '/pos-connected', builder: (_, __) => _DeferredRoute(load: pos_connected.loadLibrary, builder: () => pos_connected.PosConnectedScreen())),
      GoRoute(path: '/users', builder: (_, __) => _DeferredRoute(load: users.loadLibrary, builder: () => users.UsersScreen())),
      GoRoute(path: '/personas', builder: (_, __) => _DeferredRoute(load: personas.loadLibrary, builder: () => personas.PersonasScreen())),
      GoRoute(path: '/reports', builder: (_, __) => _DeferredRoute(load: reports.loadLibrary, builder: () => reports.ReportsScreen())),
      GoRoute(path: '/audit', builder: (_, __) => _DeferredRoute(load: audit.loadLibrary, builder: () => audit.AuditScreen())),
    ],
  );
});
