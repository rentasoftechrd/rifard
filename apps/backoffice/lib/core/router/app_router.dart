import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/lotteries/screens/lotteries_screen.dart';
import '../../features/draws/screens/draws_screen.dart';
import '../../features/results/screens/results_screen.dart';
import '../../features/limits/screens/limits_screen.dart';
import '../../features/pagos/screens/pagos_screen.dart';
import '../../features/payments/screens/payments_screen.dart';
import '../../features/pos_connected/screens/pos_connected_screen.dart';
import '../../features/users/screens/users_screen.dart';
import '../../features/vendors/screens/vendors_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/audit/screens/audit_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

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
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(path: '/lotteries', builder: (_, __) => const LotteriesScreen()),
      GoRoute(path: '/draws', builder: (_, __) => const DrawsScreen()),
      GoRoute(path: '/results', builder: (_, __) => const ResultsScreen()),
      GoRoute(path: '/limits', builder: (_, __) => const LimitsScreen()),
      GoRoute(path: '/pagos', builder: (_, __) => const PagosScreen()),
      GoRoute(path: '/payments', builder: (_, __) => const PaymentsScreen()),
      GoRoute(path: '/pos-connected', builder: (_, __) => const PosConnectedScreen()),
      GoRoute(path: '/users', builder: (_, __) => const UsersScreen()),
      GoRoute(path: '/vendors', builder: (_, __) => const VendorsScreen()),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/audit', builder: (_, __) => const AuditScreen()),
    ],
  );
});
