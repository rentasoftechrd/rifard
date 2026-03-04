import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runZonedGuarded(() {
    if (kDebugMode) {
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError: ${details.exception}\n${details.stack}');
      };
    }
    runApp(const ProviderScope(child: RifardBackofficeApp()));
  }, (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
  });
}

class RifardBackofficeApp extends ConsumerWidget {
  const RifardBackofficeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Rifard Backoffice',
      debugShowCheckedModeBanner: false,
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
