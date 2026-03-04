import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/http/api_client.dart';
import '../../auth/providers/auth_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final api = ref.read(apiClientProvider);
    final url = await api.baseUrl;
    if (url != null && url.isNotEmpty && mounted) {
      _urlController.text = url;
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
        if (accessToken != null) await api.setToken(accessToken);
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Rifard POS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL del servidor',
                  hintText: 'http://192.168.1.10:3000',
                  border: OutlineInputBorder(),
                  helperText: 'En el celular use la IP de la PC donde corre el backend, no localhost',
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                obscureText: true,
                onSubmitted: (_) => _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              if (_connectionMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _connectionMessage!,
                  style: TextStyle(
                    color: _connectionMessage!.startsWith('Sin conexión') || _connectionMessage!.startsWith('Error')
                        ? Colors.orange
                        : Colors.green,
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
                      icon: _testingConnection
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.wifi_find, size: 20),
                      label: const Text('Probar conexión'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _loading || _testingConnection ? null : _login,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Entrar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
