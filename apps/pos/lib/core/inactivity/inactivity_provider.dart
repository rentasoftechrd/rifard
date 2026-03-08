import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session/app_session.dart';

/// Tiempo de inactividad tras el cual se cierra la sesión (5 minutos).
const Duration inactivityTimeout = Duration(minutes: 5);

/// Razón del cierre de sesión (ej. por inactividad). La pantalla de login puede mostrarla y luego limpiarla.
final logoutReasonProvider = StateProvider<String?>((ref) => null);

/// Controla el temporizador de inactividad: al superar [inactivityTimeout] sin interacción
/// se cierra la sesión y el usuario debe volver a iniciar sesión.
class InactivityNotifier extends StateNotifier<void> {
  InactivityNotifier(this._ref) : super(null) {
    _timer = null;
  }

  final Ref _ref;
  Timer? _timer;
  bool _paused = true;

  void _onTimeout() {
    _timer?.cancel();
    _timer = null;
    _ref.read(logoutReasonProvider.notifier).state = 'inactivity';
    _ref.read(appSessionProvider.notifier).clear();
  }

  /// Reinicia el temporizador de inactividad (llamar en cada interacción del usuario).
  void recordActivity() {
    if (_paused) return;
    _timer?.cancel();
    _timer = Timer(inactivityTimeout, _onTimeout);
  }

  /// Pausa el temporizador (app en segundo plano).
  void pause() {
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  /// Reanuda el temporizador (app en primer plano); inicia cuenta de 5 min.
  void resume() {
    _paused = false;
    _timer?.cancel();
    _timer = Timer(inactivityTimeout, _onTimeout);
  }
}

final inactivityProvider = StateNotifierProvider<InactivityNotifier, void>((ref) {
  return InactivityNotifier(ref);
});
