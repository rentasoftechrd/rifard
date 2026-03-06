import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/http/api_client.dart';
import '../../../core/server_time/server_time_provider.dart';
import '../../../core/session/pos_session.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _urlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _testingConnection = false;
  String? _connectionMessage;
  String _terminalId = '—';

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
    getDeviceId().then((id) {
      if (mounted) setState(() => _terminalId = id.length > 10 ? '${id.substring(0, 10)}…' : id);
    });
  }

  Future<void> _loadSavedUrl() async {
    final api = ref.read(apiClientProvider);
    final url = await api.baseUrl;
    if (mounted) {
      _urlController.text = (url != null && url.isNotEmpty) ? url : kDefaultBaseUrl;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _error = 'Ingrese la URL del servidor';
        _connectionMessage = null;
      });
      return;
    }
    String baseUrl = url;
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      baseUrl = 'http://$baseUrl';
    }
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);

    setState(() {
      _error = null;
      _connectionMessage = null;
      _testingConnection = true;
    });
    try {
      final api = ref.read(apiClientProvider);
      await api.setBaseUrl(baseUrl);
      final resp = await api.get('/health/pos-connect');
      if (mounted) {
        if (resp.statusCode == 200) {
          final data = resp.body.isNotEmpty ? _parseJson(resp.body) : <String, dynamic>{};
          final server = data['server'] ?? 'Servidor';
          final msg = data['message'] ?? 'Conectado';
          setState(() {
            _connectionMessage = '$server: $msg';
            _testingConnection = false;
          });
        } else {
          setState(() {
            _connectionMessage = 'Error ${resp.statusCode}';
            _testingConnection = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionMessage = 'Sin conexión: ${e.toString().split('\n').first}';
          _testingConnection = false;
        });
      }
    }
  }

  Future<void> _login() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Ingrese la URL del servidor');
      return;
    }
    String baseUrl = url;
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      baseUrl = 'http://$baseUrl';
    }
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);

    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final api = ref.read(apiClientProvider);
      await api.setBaseUrl(baseUrl);
      final resp = await api.post('/auth/login', body: {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });
      final data = resp.body.isNotEmpty ? _parseJson(resp.body) : <String, dynamic>{};
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final accessToken = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;
        if (accessToken != null) {
          await api.setTokens(accessToken, refreshToken);
          ref.invalidate(isLoggedInProvider);
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (mounted) context.go('/select-point');
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'Login failed';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _parseJson(String s) {
    try {
      return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputDec = InputDecoration(
      labelText: 'URL del servidor',
      hintText: 'http://187.124.81.201:3000',
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      labelStyle: const TextStyle(color: AppColors.textMuted),
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.point_of_sale, size: 48, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text('Rifard POS', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('URL del servidor (misma que en el backoffice)', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _urlController,
                    decoration: inputDec.copyWith(helperText: 'Por defecto: backend en el VPS'),
                    style: const TextStyle(color: AppColors.textPrimary),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: inputDec.copyWith(labelText: 'Email', hintText: null, helperText: null),
                    style: const TextStyle(color: AppColors.textPrimary),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: inputDec.copyWith(labelText: 'Contraseña', hintText: null, helperText: null),
                    style: const TextStyle(color: AppColors.textPrimary),
                    obscureText: true,
                    onSubmitted: (_) => _login(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    ),
                  ],
                  if (_connectionMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _connectionMessage!,
                      style: TextStyle(
                        color: _connectionMessage!.startsWith('Sin conexión') || _connectionMessage!.startsWith('Error') ? AppColors.warning : AppColors.success,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loading || _testingConnection ? null : _testConnection,
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.border)),
                          icon: _testingConnection
                              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                              : const Icon(Icons.wifi_find, size: 20),
                          label: const Text('Probar conexión'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _loading || _testingConnection ? null : _login,
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                          child: _loading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Iniciar sesión'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),
                  _LoginFooter(terminalId: _terminalId, connectionMessage: _connectionMessage),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginFooter extends ConsumerWidget {
  const _LoginFooter({required this.terminalId, this.connectionMessage});
  final String terminalId;
  final String? connectionMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeAsync = ref.watch(serverTimeProvider);
    final isOnline = connectionMessage != null && connectionMessage!.toLowerCase().contains('conectado');
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Terminal: $terminalId', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(width: 16),
            Text(
              'Estado: ${isOnline ? "Online ✅" : "—"}',
              style: TextStyle(color: isOnline ? AppColors.success : AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        timeAsync.when(
          data: (t) => Text(
            'Hora servidor (RD): ${t?.displayLabel ?? "—"}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          loading: () => const Text('Hora servidor (RD): …', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          error: (_, __) => const Text('Hora servidor (RD): —', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
      ],
    );
  }
}
