import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'inactivity_provider.dart';

/// Envuelve la app (rutas ya autenticadas) para detectar inactividad.
/// Ante cualquier toque/gesto reinicia el temporizador; si pasan 5 min sin tocar, se cierra sesión.
/// En segundo plano el temporizador se pausa; al volver se reanuda.
class InactivityWrapper extends ConsumerStatefulWidget {
  const InactivityWrapper({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends ConsumerState<InactivityWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(inactivityProvider.notifier).resume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(inactivityProvider.notifier).pause();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        ref.read(inactivityProvider.notifier).resume();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        ref.read(inactivityProvider.notifier).pause();
        break;
    }
  }

  void _onUserActivity() {
    ref.read(inactivityProvider.notifier).recordActivity();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onUserActivity(),
      onPointerMove: (_) => _onUserActivity(),
      child: widget.child,
    );
  }
}
