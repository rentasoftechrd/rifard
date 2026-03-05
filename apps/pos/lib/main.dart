import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: RifardPosApp()));
}

class RifardPosApp extends ConsumerWidget {
  const RifardPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Rifard POS',
      debugShowCheckedModeBanner: false,
      theme: darkTheme,
      routerConfig: router,
    );
  }
}
