import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/pos_sell/screens/sell_screen.dart';
import '../../features/pos_sell/screens/checkout_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/pos_select_point/screens/select_point_screen.dart';
import '../../features/printer_setup/screens/printer_setup_screen.dart';
import '../../features/pos_history/screens/history_screen.dart';
import '../../features/pos_void/screens/void_screen.dart';
import '../../features/closeout/screens/closeout_screen.dart';
import '../../features/pos_sell/screens/ticket_detail_screen.dart';
import '../../features/payments/screens/payments_screen.dart';

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
          if (loggedIn && onLogin) return '/select-point';
          return null;
        },
        loading: () => null,
        error: (_, __) => onLogin ? null : '/login',
      );
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/select-point', builder: (_, __) => const SelectPointScreen()),
      GoRoute(path: '/printer-setup', builder: (_, __) => const PrinterSetupScreen()),
      GoRoute(path: '/payments', builder: (_, __) => const PaymentsScreen()),
      GoRoute(path: '/payment', builder: (_, __) => const CheckoutScreen()),
      GoRoute(
        path: '/sell',
        builder: (_, __) => const SellScreen(),
        routes: [
          GoRoute(path: 'ticket/:code', builder: (_, state) => TicketDetailScreen(code: state.pathParameters['code']!)),
        ],
      ),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/void', builder: (_, __) => const VoidScreen()),
      GoRoute(path: '/closeout', builder: (_, __) => const CloseoutScreen()),
    ],
  );
});
